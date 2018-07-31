//
//  ViewController.m
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/23.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import "ViewController.h"

#import <Masonry.h>

#import "HQLVideoTimeLineManager.h"
#import "HQLVideoItem.h"

@interface ViewController ()

@property (nonatomic, strong) HQLVideoTimeLineManager *videoTimeLineManager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    [self prepareControllerData];
    [self prepareUI];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)dealloc {
    
    [self.videoTimeLineManager cleanMemory];
    
    NSLog(@"dealloc ---> %@", NSStringFromClass([self class]));
}

#pragma mark -

- (void)prepareControllerData {
    
    self.videoTimeLineManager = [[HQLVideoTimeLineManager alloc] init];
    
    HQLVideoItem *videoItem = [[HQLVideoItem alloc] init];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"andy.MP4" ofType:nil];
    videoItem.asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:path]];
    videoItem.timeRange = CMTimeRangeMake(kCMTimeZero, videoItem.asset.duration);
    
    [self.videoTimeLineManager updateVideoItems:@[videoItem, videoItem]];
}

- (void)prepareUI {
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    [collectionView setBackgroundColor:[UIColor clearColor]];
    collectionView.contentInset = UIEdgeInsetsMake(0, self.view.frame.size.width * 0.5, 0, self.view.frame.size.width * 0.5);
    collectionView.showsVerticalScrollIndicator = NO;
    collectionView.showsHorizontalScrollIndicator = NO;
    
    [self.view addSubview:collectionView];
    [self.videoTimeLineManager bindWithCollectionView:collectionView]; // 绑定
    
    [collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.view);
        make.height.mas_equalTo(120);
        make.left.right.equalTo(self.view);
    }];
    
    // timelineview
    UIView *lineView = [[UIView alloc] init];
    [self.view addSubview:lineView];
    [lineView setBackgroundColor:[UIColor orangeColor]];
    lineView.layer.cornerRadius = 0.5;
    lineView.layer.masksToBounds = YES;
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(collectionView.mas_top).offset(-15);
        make.bottom.equalTo(collectionView.mas_bottom).offset(15);
        make.width.mas_equalTo(1);
        make.centerX.equalTo(self.view);
    }];
    
}

@end
