//
//  HQLTimeLineLayout.m
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/31.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import "HQLTimeLineLayout.h"

@interface HQLTimeLineLayout ()

@property (nonatomic, assign) CMTimeRange timeLineRange;

@end

@implementation HQLTimeLineLayout {
    double _timeLineLength;
    NSMutableArray *_headerCenterXArray; // 记录header的位置
    NSMutableArray *_footerCenterXArray; // 记录footer的位置
    CMTime _timeLineDuration; // 总时长
    HQLTimeAndLengthRatio *_timeLengthRatio; // 换算
    NSUInteger _coverSectionCount; // coverSectionCount
    
    double _itemHeight; // 高度
    
    NSMutableArray *_insertArray;
    NSMutableArray *_deleteArray;
}

#pragma mark - override method

- (void)prepareLayout {
    [super prepareLayout];
    
    if (!_headerCenterXArray) {
        _headerCenterXArray = [NSMutableArray array];
    }
    [_headerCenterXArray removeAllObjects];
    if (!_footerCenterXArray) {
        _footerCenterXArray = [NSMutableArray array];
    }
    [_footerCenterXArray removeAllObjects];
    
    // 获取一些必要的信息
    if (self.delegate && [self.delegate respondsToSelector:@selector(timeLineDurationWithCollectionView:layout:)]) {
        _timeLineDuration = [self.delegate timeLineDurationWithCollectionView:self.collectionView layout:self];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(timeLineTimeAndLengthRatioWithCollectionView:layout:)]) {
        _timeLengthRatio = [self.delegate timeLineTimeAndLengthRatioWithCollectionView:self.collectionView layout:self];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(numberOfCoverSectionWithCollectionView:layout:)]) {
        _coverSectionCount = [self.delegate numberOfCoverSectionWithCollectionView:self.collectionView layout:self];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(itemHeightWithCollectionView:layout:)]) {
        _itemHeight = [self.delegate itemHeightWithCollectionView:self.collectionView layout:self];
    }
}

- (CGSize)collectionViewContentSize {
    // 计算真正的长度
    _timeLineLength = [_timeLengthRatio calculateLengthWithTime:_timeLineDuration];
    return CGSizeMake(_timeLineLength, self.collectionView.frame.size.height);
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    // 直接计算全部的attributes
    NSMutableArray *attributes = [NSMutableArray array];

    // 遍历所有的section --- 包括coverSection
    /* // 这两个方法都在执行删除之后都不能获取正在的值
    [self.collectionView numberOfSections];
    [self.collectionView numberOfItemsInSection:0];
    //*/
    //NSInteger sectionCount = [self.collectionView.dataSource numberOfSectionsInCollectionView:self.collectionView];
    NSInteger sectionCount = [self.collectionView numberOfSections];
    
    double headerCenterX = 0;
    double footerCenterX = headerCenterX;
    
    for (NSInteger section = 0; section < sectionCount; section++) {
        
        // cell item
        //NSInteger numberOfItemsInSection = [self.collectionView.dataSource collectionView:self.collectionView numberOfItemsInSection:section];
        
        NSInteger numberOfItemsInSection = [self.collectionView numberOfItemsInSection:section];
        
        if (numberOfItemsInSection > 0) {
            
            for (NSInteger item = 0; item < numberOfItemsInSection; item++) {
                
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
                UICollectionViewLayoutAttributes *attri = [self layoutAttributesForItemAtIndexPath:indexPath];
                if (attri) {
                    [attributes addObject:attri];
                    
                    if (item == 0) { // 第一个
                        headerCenterX = attri.center.x - attri.size.width * 0.5;
                    } else if (item == (numberOfItemsInSection - 1)) { // 最后一个
                        footerCenterX = attri.center.x + attri.size.width * 0.5;
                    }
                    
                }
                NSAssert(attri, @"%s %d", __func__, __LINE__);
            }
            
        }
        
        [_headerCenterXArray addObject:@(headerCenterX)];
        [_footerCenterXArray addObject:@(footerCenterX)];
        
        // 如果上一个section有值，下一个section没值，那么下一个section的header和footer应该跟上一个section的footer重叠在一起
        headerCenterX = footerCenterX;
        
        // header and footer
        NSIndexPath *SupplementaryViewIndexPath = [NSIndexPath indexPathForItem:0 inSection:section];
        // header
        UICollectionViewLayoutAttributes *headerAttri = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:SupplementaryViewIndexPath];
        if (headerAttri) {
            [attributes addObject:headerAttri];
        }
        NSAssert(headerAttri, @"%s %d", __func__, __LINE__);
        
        // footer
        UICollectionViewLayoutAttributes *footerAttri = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionFooter atIndexPath:SupplementaryViewIndexPath];
        if (footerAttri) {
            [attributes addObject:footerAttri];
        }
        NSAssert(footerAttri, @"%s %d", __func__, __LINE__);
        
    }

    return attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    
    // 计算位置
    // 获取Item的timeRange
    CMTimeRange timeRange = kCMTimeRangeInvalid;
    if ([self.delegate respondsToSelector:@selector(collectionView:layout:itemTimeRangeForIndexPath:)]) {
        timeRange = [self.delegate collectionView:self.collectionView layout:self itemTimeRangeForIndexPath:indexPath];
    }
    NSAssert(CMTIMERANGE_IS_INVALID(timeRange) != YES, @"%s %d %@ %@", __func__, __LINE__, @"Invalid time range of indexPath", indexPath);
    
    // 判断timeRange是否合法
    //NSAssert(CMTimeRangeContainsTimeRange(self.timeLineRange, timeRange), @"%s %d %@ %@", __func__, __LINE__, @"Invalid time range of indexPath", indexPath);
    
    // 计算位置size
    double width = [_timeLengthRatio calculateLengthWithTime:timeRange.duration];
    
    // 计算center
    double centerY = self.collectionView.frame.size.height * 0.5;
    double startX = [_timeLengthRatio calculateLengthWithTime:timeRange.start];
    
    // 计算出来的结果有可能是超出范围的 --- 但不会导致崩毁
    //NSAssert(((startX + width) <= _timeLineLength), @"%s %d %@", __func__, __LINE__, @"Out of collection view content size");
    
    // 要加上inset
    double centerX = startX + width * 0.5;
    CGPoint center = CGPointMake(centerX, centerY);
    CGSize size = CGSizeMake(width, _itemHeight);
    
    attributes.center = center;
    attributes.size = size;
    
    return attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:elementKind withIndexPath:indexPath];
    
    if ([elementKind isEqualToString:UICollectionElementKindSectionHeader]) {
        
        // 获取size
        CGSize size = CGSizeZero;
        if (self.delegate && [self.delegate respondsToSelector:@selector(collectionView:layout:sizeForHeaderInSection:)]) {
            size = [self.delegate collectionView:self.collectionView layout:self sizeForHeaderInSection:indexPath.section];
        }
        
        attributes.size = size;
        
        double centerX = 0;
        @try {
            centerX = [[_headerCenterXArray objectAtIndex:indexPath.section] doubleValue];
        } @catch (NSException *exception) {
            NSAssert(NO, @"%s %d %@", __func__, __LINE__, exception);
        }
        
        CGPoint center = CGPointMake(centerX, self.collectionView.frame.size.height * 0.5);
        
        attributes.center = center;
        
    } else if ([elementKind isEqualToString:UICollectionElementKindSectionFooter]) {
        
        // 获取size
        CGSize size = CGSizeZero;
        if (self.delegate && [self.delegate respondsToSelector:@selector(collectionView:layout:sizeForFooterInSection:)]) {
            size = [self.delegate collectionView:self.collectionView layout:self sizeForFooterInSection:indexPath.section];
        }
        
        attributes.size = size;
        
        double centerX = 0;
        @try {
            centerX = [[_footerCenterXArray objectAtIndex:indexPath.section] doubleValue];
        } @catch (NSException *exception) {
            NSAssert(NO, @"%s %d %@", __func__, __LINE__, exception);
        }
        
        CGPoint center = CGPointMake(centerX, self.collectionView.frame.size.height * 0.5);
        
        attributes.center = center;
        
    } else {
        NSAssert(NO, @"%s %d %@ %@", __func__, __LINE__, @"Unsupport element kind", elementKind);
    }
    
    return attributes;
}

#pragma mark - update

- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems {
    [super prepareForCollectionViewUpdates:updateItems];
    
    // 暂时只有删除和插入
    _insertArray = [NSMutableArray array];
    _deleteArray = [NSMutableArray array];
    
    for (UICollectionViewUpdateItem *update in updateItems) {
        
        switch (update.updateAction) {
            case UICollectionUpdateActionInsert: {
                [_insertArray addObject:update.indexPathAfterUpdate];
                break;
            }
            case UICollectionUpdateActionDelete: {
                [_deleteArray addObject:update.indexPathBeforeUpdate];
                break;
            }
            
                // 其他的情况不考虑
            default: { break; }
        }
        
    }
    
}

- (void)finalizeCollectionViewUpdates {
    [super finalizeCollectionViewUpdates];
    
    [_insertArray removeAllObjects];
    _insertArray = nil;
    [_deleteArray removeAllObjects];
    _deleteArray = nil;
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath {
    
    UICollectionViewLayoutAttributes *attributes = [super initialLayoutAttributesForAppearingItemAtIndexPath:itemIndexPath];
    
    if ([_insertArray containsObject:itemIndexPath]) {
        if (!attributes) {
            attributes = [self layoutAttributesForItemAtIndexPath:itemIndexPath];
        }
        
        attributes.alpha = 0.0;
    }
    
    return attributes;
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)itemIndexPath {
    UICollectionViewLayoutAttributes *attributes = [super finalLayoutAttributesForDisappearingItemAtIndexPath:itemIndexPath];
    
    if ([_deleteArray containsObject:itemIndexPath]) {
        if (!attributes) {
            attributes = [self layoutAttributesForItemAtIndexPath:itemIndexPath];
        }
        
        attributes.alpha = 0.0;
    }
    
    return attributes;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    CGRect oldBounds = self.collectionView.bounds;
    if (CGRectGetWidth(newBounds) != CGRectGetWidth(oldBounds)) {
        return YES;
    }
    return NO;
}

#pragma mark - getter

- (CMTimeRange)timeLineRange {
    return CMTimeRangeMake(CMTimeMakeWithSeconds(0, 600), _timeLineDuration);
}

@end

@implementation HQLTimeAndLengthRatio {
    CMTime _timeDuration;
    double _lengthPerTimeDuration;
}

- (instancetype)initWithTimeDuration:(CMTime)timeDuration lengthPerTimeDuration:(double)lengthPerTimeDuration {
    if (self = [super init]) {
        _timeDuration = timeDuration;
        _lengthPerTimeDuration = lengthPerTimeDuration;
    }
    return self;
}

- (void)updateTimeDuration:(CMTime)duration {
    if (CMTimeCompare(duration, _timeDuration) == 0) {
        return;
    }
    _timeDuration = duration;
}

- (double)calculateLengthWithTime:(CMTime)time {
    double aTime = CMTimeGetSeconds(time);
    double timeDuration = CMTimeGetSeconds(self.timeDuration);
    return (aTime / timeDuration * self.lengthPerTimeDuration);
}

- (CMTime)calculateTimeWithLength:(double)length {
    double timeDuration = CMTimeGetSeconds(self.timeDuration);
    double time = (length / self.lengthPerTimeDuration * timeDuration);
    return CMTimeMakeWithSeconds(time, 600);
}

- (CMTime)timeDuration {
    return _timeDuration;
}

- (double)lengthPerTimeDuration {
    return _lengthPerTimeDuration;
}

@end
