//
//  ViewController.m
//  HPPlayerDemo
//
//  Created by 胡鹏 on 9/1/16.
//  Copyright © 2016 Vince. All rights reserved.
//

#import "ViewController.h"
#import "AVDetailViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (IBAction)buttonAction:(UIButton *)sender {
    
    [self.navigationController pushViewController:[AVDetailViewController new] animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
