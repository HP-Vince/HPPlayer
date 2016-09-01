//
//  HPPlayerLoadStatusView.h
//  HPPlayerDemo
//
//  Created by 胡鹏 on 9/1/16.
//  Copyright © 2016 Vince. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HPPlayerLoadStatusView : UIView

@property (nonatomic,copy) NSString * loadingStatus;

// 重置加载状态View
-(void)resetLoadingView;



@end
