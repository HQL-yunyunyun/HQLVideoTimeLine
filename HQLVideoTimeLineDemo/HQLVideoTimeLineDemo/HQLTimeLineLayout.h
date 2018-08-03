//
//  HQLTimeLineLayout.h
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/31.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <CoreMedia/CoreMedia.h>

/*
 视频时间线的layout，以时间为驱动，目前这个布局的时间和长度的换算比例都是一致的，而且每一个section之间的空隙为0。
 可以在正真的时间线上覆盖cell，这些覆盖的cell以section的形式来表现。
 显示为只有一条水平滑动的View，显示缩略图的cell之间没有间隙。
 垂直居中显示。
 section.headerView 的位置将在section.left。
 section.footerView 的位置将在section.right。
 */

@class HQLTimeAndLengthRatio, HQLTimeLineLayout;

@protocol HQLTimeLineLayoutDelegate <NSObject>

/**
 总时长
 */
- (CMTime)timeLineDurationWithCollectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout;

/**
 时长的换算
 */
- (HQLTimeAndLengthRatio *)timeLineTimeAndLengthRatioWithCollectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout;

/**
 返回每个Item的高度
 */
- (double)itemHeightWithCollectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout;

/**
 返回每个Item的时间范围 --- 以此来计算Item的size
 */
- (CMTimeRange)collectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout itemTimeRangeForIndexPath:(NSIndexPath *)indexPath;

@optional

/**
 coverCell的section个数，这个section的个数是包含在collectionView的numberOfSection中的。
 所以这里的意思就是：collectionView最后的 numberOfCoverSection 都为coverSection
 */
- (NSUInteger)numberOfCoverSectionWithCollectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout;

/**
 section.footer 的 size
 */
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout sizeForFooterInSection:(NSInteger)section;

/**
 section.header 的size
 */
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout sizeForHeaderInSection:(NSInteger)section;

@end

@interface HQLTimeLineLayout : UICollectionViewLayout

@property (nonatomic, weak) id<HQLTimeLineLayoutDelegate> delegate;

@end


/**
 记录时间轴显示时间的 时间 和 长度的比例
 例: 1秒的长度为100px
 */
@interface HQLTimeAndLengthRatio : NSObject

/**
 时间长度
 */
@property (nonatomic, assign, readonly) CMTime timeDuration;

/**
 每一个时间长度代表的length --- 一旦生成了就不能改变
 */
@property (nonatomic, assign, readonly) double lengthPerTimeDuration;

- (instancetype)initWithTimeDuration:(CMTime)timeDuration lengthPerTimeDuration:(double)lengthPerTimeDuration;

/**
 更新 timeDuration属性
 */
- (void)updateTimeDuration:(CMTime)duration;

/**
 根据time来计算length
 */
- (double)calculateLengthWithTime:(CMTime)time;

/**
 根据length来计算time
 */
- (CMTime)calculateTimeWithLength:(double)length;

@end
