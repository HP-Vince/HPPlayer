//
//  HPPlayerControllerView.h
//  HPPlayerDemo
//
//  Created by 胡鹏 on 9/1/16.
//  Copyright © 2016 Vince. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HPPlayer.h"

typedef void(^SliderTapBlock)(CGFloat value);

@interface HPPlayerControllerView : UIView

/**
* 开始播放按钮
*/
@property (nonatomic, strong, readonly) UIButton                *startBtn;

/**
 * 当前播放时长label
 */
@property (nonatomic, strong, readonly) UILabel                 *currentTimeLabel;

/**
 * 视频总时长label
 */
@property (nonatomic, strong, readonly) UILabel                 *totalTimeLabel;

/**
 * 缓冲进度条
 */
@property (nonatomic, strong, readonly) UIProgressView          *progressView;
/**
 *  滑杆
 */
@property (nonatomic, strong, readonly) UISlider                *videoSlider;
/**
 *  全屏按钮
 */
@property (nonatomic, strong, readonly) UIButton                *fullScreenBtn;
/**
 *  快进快退label
 */
@property (nonatomic, strong, readonly) UILabel                 *horizontalLabel;
/**
 *  等待菊花
 */
@property (nonatomic, strong, readonly) UIActivityIndicatorView *activity;

/**
 *  返回按钮
 */
@property (nonatomic, strong, readonly) UIButton                *backBtn;
/**
 *  重播按钮
 */
@property (nonatomic, strong, readonly) UIButton                *repeatBtn;
/**
 *  bottomView
 */
@property (nonatomic, strong, readonly) UIImageView             *bottomImageView;
/**
 *  topView
 */
@property (nonatomic, strong, readonly) UIImageView             *topImageView;
/**
 *  播放按钮
 */
@property (nonatomic, strong, readonly) UIButton                *playeBtn;

/**
 *  进度条手势的Block
 */
@property (nonatomic, copy  ) SliderTapBlock                    tapBlock;

/**
 * 重置ControlView
 */
- (void)resetControlView;

/**
 *  显示topImageView和bottomImageView
 */
- (void)showControlView;

/**
 *  隐藏topImageView和bottomImageView
 */
- (void)hideControlView;

@end
