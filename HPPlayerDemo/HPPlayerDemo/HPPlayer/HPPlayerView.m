//
//  HPPlayerView.m
//  HPPlayerDemo
//
//  Created by 胡鹏 on 9/1/16.
//  Copyright © 2016 Vince. All rights reserved.
//

#import "HPPlayerView.h"
#import "HPPlayerControllerView.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "HPPlayerLoadStatusView.h"
#import "UIView+YYAdd.h"
#import "HPPlayer.h"


static const CGFloat HPPlayerAnimationTimeInterval = 1;
static const CGFloat HPPlayerControlBarAutoFadeOutTimeInterval = 1;

//手势移动方向
typedef enum {
    PanDirectionHorizontalMoved, // 横向移动
    PanDirectionVerticalMoved    // 纵向移动
} PanDirection;

typedef enum {

    HPPlayerStateFailed,     // 播放失败
    HPPlayerStateBuffering,  // 缓冲中
    HPPlayerStatePlaying,    // 播放中
    HPPlayerStateStopped,    // 停止播放
    HPPlayerStatePause       // 暂停播放
    
}HPPlayerState;

@interface HPPlayerView ()<UIGestureRecognizerDelegate,UIAlertViewDelegate>

/**
 * 播放player
 */
@property (nonatomic, strong) AVPlayer *player;
/**
 * 播放属性 
 */
@property (nonatomic, strong) AVPlayerItem *playerItem;
/** 
 * playerLayer 
 */
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

/**
 *  计时器
 */
@property (nonatomic, strong) NSTimer *timer;
/**
 *  控制层View
 */
@property (nonatomic, strong) HPPlayerControllerView *controlView;
/**
 *  视频加载状态指示视图
 */
@property (nonatomic, strong) HPPlayerLoadStatusView *loadStatusView;

/** 滑杆 */
@property (nonatomic, strong) UISlider            *volumeViewSlider;

/**
 *  用来保存快进的总时长
 */
@property (nonatomic, assign) CGFloat             sumTime;
/**
 *  定义一个实例变量，保存枚举值
 */
@property (nonatomic, assign) PanDirection        panDirection;
/**
 *  播发器的几种状态
 */
@property (nonatomic, assign) HPPlayerState       state;
/**
 *  是否为全屏
 */
@property (nonatomic, assign) BOOL                isFullScreen;

/**
 *  是否在调节音量
 */
@property (nonatomic, assign) BOOL                isVolume;
/**
 *  是否显示controlView
 */
@property (nonatomic, assign) BOOL                isMaskShowing;
/**
 *   是否被用户暂停
 */
@property (nonatomic, assign) BOOL                isPauseByUser;

/**
 *  slider上次的值
 */
@property (nonatomic, assign) CGFloat             sliderLastValue;
/**
 *  是否再次设置URL播放视频
 */
@property (nonatomic, assign) BOOL                repeatToPlay;
/**
 *  播放完了
 */
@property (nonatomic, assign) BOOL                playDidEnd;
/**
 *  进入后台
 */
@property (nonatomic, assign) BOOL                didEnterBackground;

/**
 *  是否自动播放
 */
@property (nonatomic, assign) BOOL                isAutoPlay;

/**
 *  原始位置
 */
@property (nonatomic, assign) CGRect originFrame;

@end

@implementation HPPlayerView

#pragma mark - 生命周期
- (instancetype)initWithFrame:(CGRect)frame {

    if (self = [super initWithFrame:frame]) {
        
        //添加加载指示视图
        [self addSubview:self.loadStatusView];
        
        [self.controlView.activity stopAnimating];
        self.controlView.horizontalLabel.hidden = YES;
        
//        self.clipsToBounds = YES;
    }
    
    return self;
}

- (void)dealloc {
    NSLog(@"%s", __FUNCTION__);
//    //移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 移除观察者
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    
}

//重置player
- (void)resetPlayer {

    self.playDidEnd = NO;
    self.didEnterBackground = NO;
    
    self.isAutoPlay = NO;
    //移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 移除观察者
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    //关闭定时器
    [self.timer invalidate];
    
    //暂停
    [self pause];
    
    // 移除原来的layer
    [self.playerLayer removeFromSuperlayer];
    // 替换PlayerItem
    [self.player replaceCurrentItemWithPlayerItem:nil];
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    // 重置控制层View
    [self.controlView resetControlView];
    [self removeFromSuperview];
}

#pragma mark - 观察者、通知
- (void)addObserverAndNotification {

    // app退到后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    // app进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    // slider开始滑动事件
    [self.controlView.videoSlider addTarget:self action:@selector(progressSliderTouchBegan:) forControlEvents:UIControlEventTouchDown];
    // slider滑动中事件
    [self.controlView.videoSlider addTarget:self action:@selector(progressSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    // slider结束滑动事件
    [self.controlView.videoSlider addTarget:self action:@selector(progressSliderTouchEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchUpOutside];
    
    // 播放按钮点击事件
    [self.controlView.startBtn addTarget:self action:@selector(startAction:) forControlEvents:UIControlEventTouchUpInside];
    
    // 返回按钮点击事件
    [self.controlView.backBtn addTarget:self action:@selector(backButtonAction) forControlEvents:UIControlEventTouchUpInside];
    // 全屏按钮点击事件
    [self.controlView.fullScreenBtn addTarget:self action:@selector(fullScreenAction:) forControlEvents:UIControlEventTouchUpInside];
    // 重播
    [self.controlView.repeatBtn addTarget:self action:@selector(repeatPlay:) forControlEvents:UIControlEventTouchUpInside];
    // 中间按钮播放
    [self.controlView.playeBtn addTarget:self action:@selector(configHPPlayer) forControlEvents:UIControlEventTouchUpInside];
    
    // 点击slider快进
    __weak typeof(self) weakSelf = self;
    self.controlView.tapBlock = ^(CGFloat value) {
        [weakSelf pause];
        // 视频总时间长度
        CGFloat total           = (CGFloat)weakSelf.playerItem.duration.value / weakSelf.playerItem.duration.timescale;
        //计算出拖动的当前秒数
        NSInteger dragedSeconds = floorf(total * value);
        [weakSelf seekToTime:dragedSeconds completionHandler:^(BOOL finished) {
            if (finished) {
                // 只要点击进度条就跳转播放
                weakSelf.controlView.startBtn.selected = !finished;
                [weakSelf startAction:weakSelf.controlView.startBtn];
            }
        }];
        
    };
    
    // 监听播放状态
    [self.player.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
//     监听loadedTimeRanges属性
    [self.player.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    // 监听playbackBufferEmpty缓冲为空
    [self.player.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    // 监听playbackLikelyToKeepUp缓冲完毕
    [self.player.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    
    [self listeningRotating];
}


/**
 *  监听设备旋转通知
 */
- (void)listeningRotating{
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDeviceOrientationChange)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil
     ];
    
}

/**
 *  创建手势
 */
- (void)createGesture
{
    // 单击
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapAction:)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];
    
    // 双击(播放/暂停)
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTapAction:)];
    [doubleTap setNumberOfTapsRequired:2];
    [self addGestureRecognizer:doubleTap];
    
    [tap requireGestureRecognizerToFail:doubleTap];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (object == self.playerItem) {
        if ([keyPath isEqualToString:@"status"]) {
            
            if (self.player.status == AVPlayerStatusReadyToPlay) {
                //准备播放时，移除
                [self.loadStatusView resetLoadingView];
                _loadStatusView = nil;
                
                self.state = HPPlayerStatePlaying;
                // 加载完成后，再添加平移手势
                // 添加平移手势，用来控制音量、亮度、快进快退
                UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panDirection:)];
                pan.delegate                = self;
                [self addGestureRecognizer:pan];
                
            } else if (self.player.status == AVPlayerStatusFailed){

                [self.controlView.activity startAnimating];
                
                self.controlView.horizontalLabel.hidden = NO;
                self.controlView.horizontalLabel.text = @"视频加载失败";
            }
            
        }
        else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            
            NSTimeInterval timeInterval = [self availableDuration];// 计算缓冲进度
            CMTime duration             = self.playerItem.duration;
            CGFloat totalDuration       = CMTimeGetSeconds(duration);
            [self.controlView.progressView setProgress:timeInterval / totalDuration animated:NO];
        }else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            
            // 当缓冲是空的时候
            if (self.playerItem.playbackBufferEmpty) {

                self.state = HPPlayerStateBuffering;
                [self bufferingSomeSecond];
            }
            
        }else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            
            // 当缓冲好的时候
            if (self.playerItem.playbackLikelyToKeepUp){
                
                self.state = HPPlayerStatePlaying;
            }
            
        }
    }
}

/**
 *  全屏按钮事件
 *
 *  @param sender 全屏Button
 */
- (void)fullScreenAction:(UIButton *)sender
{
    if (self.isFullScreen) {
        [self backOrientationPortrait];
    }else{
        [self setDeviceOrientationLandscapeRight];
    }
}

- (void)backOrientationPortrait{
    if (!self.isFullScreen) {
        return;
    }
    
    self.isFullScreen = NO;
    [UIView animateWithDuration:0.3f animations:^{
        
        [self setTransform:CGAffineTransformIdentity];
        self.rFrame = self.originFrame;
    } completion:^(BOOL finished) {
       
    }];
}

-(void)setIsRightRotation:(BOOL)isRightRotation
{
    _isRightRotation = isRightRotation;
    if (isRightRotation) {
        [self setDeviceOrientationLandscapeRight];
        self.controlView.fullScreenBtn.hidden = YES;
    }
}

//电池栏在左全屏
- (void)setDeviceOrientationLandscapeRight{
    
    if (self.isFullScreen) {
        return;
    }
    
    self.originFrame = self.frame;
    CGFloat height = [[UIScreen mainScreen] bounds].size.width;
    CGFloat width = [[UIScreen mainScreen] bounds].size.height;
    CGRect frame;
    if (self.isRightRotation) {
        frame = CGRectMake(0, 0, width, height);
    }else{
        frame = CGRectMake((height - width) / 2, (width - height) / 2, width, height);
    }

    self.isFullScreen = YES;
    [UIView animateWithDuration:0.3f animations:^{
        self.rFrame = frame;
        if (!self.isRightRotation) {
            [self setTransform:CGAffineTransformMakeRotation(M_PI_2)];
        }
    } completion:^(BOOL finished) {
       
    }];
    
}

//电池栏在右全屏
- (void)setDeviceOrientationLandscapeLeft{
  
    if (self.isFullScreen) {
        return;
    }
    self.originFrame = self.frame;
    CGFloat height = [[UIScreen mainScreen] bounds].size.width;
    CGFloat width = [[UIScreen mainScreen] bounds].size.height;
    CGRect frame;
    if (self.isRightRotation) {
        frame = CGRectMake(0, 0, width, height);
    }else{
        frame = CGRectMake((height - width) / 2, (width - height) / 2, width, height);
    }
    
    self.isFullScreen = YES;
   
    [UIView animateWithDuration:0.3f animations:^{
        self.rFrame = frame;
        if (!self.isRightRotation) {
            [self setTransform:CGAffineTransformMakeRotation(M_PI_2)];
        }
    } completion:^(BOOL finished) {
      
    }];
}

#pragma mark - 设置视频URL

/**
 *  videoURL的setter方法
 *
 *  @param videoURL videoURL
 */
- (void)setVideoURL:(NSURL *)videoURL
{
    
    _videoURL = videoURL;
    self.state = HPPlayerStateStopped;
    
    // 初始化playerItem
    self.playerItem  = [AVPlayerItem playerItemWithURL:videoURL];
    [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
    // 初始化playerLayer
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    
    // AVLayerVideoGravityResize,       // 非均匀模式。两个维度完全填充至整个视图区域
    // AVLayerVideoGravityResizeAspect,  // 等比例填充，直到一个维度到达区域边界
    // AVLayerVideoGravityResizeAspectFill, // 等比例填充，直到填充满整个视图区域，其中一个维度的部分区域会被裁剪
    
    // 此处根据视频填充模式设置
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    // 添加playerLayer到self.layer
    [self.layer insertSublayer:self.playerLayer atIndex:0];
    
    // 添加观察者、通知
    [self addObserverAndNotification];
    
    // 初始化显示controlView为YES
    self.isMaskShowing = YES;
    // 延迟隐藏controlView
    [self autoFadeOutControlBar];
    
    // 计时器
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(playerTimerAction) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
    // 根据屏幕的方向设置相关UI
    if (!self.isRightRotation) {
        [self onDeviceOrientationChange];
    }
    
    // 添加手势
    [self createGesture];
    
    //获取系统音量
    [self configureVolume];
    
    // 开始播放
    [self play];
    self.controlView.startBtn.selected = YES;
    self.isPauseByUser = NO;
    
    //强制让系统调用layoutSubviews 两个方法必须同时写
    [self setNeedsLayout]; //是标记 异步刷新 会调但是慢
    [self layoutIfNeeded]; //加上此代码立刻刷新
}

#pragma mark - Action

/**
 *   轻拍方法
 *
 *  @param gesture UITapGestureRecognizer
 */
- (void)tapAction:(UITapGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateRecognized) {

        if (self.isMaskShowing) {
            [self hideControlView];
        } else {
            [self animateShow];
        }
    }
}

/**
 *  双击播放/暂停
 *
 *  @param gesture UITapGestureRecognizer
 */
- (void)doubleTapAction:(UITapGestureRecognizer *)gesture
{
    // 显示控制层
    [self animateShow];
    [self startAction:self.controlView.startBtn];
}


/**
 *  播放、暂停按钮事件
 *
 *  @param button UIButton
 */
- (void)startAction:(UIButton *)button
{
    button.selected    = !button.selected;
    self.isPauseByUser = !self.isPauseByUser;
    if (button.selected) {
        if (self.playDidEnd) {
            
            [self.loadStatusView removeFromSuperview];
            [self setVideoURL:self.videoURL];
            
        } else {
            
            [self play];
        }
        if (self.state == HPPlayerStatePause) { self.state = HPPlayerStatePlaying; }
    } else {
        [self pause];
        if (self.state == HPPlayerStatePlaying) { self.state = HPPlayerStatePause;}
    }
}

/**
 *  播放
 */
- (void)play
{
    self.isPauseByUser = NO;
    [_player play];
}

/**
 * 暂停
 */
- (void)pause
{
    self.isPauseByUser = YES;
    [_player pause];
}

/**
 *  返回按钮事件
 */
- (void)backButtonAction
{
    
    if (!self.isFullScreen) {
        // player加到控制器上，只有一个player时候
        [self.timer invalidate];
        [self pause];
        if (self.goBackBlock) {
            self.goBackBlock();
        }
    }else {
        if (self.isRightRotation) {
            [self.timer invalidate];
            [self pause];
            UITabBarController * tab = (UITabBarController *)[[UIApplication sharedApplication].delegate window].rootViewController;
            UINavigationController * nav = tab.selectedViewController;
            [nav.topViewController dismissViewControllerAnimated:YES completion:nil];
        }else{
            [self backOrientationPortrait];
        }
    }
   
}

/**
 *  重播点击事件
 *
 *  @param sender sender
 */
- (void)repeatPlay:(UIButton *)sender
{
    // 没有播放完
    self.playDidEnd    = NO;
    // 重播改为NO
    self.repeatToPlay  = NO;
    // 准备显示控制层
    self.isMaskShowing = NO;
    [self animateShow];
    // 重置控制层View
    [self.controlView resetControlView];
    [self seekToTime:0 completionHandler:nil];
}

/**
 *  设置Player相关参数
 */
- (void)configHPPlayer
{
    // 初始化playerItem
    self.playerItem  = [AVPlayerItem playerItemWithURL:self.videoURL];
    
    // 每次都重新创建Player，替换replaceCurrentItemWithPlayerItem:，该方法阻塞线程
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    
    // 初始化playerLayer
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    
    // 此处为默认视频填充模式
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    // 添加playerLayer到self.layer
    [self.layer insertSublayer:self.playerLayer atIndex:0];
    
    // 初始化显示controlView为YES
    self.isMaskShowing = YES;
    // 延迟隐藏controlView
    [self autoFadeOutControlBar];
    
    // 计时器
    [self createTimer];
    
    // 添加手势
    [self createGesture];
    
    // 获取系统音量
    [self configureVolume];
    
    // 开始播放
    [self play];
    self.controlView.startBtn.selected = YES;
    self.isPauseByUser = NO;
    self.controlView.playeBtn.hidden   = YES;
    
    // 强制让系统调用layoutSubviews 两个方法必须同时写
    [self setNeedsLayout]; //是标记 异步刷新 会调但是慢
    [self layoutIfNeeded]; //加上此代码立刻刷新
}

#pragma mark - 获取系统音量
/**
 *  获取系统音量
 */
- (void)configureVolume
{
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    _volumeViewSlider = nil;
    for (UIView *view in [volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            _volumeViewSlider = (UISlider *)view;
            break;
        }
    }
    
    // 使用这个category的应用不会随着手机静音键打开而静音，可在手机静音下播放声音
    NSError *setCategoryError = nil;
    BOOL success = [[AVAudioSession sharedInstance]
                    setCategory: AVAudioSessionCategoryPlayback
                    error: &setCategoryError];
    
    if (!success) { /* handle the error in setCategoryError */ }
    
    // 监听耳机插入和拔掉通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:) name:AVAudioSessionRouteChangeNotification object:nil];
}

/**
 *  耳机插入、拔出事件
 */
- (void)audioRouteChangeListenerCallback:(NSNotification*)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    switch (routeChangeReason) {
            
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            // 耳机插入
            break;
            
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        {
            // 耳机拔掉
            // 拔掉耳机继续播放
            [self play];
        }
            break;
            
        case AVAudioSessionRouteChangeReasonCategoryChange:
            
            NSLog(@"AVAudioSessionRouteChangeReasonCategoryChange");
            break;
    }
}

#pragma mark - NSNotification Action
/**
 *  播放完了
 *
 *  @param notification 通知
 */
- (void)moviePlayDidEnd:(NSNotification *)notification
{
    self.state            = HPPlayerStateStopped;
    if ( !self.isFullScreen) { // 播放完了，如果是在小屏模式 && 在bottom位置，直接关闭播放器
        self.repeatToPlay = NO;
        self.playDidEnd   = NO;
        [self resetPlayer];
    } else {
        self.controlView.backgroundColor  = RGBA(0, 0, 0, .6);
        self.playDidEnd                   = YES;
        self.controlView.repeatBtn.hidden = NO;
        // 初始化显示controlView为YES
        self.isMaskShowing                = NO;
        // 延迟隐藏controlView
        [self animateShow];
    }
}

/**
 *  应用退到后台
 */
- (void)appDidEnterBackground
{
    self.didEnterBackground = YES;
    [_player pause];
    self.state = HPPlayerStatePause;

    self.controlView.startBtn.selected = NO;
}

/**
 *  应用进入前台
 */
- (void)appDidEnterPlayGround
{
    self.didEnterBackground = NO;
    self.isMaskShowing = NO;
    // 延迟隐藏controlView
    [self animateShow];
    [self createTimer];
    if (!self.isPauseByUser) {
        self.state                         = HPPlayerStatePlaying;
        self.controlView.startBtn.selected = YES;
        self.isPauseByUser                 = NO;
        [self play];
    }
}

#pragma mark - UIPanGestureRecognizer手势方法

/**
 *  pan手势事件
 *
 *  @param pan UIPanGestureRecognizer
 */
- (void)panDirection:(UIPanGestureRecognizer *)pan
{
    //根据在view上Pan的位置，确定是调音量还是亮度
    CGPoint locationPoint = [pan locationInView:self];
    
    // 我们要响应水平移动和垂直移动
    // 根据上次和本次移动的位置，算出一个速率的point
    CGPoint veloctyPoint = [pan velocityInView:self];
    
    // 判断是垂直移动还是水平移动
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{ // 开始移动
            // 使用绝对值来判断移动的方向
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            if (x > y) { // 水平移动
                self.panDirection           = PanDirectionHorizontalMoved;
                // 取消隐藏
                self.controlView.horizontalLabel.hidden = NO;
                // 给sumTime初值
                CMTime time                 = self.player.currentTime;
                self.sumTime                = time.value/time.timescale;
                
                // 暂停视频播放
                [self pause];
                // 暂停timer
                [self.timer setFireDate:[NSDate distantFuture]];
            }
            else if (x < y){ // 垂直移动
                self.panDirection = PanDirectionVerticalMoved;
                // 开始滑动的时候,状态改为正在控制音量
                if (locationPoint.x > self.bounds.size.width / 2) {
                    self.isVolume = YES;
                }else { // 状态改为显示亮度调节
                    self.isVolume = NO;
                }
                
            }
            break;
        }
        case UIGestureRecognizerStateChanged:{ // 正在移动
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    [self horizontalMoved:veloctyPoint.x]; // 水平移动的方法只要x方向的值
                    break;
                }
                case PanDirectionVerticalMoved:{
                    [self verticalMoved:veloctyPoint.y]; // 垂直移动方法只要y方向的值
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:{ // 移动停止
            // 移动结束也需要判断垂直或者平移
            // 比如水平移动结束时，要快进到指定位置，如果这里没有判断，当我们调节音量完之后，会出现屏幕跳动的bug
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    
                    // 继续播放
                    [self play];
                    [self.timer setFireDate:[NSDate date]];
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        // 隐藏视图
                        self.controlView.horizontalLabel.hidden = YES;
                    });
                    //快进、快退时候把开始播放按钮改为播放状态
                    self.controlView.startBtn.selected = YES;
                    self.isPauseByUser                 = NO;
                    
                    // 转换成CMTime才能给player来控制播放进度
                    CMTime dragedCMTime                = CMTimeMake(self.sumTime, 1);
                    //[_player pause];
                    
                    [self endSlideTheVideo:dragedCMTime];
                    
                    // 把sumTime滞空，不然会越加越多
                    self.sumTime = 0;
                    break;
                }
                case PanDirectionVerticalMoved:{
                    // 垂直移动结束后，把状态改为不再控制音量
                    self.isVolume = NO;
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        self.controlView.horizontalLabel.hidden = YES;
                    });
                    break;
                }
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }
}

/**
 *  pan垂直移动的方法
 *
 *  @param value void
 */
- (void)verticalMoved:(CGFloat)value
{
    if (self.isVolume) {
        // 更改系统的音量
        self.volumeViewSlider.value      -= value / 10000;// 越小幅度越小
    }else {
        //亮度
        [UIScreen mainScreen].brightness -= value / 10000;

    }
}

/**
 *  pan水平移动的方法
 *
 *  @param value void
 */
- (void)horizontalMoved:(CGFloat)value
{
    // 快进快退的方法
    NSString *style = @"";
    if (value < 0) {
        style = @"<<";
    }
    else if (value > 0){
        style = @">>";
    }
    
    // 每次滑动需要叠加时间
    self.sumTime += value / 200;
    
    // 需要限定sumTime的范围
    CMTime totalTime           = self.playerItem.duration;
    CGFloat totalMovieDuration = (CGFloat)totalTime.value/totalTime.timescale;
    if (self.sumTime > totalMovieDuration) {
        self.sumTime = totalMovieDuration;
    }else if (self.sumTime < 0){
        self.sumTime = 0;
    }
    
    // 当前快进的时间
    NSString *nowTime         = [self durationStringWithTime:(int)self.sumTime];
    // 总时间
    NSString *durationTime    = [self durationStringWithTime:(int)totalMovieDuration];
    // 给label赋值
    self.controlView.horizontalLabel.text = [NSString stringWithFormat:@"%@ %@ / %@",style, nowTime, durationTime];
}


/**
 *  根据时长求出字符串
 *
 *  @param time 时长
 *
 *  @return 时长字符串
 */
- (NSString *)durationStringWithTime:(int)time
{
    // 获取分钟
    NSString *min = [NSString stringWithFormat:@"%02d",time / 60];
    // 获取秒数
    NSString *sec = [NSString stringWithFormat:@"%02d",time % 60];
    return [NSString stringWithFormat:@"%@:%@", min, sec];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    CGPoint point = [touch locationInView:self.controlView];
    // （屏幕下方slider区域不响应pan手势）
    if ((point.y > self.bounds.size.height-40) && !self.isFullScreen) {
        return NO;
    }
    return YES;
}


#pragma mark - sliderAction

/**
 *  slider开始滑动事件
 *
 *  @param slider UISlider
 */
- (void)progressSliderTouchBegan:(UISlider *)slider
{
//    [self cancelAutoFadeOutControlBar];
    // 暂停timer
    [self.timer setFireDate:[NSDate distantFuture]];
}

/**
 *  slider滑动中事件
 *
 *  @param slider UISlider
 */
- (void)progressSliderValueChanged:(UISlider *)slider
{
    NSString *style = @"";
    CGFloat value = slider.value - self.sliderLastValue;
    if (value > 0) {
        style = @">>";
    } else if (value < 0) {
        style = @"<<";
    }
    self.sliderLastValue = slider.value;
    //拖动改变视频播放进度
    if (self.player.status == AVPlayerStatusReadyToPlay) {
        
        [self pause];
        //计算出拖动的当前秒数
        CGFloat total                       = (CGFloat)_playerItem.duration.value / _playerItem.duration.timescale;
        
        NSInteger dragedSeconds             = floorf(total * slider.value);
        
        //转换成CMTime才能给player来控制播放进度
        
        CMTime dragedCMTime                 = CMTimeMake(dragedSeconds, 1);
        // 拖拽的时长
        NSInteger proMin                    = (NSInteger)CMTimeGetSeconds(dragedCMTime) / 60;//当前秒
        NSInteger proSec                    = (NSInteger)CMTimeGetSeconds(dragedCMTime) % 60;//当前分钟
        
        //duration 总时长
        NSInteger durMin                    = (NSInteger)total / 60;//总秒
        NSInteger durSec                    = (NSInteger)total % 60;//总分钟
        
        NSString *currentTime               = [NSString stringWithFormat:@"%02zd:%02zd", proMin, proSec];
        NSString *totalTime                 = [NSString stringWithFormat:@"%02zd:%02zd", durMin, durSec];
        
        self.controlView.currentTimeLabel.text = currentTime;
        self.controlView.horizontalLabel.hidden         = NO;
        self.controlView.horizontalLabel.text           = [NSString stringWithFormat:@"%@ %@ / %@",style, currentTime, totalTime];
        
    }
}

/**
 *  slider结束滑动事件
 *
 *  @param slider UISlider
 */
- (void)progressSliderTouchEnded:(UISlider *)slider
{
    // 继续开启timer
    [self.timer setFireDate:[NSDate date]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.controlView.horizontalLabel.hidden = YES;
    });
    // 结束滑动时候把开始播放按钮改为播放状态
    self.controlView.startBtn.selected = YES;
    self.isPauseByUser                 = NO;
    
    // 滑动结束延时隐藏controlView
    [self autoFadeOutControlBar];
    
    //计算出拖动的当前秒数
    CGFloat total           = (CGFloat)_playerItem.duration.value / _playerItem.duration.timescale;
    
    NSInteger dragedSeconds = floorf(total * slider.value);
    
    //转换成CMTime才能给player来控制播放进度
    
    CMTime dragedCMTime     = CMTimeMake(dragedSeconds, 1);
    
    [self endSlideTheVideo:dragedCMTime];
}


/**
 *  滑动结束视频跳转
 *
 *  @param dragedCMTime 视频跳转的CMTime
 */
- (void)endSlideTheVideo:(CMTime)dragedCMTime
{
    //[_player pause];
    
    [self.player seekToTime:dragedCMTime completionHandler:^(BOOL finish){
        // 如果点击了暂停按钮
        if (self.isPauseByUser) {
            
            return ;
        }
        [self play];
        if (!self.playerItem.isPlaybackLikelyToKeepUp ) {
            self.state = HPPlayerStateBuffering;
            
        }
    }];
}

/**
 *  从xx秒开始播放视频跳转
 *
 *  @param dragedSeconds 视频跳转的秒数
 */
- (void)seekToTime:(NSInteger)dragedSeconds completionHandler:(void (^)(BOOL finished))completionHandler
{
    if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
        // seekTime:completionHandler:不能精确定位
        // 如果需要精确定位，可以使用seekToTime:toleranceBefore:toleranceAfter:completionHandler:
        // 转换成CMTime才能给player来控制播放进度
        CMTime dragedCMTime = CMTimeMake(dragedSeconds, 1);
        [self.player seekToTime:dragedCMTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
            // 视频跳转回调
            if (completionHandler) { completionHandler(finished); }
            // 如果点击了暂停按钮
            if (self.isPauseByUser) return ;
            [self play];
            self.seekTime = 0;
            if (!self.playerItem.isPlaybackLikelyToKeepUp) {
                self.state = HPPlayerStateBuffering;
            }
            
        }];
    }
}


#pragma mark - layoutSubViews

- (void)layoutSubviews {

    [super layoutSubviews];
    
    self.playerLayer.frame = self.bounds;
    
    //重设frame
    [self resetFrame:self.bounds];
    
    [UIApplication sharedApplication].statusBarHidden = NO;
    
    if (!self.isPauseByUser) {
        // 只要屏幕旋转就显示控制层
        self.isMaskShowing = NO;
        // 延迟隐藏controlView
        [self animateShow];
    }
    
    [self layoutIfNeeded];
}

#pragma mark - 旋转屏幕

- (void)setRFrame:(CGRect)rFrame
{
    [self setFrame:rFrame];
    [self resetFrame:self.bounds];
}

/**
 *  重设frame
 */
-(void)resetFrame:(CGRect)frame {

    self.loadStatusView.frame = frame;
    [self.loadStatusView setNeedsLayout];
    _controlView.activity.centerX = self.isFullScreen?self.centerY:self.centerX;
    _controlView.activity.centerY = self.isFullScreen?self.centerX:self.centerY;
    _controlView.horizontalLabel.centerX = self.isFullScreen?self.center.y:self.center.x;
    _controlView.horizontalLabel.centerY = self.isFullScreen?self.center.x:self.center.y;
}

/**
 *  屏幕方向发生变化会调用这里
 */
- (void)onDeviceOrientationChange{
    
    UIDeviceOrientation orientation             = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortraitUpsideDown:{
            [self.controlView.fullScreenBtn setImage:[UIImage imageNamed:@"shrinkscreen"] forState:UIControlStateNormal];
            
            [self backOrientationPortrait];
            
        }
            break;
        case UIInterfaceOrientationPortrait:{
            [self.controlView.fullScreenBtn setImage:[UIImage imageNamed:@"player-fullscreen"] forState:UIControlStateNormal];
            
            [self backOrientationPortrait];
        }
            break;
        case UIInterfaceOrientationLandscapeLeft:{
            [self.controlView.fullScreenBtn setImage:[UIImage imageNamed:@"shrinkscreen"] forState:UIControlStateNormal];
            
            [self setDeviceOrientationLandscapeLeft];
        }
            break;
        case UIInterfaceOrientationLandscapeRight:{
            [self.controlView.fullScreenBtn setImage:[UIImage imageNamed:@"player-fullscreen"] forState:UIControlStateNormal];
            
            [self setDeviceOrientationLandscapeRight];
            
        }
            break;
            
        default:
            break;
    }
}


#pragma mark - 缓冲较差时候

/**
 *  缓冲较差时候回调这里
 */
- (void)bufferingSomeSecond
{
    [self.controlView.activity startAnimating];
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
    __block BOOL isBuffering = NO;
    if (isBuffering) {
        return;
    }
    isBuffering = YES;
    
    // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
    [self pause];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 如果此时用户已经暂停了，则不再需要开启播放了
        if (self.isPauseByUser) {
            isBuffering = NO;
            return;
        }
        
        [self play];
        // 如果执行了play还是没有播放则说明还没有缓存好，则再次缓存一段时间
        isBuffering = NO;
        if (!self.playerItem.isPlaybackLikelyToKeepUp) {
            [self bufferingSomeSecond];
        }
    });
}


#pragma mark - 计时器
/**
 *  创建timer
 */
- (void)createTimer {

    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(playerTimerAction) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}


#pragma mark - 计时器事件
- (void)playerTimerAction
{
    if (_playerItem.duration.timescale != 0) {
        self.controlView.videoSlider.value     = CMTimeGetSeconds([_playerItem currentTime]) / (_playerItem.duration.value / _playerItem.duration.timescale);//当前进度
        
        //当前时长进度progress
        NSInteger proMin                       = (NSInteger)CMTimeGetSeconds([_player currentTime]) / 60;//当前秒
        NSInteger proSec                       = (NSInteger)CMTimeGetSeconds([_player currentTime]) % 60;//当前分钟
        
        //duration 总时长
        NSInteger durMin                       = (NSInteger)_playerItem.duration.value / _playerItem.duration.timescale / 60;//总秒
        NSInteger durSec                       = (NSInteger)_playerItem.duration.value / _playerItem.duration.timescale % 60;//总分钟
        
        self.controlView.currentTimeLabel.text = [NSString stringWithFormat:@"%02zd:%02zd", proMin, proSec];
        self.controlView.totalTimeLabel.text   = [NSString stringWithFormat:@"%02zd:%02zd", durMin, durSec];
        
        
    }
}

/**
 *  计算缓冲进度
 *
 *  @return 缓冲进度
 */
- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [[_player currentItem] loadedTimeRanges];
    CMTimeRange timeRange     = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds        = CMTimeGetSeconds(timeRange.start);
    float durationSeconds     = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result     = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}


#pragma mark - 显示或者隐藏controlView

- (void)autoFadeOutControlBar
{
    if (!self.isMaskShowing) { return; }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControlView) object:nil];
    [self performSelector:@selector(hideControlView) withObject:nil afterDelay:HPPlayerAnimationTimeInterval];
    
}
/**
 *  显示controlView
 */
- (void)animateShow {

    if (self.isMaskShowing) { return; }
    [UIView animateWithDuration:HPPlayerControlBarAutoFadeOutTimeInterval animations:^{
        self.controlView.backBtn.alpha = 1;
        
        self.controlView.alpha = 1;
        
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
        
    } completion:^(BOOL finished) {
        
        self.isMaskShowing = YES;
        [self autoFadeOutControlBar];
        
    }];

}

/**
 *  隐藏控制层
 */
- (void)hideControlView
{
    if (!self.isMaskShowing) { return; }
    [UIView animateWithDuration:HPPlayerControlBarAutoFadeOutTimeInterval animations:^{
        self.controlView.alpha = 0;
        
        self.controlView.backBtn.alpha  = 0;
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    }completion:^(BOOL finished) {
        self.isMaskShowing = NO;
    }];
}

#pragma mark - Seter
- (void)setState:(HPPlayerState)state {

    _state = state;
    
     state == HPPlayerStateBuffering ? ([self.controlView.activity startAnimating]) : ([self.controlView.activity stopAnimating]);
}

//加载状态label的setter
-(void)setLoadingStatus:(NSString *)loadingStatus
{
    if (!loadingStatus) return;
    _loadingStatus = loadingStatus;
    
    self.loadStatusView.loadingStatus = loadingStatus;
}

#pragma mark - 懒加载
- (AVPlayer *)player {

    if (!_player) {
        
        _player = [AVPlayer playerWithPlayerItem:self.playerItem];
    }
    
    return _player;
}

- (HPPlayerControllerView *)controlView {

    if (_controlView == nil) {
        _controlView = [[HPPlayerControllerView alloc] init];
        
        [self addSubview:_controlView];
        
        [_controlView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.trailing.bottom.equalTo(self);
        }];
    }
    return _controlView;
}

- (HPPlayerLoadStatusView *)loadStatusView {

    if (_loadStatusView == nil) {
        _loadStatusView = [[HPPlayerLoadStatusView alloc] initWithFrame:self.bounds];
       
    }
    return _loadStatusView;
}

@end
