//
//  HQLThumbnailCell.m
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/23.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import "HQLThumbnailCell.h"
#import "HQLThumbnailCellImageGetter.h"
#import <Masonry.h>

#define kMargin 2
#define kcornerRadius 5

@interface HQLThumbnailCell ()

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) HQLThumbnailCellImageGetter *imageGetter;

@property (nonatomic, strong) UILabel *lastLabel;
@property (nonatomic, strong) UILabel *currentLabel;

/**
 masks layer
 */
@property (nonatomic, strong) CAShapeLayer *roundCornerLayer;

@end

@implementation HQLThumbnailCell


#pragma mark - initialize method

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        
        self.imageGetter = [[HQLThumbnailCellImageGetter alloc] init];
        __weak typeof(self) _self = self;
        self.imageGetter.fetchImageHandle = ^(UIImage *image) {
            _self.thumbnail = image;
            
            // 回调
            _self.imageGetterCallBackHandle ? _self.imageGetterCallBackHandle(image, _self.imageGetter) : nil;
            
        };
        
        self.currentPath = -1;
        self.lastPath = -1;
        
        self.contentView.layer.masksToBounds = YES;
        
        [self prepareUI];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"dealloc ---> %@", NSStringFromClass([self class]));
}

#pragma mark - prepareUI

- (void)prepareUI {
    UIImageView *imageView = [[UIImageView alloc] init];
    self.imageView = imageView;
    [self.contentView addSubview:imageView];
    imageView.layer.masksToBounds = YES;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentView);
    }];
    
    self.lastLabel = [[UILabel alloc] init];
    self.lastLabel.font = [UIFont systemFontOfSize:20];
    self.lastLabel.textColor = [UIColor blueColor];
    [self.lastLabel setTextAlignment:NSTextAlignmentCenter];
    [self.contentView addSubview:self.lastLabel];
    [self.lastLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.right.left.equalTo(self.contentView);
        make.height.equalTo(self.contentView).multipliedBy(0.5);
    }];
    
    self.currentLabel = [[UILabel alloc] init];
    self.currentLabel.font = [UIFont systemFontOfSize:20];
    self.currentLabel.textColor = [UIColor redColor];
    [self.currentLabel setTextAlignment:NSTextAlignmentCenter];
    [self.contentView addSubview:self.currentLabel];
    [self.currentLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.right.left.equalTo(self.contentView);
        make.height.equalTo(self.contentView).multipliedBy(0.5);
    }];
}

#pragma mark - event

- (void)updateRoundCornersWithIsSingleCell:(BOOL)isSingleCell isLastCell:(BOOL)isLastCell isFirstCell:(BOOL)isFirstCell isFirstSection:(BOOL)isFirstSection isLastSection:(BOOL)isLastSection isSingleSection:(BOOL)isSingleSection cellSize:(CGSize)cellSize {
    
    NSInteger type = [self roundCornerTypeWithIsSingleCell:isSingleCell isLastCell:isLastCell isFirstCell:isFirstCell];
    
    CGRect aRect = CGRectMake(0, 0, cellSize.width, cellSize.height);
    
    switch (type) {
        case 0: {
            
            CGRect rect = CGRectMake(0, 0, 100, 100);
            rect.size = cellSize;
            UIBezierPath *path = [UIBezierPath bezierPathWithRect:rect];
            
//            CAShapeLayer *layer = [[CAShapeLayer alloc] init];
//            layer.frame = rect;
//            layer.path = path.CGPath;
////            layer.backgroundColor = [UIColor redColor].CGColor;
//            self.contentView.layer.mask = layer;
            
            self.roundCornerLayer.path = path.CGPath;
            self.roundCornerLayer.frame = aRect;
            self.contentView.layer.mask = self.roundCornerLayer;
            
            break;
        }
        case 1: {
            
            CGFloat x = kMargin;
            if (isFirstSection) {
                x = 0;
            }
            CGFloat width = cellSize.width - x;
            CGFloat height = cellSize.height;
            CGRect rect = CGRectMake(x, 0, width, height);
            
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:UIRectCornerTopLeft | UIRectCornerBottomLeft cornerRadii:CGSizeMake(kcornerRadius, kcornerRadius)];
            
//            CAShapeLayer *layer = [[CAShapeLayer alloc] init];
//            layer.path = path.CGPath;
//            layer.frame = rect;
////            layer.backgroundColor = [UIColor redColor].CGColor;
//            self.contentView.layer.mask = layer;
            
            self.roundCornerLayer.path = path.CGPath;
            self.roundCornerLayer.frame = aRect;
            self.contentView.layer.mask = self.roundCornerLayer;
            
            break;
        }
        case 2: {
            
            CGFloat width = cellSize.width;
            if (!isLastSection) {
                width -= kMargin;
            }
            CGFloat height = cellSize.height;
            CGRect rect = CGRectMake(0, 0, width, height);
            
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:UIRectCornerTopRight | UIRectCornerBottomRight cornerRadii:CGSizeMake(kcornerRadius, kcornerRadius)];
            
//            CAShapeLayer *layer = [[CAShapeLayer alloc] init];
//            layer.path = path.CGPath;
//            layer.frame = rect;
////            layer.backgroundColor = [UIColor redColor].CGColor;
//            self.contentView.layer.mask = layer;
            
            self.roundCornerLayer.path = path.CGPath;
            self.roundCornerLayer.frame = aRect;
            self.contentView.layer.mask = self.roundCornerLayer;
            
            break;
        }
            
        case 3: {
            
            CGFloat width = cellSize.width;
            CGFloat x = 0;
            if (!isSingleSection) {
                
                if (isLastSection) {
                    width -= kMargin;
                    x = kMargin;
                } else if (isFirstSection) {
                    width -= kMargin;
                } else {
                    width -= (2 * kMargin);
                    x = kMargin;
                }
                
            }
            
            CGFloat height = cellSize.height;
            CGRect rect = CGRectMake(x, 0, width, height);
            
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(kcornerRadius, kcornerRadius)];
            
            self.roundCornerLayer.path = path.CGPath;
            self.roundCornerLayer.frame = aRect;
            self.contentView.layer.mask = self.roundCornerLayer;
            
//            CAShapeLayer *layer = [[CAShapeLayer alloc] init];
//            layer.path = path.CGPath;
//            layer.frame = rect;
//            self.contentView.layer.mask = layer;
            
            break;
        }
        default: { break; }
    }
}

// 0 --- 不显示 / 1 --- 显示左边 / 2 --- 显示右边 / 3 --- 显示全部
- (NSInteger)roundCornerTypeWithIsSingleCell:(BOOL)isSingleCell isLastCell:(BOOL)isLastCell isFirstCell:(BOOL)isFirstCell {
    
    if (!isSingleCell) { // 不是单独的cell
        
        if (isFirstCell) { // 第一个cell
            return 1; // 显示左边
        }
        
        if (isLastCell) { // 最后一个cell
            return 2; // 显示右边
        }
        
        // 都不是
        return 0; // 不显示
    }
    
    // 单独的cell
    return 3; // 显示全部
}

#pragma mark - setter & getter

- (void)setCurrentPath:(NSInteger)currentPath {
    self.lastPath = _currentPath;
    _currentPath = currentPath;
    [self.currentLabel setText:[NSString stringWithFormat:@"%@", [NSString stringWithFormat:@"%ld", currentPath]]];
    if (self.lastPath == -1) {
        self.lastPath = currentPath;
    }
    [self.lastLabel setText:[NSString stringWithFormat:@"%@", [NSString stringWithFormat:@"%ld", self.lastPath]]];
}

- (void)setThumbnail:(UIImage *)thumbnail {
    _thumbnail = thumbnail;
    self.imageView.image = thumbnail;
}

- (CAShapeLayer *)roundCornerLayer {
    if (!_roundCornerLayer) {
        _roundCornerLayer = [[CAShapeLayer alloc] init];
    }
    return _roundCornerLayer;
}

@end
