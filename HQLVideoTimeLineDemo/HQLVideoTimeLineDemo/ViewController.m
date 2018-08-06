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

@interface ViewController () <HQLVideoTimeLineChangeDelegate>

@property (nonatomic, strong) HQLVideoTimeLineManager *videoTimeLineManager;

@property (nonatomic, strong) UILabel *totalLabel;
@property (nonatomic, strong) UILabel *currentLabel;

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
    self.videoTimeLineManager.delegate = self;
    
    HQLVideoItem *videoItem = [[HQLVideoItem alloc] init];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"andy.MP4" ofType:nil];
    videoItem.asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:path]];
    videoItem.timeRange = CMTimeRangeMake(kCMTimeZero, videoItem.asset.duration);
    
    HQLVideoItem *videoItem2 = [[HQLVideoItem alloc] init];
    videoItem2.asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:path]];
    videoItem2.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(10, 600));
    
    [self.videoTimeLineManager updateVideoItems:@[videoItem]];
}

- (void)prepareUI {
    
    HQLTimeLineLayout *layout = [[HQLTimeLineLayout alloc] init];
    HQLTimeLineView *collectionView = [[HQLTimeLineView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
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
    
    UILabel *total = [[UILabel alloc] init];
    total.textAlignment = NSTextAlignmentCenter;
    total.textColor = [UIColor redColor];
    total.font = [UIFont systemFontOfSize:20];
    [self.view addSubview:total];
    self.totalLabel = total;
    [total mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(lineView.mas_top).offset(-20);
    }];
    
    // 手动刷新
    [self timeLineManager:self.videoTimeLineManager timeLineView:self.videoTimeLineManager.timeLineView totalDuartionDidChange:self.videoTimeLineManager.totalDuration];
    
    UILabel *current = [[UILabel alloc] init];
    current.textAlignment = NSTextAlignmentCenter;
    current.textColor = [UIColor blueColor];
    current.font = [UIFont systemFontOfSize:20];
    [self.view addSubview:current];
    self.currentLabel = current;
    [current mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(total.mas_top).offset(-20);
    }];
    
    [self timeLineManager:self.videoTimeLineManager timeLineView:self.videoTimeLineManager.timeLineView didChangeOffset:0 targetOffset:0 time:self.videoTimeLineManager.currentTime];
    
    UIButton *insert = [UIButton buttonWithType:UIButtonTypeSystem];
    [insert setTitle:@"insert" forState:UIControlStateNormal];
    [insert addTarget:self action:@selector(insertButtonDidClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:insert];
    [insert mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(lineView.mas_bottom).offset(20);
        make.centerX.equalTo(self.view);
        make.height.mas_equalTo(30);
        make.width.mas_equalTo(80);
    }];
    
    UIButton *delete = [UIButton buttonWithType:UIButtonTypeSystem];
    [delete setTitle:@"delete" forState:UIControlStateNormal];
    [delete addTarget:self action:@selector(deleteButtonDidClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:delete];
    [delete mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(insert.mas_bottom).offset(20);
        make.centerX.equalTo(self.view);
        make.height.mas_equalTo(30);
        make.width.mas_equalTo(80);
    }];
}

#pragma mark - event

- (void)insertButtonDidClick {
    
    HQLVideoItem *videoItem2 = [[HQLVideoItem alloc] init];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"andy.MP4" ofType:nil];
    videoItem2.asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:path]];
    videoItem2.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(10, 600));
    
    [self.videoTimeLineManager insertVideoItemsAfterCurrentVideoItem:@[videoItem2]];
}

- (void)deleteButtonDidClick {
    [self.videoTimeLineManager removeCurrentVideoItem];
}

#pragma mark - HQLVideoTimeLineChangeDelegate

- (void)timeLineManager:(HQLVideoTimeLineManager *)manager timeLineView:(HQLTimeLineView *)timeLineView totalDuartionDidChange:(CMTime)totalDuration {
    NSUInteger seconds = CMTimeGetSeconds(totalDuration);
    self.totalLabel.text = [NSString stringWithFormat:@"%02lu:%02lu",seconds/60,seconds%60];
}

- (void)timeLineManager:(HQLVideoTimeLineManager *)manager timeLineView:(HQLTimeLineView *)timeLineView shouldSeekTime:(CMTime)seekTime {
    
}

- (void)timeLineManager:(HQLVideoTimeLineManager *)manager timeLineView:(HQLTimeLineView *)timeLineView didChangeOffset:(CGFloat)originOffset targetOffset:(CGFloat)targetOffset time:(CMTime)time {
    NSUInteger seconds = CMTimeGetSeconds(time);
    self.currentLabel.text = [NSString stringWithFormat:@"%02lu:%02lu",seconds/60,seconds%60];
}

@end
