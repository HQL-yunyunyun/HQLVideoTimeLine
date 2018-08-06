//
//  HQLThumbnailCellImageGetter.h
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/24.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>

@class HQLThumbnailCell, HQLThumbnailModel;

@interface HQLThumbnailCellImageGetter : NSObject

@property (nonatomic, strong, readonly) HQLThumbnailModel *currentModel;

@property (nonatomic, copy) void(^fetchImageHandle)(UIImage *image);

/**
 获取图片 --- 默认子线程
 */
- (void)generateThumbnailWithModel:(HQLThumbnailModel *)model;

/**
 是否在主线程获取图片
 */
- (void)generateThumbnailWithModel:(HQLThumbnailModel *)model mainThread:(BOOL)isMainThread;

- (AVAssetImageGenerator *)generatorWithModel:(HQLThumbnailModel *)model;

- (void)cleanMemory;

@end
