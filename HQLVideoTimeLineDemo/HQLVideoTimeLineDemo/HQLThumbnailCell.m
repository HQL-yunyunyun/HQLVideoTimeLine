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

@interface HQLThumbnailCell ()

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) HQLThumbnailCellImageGetter *imageGetter;

@property (nonatomic, strong) UILabel *lastLabel;
@property (nonatomic, strong) UILabel *currentLabel;

@end

@implementation HQLThumbnailCell


#pragma mark - initialize method

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        
        self.imageGetter = [[HQLThumbnailCellImageGetter alloc] init];
        __weak typeof(self) _self = self;
        self.imageGetter.fetchImageHandle = ^(UIImage *image) {
            _self.thumbnail = image;
        };
        
        self.currentPath = -1;
        self.lastPath = -1;
        
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

@end
