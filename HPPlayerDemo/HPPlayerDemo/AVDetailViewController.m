//
//  AVDetailViewController.m
//  HPPlayerDemo
//
//  Created by 胡鹏 on 9/1/16.
//  Copyright © 2016 Vince. All rights reserved.
//

#import "AVDetailViewController.h"
#import "HPPlayerView.h"
#import "HPPlayer.h"

@interface AVDetailViewController ()

@property (nonatomic, strong) HPPlayerView *playerView;

@end

@implementation AVDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self playerView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    [self.playerView pause];
    
    [self.playerView removeFromSuperview];
    
    self.playerView = nil;
}

- (HPPlayerView *)playerView {
    
    if (_playerView == nil) {
        
        _playerView = [[HPPlayerView alloc] initWithFrame:CGRectMake(0, 20, ScreenWidth, ScreenHeight/2)];
        
        typeof(self) weakSelf = self;
        _playerView.goBackBlock = ^{
            
            [weakSelf.navigationController popViewControllerAnimated:YES];
        };
        
        _playerView.loadingStatus = @"正在获取视频地址";
        
        [self.view addSubview:_playerView];
        
        
        NSURL *url = [NSURL URLWithString:@"http://baobab.cdn.wandoujia.com/14468618701471.mp4"];
        
        _playerView.loadingStatus = @"正在加载视频...";
        
        [_playerView setVideoURL:url];
        
    }
    return _playerView;
}

- (void)dealloc {
    
    NSLog(@"%s", __FUNCTION__);
}


@end
