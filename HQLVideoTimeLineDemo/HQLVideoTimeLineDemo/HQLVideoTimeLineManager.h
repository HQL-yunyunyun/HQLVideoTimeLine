//
//  HQLVideoTimeLineManager.h
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/26.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HQLTimeLineView.h"
/*
 用来管理时间线
 */

@class HQLVideoItem, HQLVideoTimeLineManager;

/*
 关于时间线变化的delegate
 */
@protocol HQLVideoTimeLineChangeDelegate <NSObject>

/**
 滑动时间条 --- 不应该做刷新画面的动作，在这个代理回调中不应该做计算量太大的动作

 @param manager manager
 @param timeLineView timeLineView
 @param originOffset 原原本本返回的contentOffset
 @param targetOffset 转换后的offset
 @param time offset转换成的时间
 */
- (void)timeLineManager:(HQLVideoTimeLineManager *)manager timeLineView:(HQLTimeLineView *)timeLineView didChangeOffset:(CGFloat)originOffset targetOffset:(CGFloat)targetOffset time:(CMTime)time;

/**
 刷新当前播放的画面 --- 在这个代理回调中不应该进行计算量太大的动作

 @param manager manager
 @param timeLineView timeLineView
 @param seekTime seekTime
 */
- (void)timeLineManager:(HQLVideoTimeLineManager *)manager timeLineView:(HQLTimeLineView *)timeLineView shouldSeekTime:(CMTime)seekTime;

@optional

/**
 时长改变了
 */
- (void)timeLineManager:(HQLVideoTimeLineManager *)manager timeLineView:(HQLTimeLineView *)timeLineView totalDuartionDidChange:(CMTime)totalDuration;

@end

@interface HQLVideoTimeLineManager : NSObject

@property (nonatomic, strong, readonly) NSMutableArray <HQLVideoItem *>*videoItems;

@property (nonatomic, strong, readonly) HQLTimeAndLengthRatio *timeLengthRatio;

/**
 时间线
 */
@property (nonatomic, strong, readonly) HQLTimeLineView *timeLineView;

/**
 当前显示的videoItem
 */
@property (nonatomic, strong, readonly) HQLVideoItem *currentVideoItem;

/**
 当前时间
 */
@property (nonatomic, assign, readonly) CMTime currentTime;

/**
 总时长
 */
@property (nonatomic, assign, readonly) CMTime totalDuration;

/**
 代理
 */
@property (nonatomic, weak) id<HQLVideoTimeLineChangeDelegate> delegate;

#pragma mark -

- (void)cleanMemory;

/**
 绑定collectionView为timeLineView
 方法里面会将delegate和dataSource这两个代理指向VideoTimeLineManager
 注册cell方法
 将会对collectionView添加缩放手势
 HQLTimeLineLayoutDelegate将会指向VideoTimeLineManager
 */
- (void)bindWithCollectionView:(HQLTimeLineView *)collectionView;

#pragma mark - VideoItems Operation method

/**
 更新视频源 --- 会触发[self.videoItems removeAllObject]
 */
- (void)updateVideoItems:(NSArray <HQLVideoItem *>*)videoItems;

/**
 在当前Item之后批量插入videoItem
 */
- (void)insertVideoItemsAfterCurrentVideoItem:(NSArray <HQLVideoItem *>*)videoItems;

/**
 批量插入 --- 如果index大小当前videoItems.count那么就执行addObject的操作
 */
- (void)insertVideoItems:(NSArray <HQLVideoItem *>*)videoItems index:(NSUInteger)index;

/**
 删除某个Item
 */
- (void)removeVideoItemAtIndex:(NSUInteger)index;

/**
 删除当前的videoItem
 */
- (void)removeCurrentVideoItem;

@end
