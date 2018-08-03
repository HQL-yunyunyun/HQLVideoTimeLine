//
//  HQLThumbnailCell.h
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/23.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HQLThumbnailCellImageGetter;

@interface HQLThumbnailCell : UICollectionViewCell

@property (nonatomic, assign) NSInteger lastPath;

@property (nonatomic, assign) NSInteger currentPath;

@property (nonatomic, strong) UIImage *thumbnail;

@property (nonatomic, strong, readonly) HQLThumbnailCellImageGetter *imageGetter;

- (void)updateRoundCornersWithIsSingleCell:(BOOL)isSingleCell isLastCell:(BOOL)isLastCell isFirstCell:(BOOL)isFirstCell isFirstSection:(BOOL)isFirstSection isLastSection:(BOOL)isLastSection isSingleSection:(BOOL)isSingleSection cellSize:(CGSize)cellSize;

@end
