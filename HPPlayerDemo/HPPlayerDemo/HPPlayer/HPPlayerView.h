//
//  HPPlayerView.h
//  HPPlayerDemo
//
//  Created by 胡鹏 on 9/1/16.
//  Copyright © 2016 Vince. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^PlayerGoBackBlock)(void);

@interface HPPlayerView : UIView

/**
 *  视频URL
 */
@property (nonatomic, strong) NSURL *videoURL;
/**
 * 返回按钮的block
 */

@property (nonatomic, copy) PlayerGoBackBlock goBackBlock;

/**
 * 播放前占位图片的名称，不设置就显示默认占位图（需要在设置视频URL之前设置） 
 */
@property (nonatomic, copy) NSString               *placeholderImageName;

/** 
 * 从xx秒开始播放视频跳转 
 */
@property (nonatomic, assign) NSInteger            seekTime;

@property (nonatomic, assign) CGRect rFrame;

@property (nonatomic,assign) BOOL isRightRotation;

//视频加载状态指示
@property (nonatomic,copy) NSString * loadingStatus;

/** ViewController中页面是否消失 */
//@property (nonatomic, assign) BOOL                viewDisappear;
//@property (nonatomic, assign) CGRect rFrame;

/**
 *  取消延时隐藏controlView的方法,在ViewController的delloc方法中调用
 *  用于解决：刚打开视频播放器，就关闭该页面，maskView的延时隐藏还未执行。
 */
//- (void)cancelAutoFadeOutControlBar;

/**
 *  重置player
 */
- (void)resetPlayer;

/**
 *  播放
 */
- (void)play;
/**
 * 暂停
 */
- (void)pause;


@end
