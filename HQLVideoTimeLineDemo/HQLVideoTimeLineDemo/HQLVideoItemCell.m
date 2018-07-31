//
//  HQLVideoItemCell.m
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/27.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import "HQLVideoItemCell.h"

#import <Masonry.h>

#import "HQLThumbnailModel.h"
#import "HQLVideoItem.h"
#import "HQLThumbnailCellImageGetter.h"

#import "HQLThumbnailCell.h"

@interface HQLVideoItemCell () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;

@property (nonatomic, assign) double timeScale;

@end

@implementation HQLVideoItemCell


#pragma mark - initialize method

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self prepareUI];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"dealloc ---> %@", NSStringFromClass([self class]));
}

#pragma mark - prepareUI

- (void)prepareUI {
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    [collectionView setBackgroundColor:[UIColor clearColor]];
    collectionView.delegate = self;
    collectionView.dataSource = self;
    collectionView.showsVerticalScrollIndicator = NO;
    collectionView.showsHorizontalScrollIndicator = NO;
    [collectionView registerClass:[HQLThumbnailCell class] forCellWithReuseIdentifier:@"reuseId"];
    
    collectionView.scrollEnabled = NO;
    
    [self.contentView addSubview:collectionView];
    [collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentView);
    }];
    
}

#pragma mark - event

/**
 根据indexPath计算每个cell显示的画面时间
 */
- (CMTime)calculateItemTimeWithIndex:(NSInteger)index {
    HQLVideoItem *item = self.videoItem;
    
    // 计算真正的时间
    CMTime timeScale = CMTimeMakeWithSeconds(self.timeScale, 600);
    CMTime time = CMTimeMultiply(timeScale, (int)index);
    if (CMTimeCompare(time, item.timeRange.duration) >= 0) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Invalid time.");
        time = item.asset.duration; // 永远不会达到这个范围
    }
    CMTime start = item.timeRange.start;
    time = CMTimeAdd(start, time);
    return time;
}

- (void)refreshWithTimeScale:(double)timeScale {
    if (_timeScale == timeScale) {
        return;
    }
    NSLog(@"timeScale : %f", timeScale);
    self.timeScale = timeScale;
    [self.collectionView reloadData];
}

#pragma mark - collectionView delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (!_videoItem) {
        return 0;
    }
    double duration = CMTimeGetSeconds(self.videoItem.timeRange.duration);
    NSInteger count = duration / self.timeScale;
    double remainder = duration - (count * self.timeScale);
    if (remainder > 0) {
        count += 1;
    }
    return count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    // 计算每个cell的大小
    NSInteger sectionCount = [self collectionView:collectionView numberOfItemsInSection:indexPath.section];
    
//    CGFloat size = self.collectionView.frame.size.height;
    CGFloat size = 100;
    
    if (indexPath.item != (sectionCount - 1)) {
        // 不是最后一个
        return CGSizeMake(size, size);
    }
    // 这个时间是相对于asset的
    CMTime currentItemTime = [self calculateItemTimeWithIndex:indexPath.item];
    // 所以这里也得相对于asset的时间来计算
    CMTime currentItemDuration = CMTimeSubtract(CMTimeAdd(self.videoItem.timeRange.start, self.videoItem.timeRange.duration), currentItemTime);
    
    double duration = CMTimeGetSeconds(currentItemDuration);
    double width = duration / self.timeScale * size;
    return CGSizeMake(width, size);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    HQLVideoItem *item = self.videoItem;
    
    // 计算真正的时间
    CMTime time = [self calculateItemTimeWithIndex:indexPath.item];
    
    // 获取图片
    HQLThumbnailModel *model = [[HQLThumbnailModel alloc] init];
    model.asset = item.asset;
    model.thumbnailTime = time;
    HQLThumbnailCell *_cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"reuseId" forIndexPath:indexPath];
    
    [_cell.imageGetter generateThumbnailWithModel:model];
    
    return _cell;
}

#pragma mark - setter & getter

@end
