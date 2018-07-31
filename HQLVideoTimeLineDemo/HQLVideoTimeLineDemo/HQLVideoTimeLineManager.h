//
//  HQLVideoTimeLineManager.h
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/26.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import <UIKit/UIKit.h>

/*
 用来管理时间线
 */

@class HQLVideoItem;

@interface HQLVideoTimeLineManager : NSObject

@property (nonatomic, strong, readonly) NSMutableArray <HQLVideoItem *>*videoItems;

@property (nonatomic, assign, readonly) double timeScale;

/**
 时间线
 */
@property (nonatomic, strong, readonly) UICollectionView *timeLineView;

/**
 更新视频源 --- 会触发[self.videoItems removeAllObject]
 */
- (void)updateVideoItems:(NSArray <HQLVideoItem *>*)videoItems;

- (void)cleanMemory;

/**
 绑定collectionView为timeLineView
 方法里面会将delegate和dataSource这两个代理指向VideoTimeLineManager
 注册cell方法
 将会对collectionView添加缩放手势
 */
- (void)bindWithCollectionView:(UICollectionView *)collectionView;

@end
