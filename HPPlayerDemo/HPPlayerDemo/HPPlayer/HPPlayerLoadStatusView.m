//
//  HPPlayerLoadStatusView.m
//  HPPlayerDemo
//
//  Created by 胡鹏 on 9/1/16.
//  Copyright © 2016 Vince. All rights reserved.
//

#import "HPPlayerLoadStatusView.h"
#import <UIView+YYAdd.h>
#import <UIFont+YYAdd.h>
#import <NSString+YYAdd.h>

@interface HPPlayerLoadStatusView ()

@property (nonatomic,copy) NSMutableArray * stastuss;

@end

@implementation HPPlayerLoadStatusView

-(instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        
        self.backgroundColor = [UIColor whiteColor];
        
    }
    return self;
}

-(NSMutableArray *)stastuss
{
    if (!_stastuss) {
        _stastuss = [NSMutableArray array];
    }
    return _stastuss;
}

#pragma mark - 视频加载指示label
-(void)setLoadingStatus:(NSString *)loadingStatus
{
    if (!loadingStatus) return;
    
    [self addStatusWithStr:loadingStatus];
}

-(void)addStatusWithStr:(NSString *)status
{
    UILabel * statusLabel = [UILabel new];
    statusLabel.font = [UIFont systemFontOfSize:14];
    statusLabel.textColor = [UIColor lightGrayColor];
    statusLabel.text = status;
    [self addSubview:statusLabel];
    
    [self.stastuss addObject:statusLabel];
    
    [self reSetStatusFrame];
}

-(void)resetLoadingView
{
    [self.stastuss removeAllObjects];
    [self removeAllSubviews];
    [self removeFromSuperview];
}

-(void)reSetStatusFrame
{
    NSInteger num=0;
    for (NSInteger i=self.stastuss.count-1; i>=0; i--) {
        num++;
        UILabel * statusLabel = self.stastuss[i];
        statusLabel.frame = CGRectMake(0, self.height-num* 20 - 40, [statusLabel.text widthForFont:statusLabel.font], 20);
    }
}


@end
