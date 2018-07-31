//
//  HQLVideoItemCell.h
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/27.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HQLVideoItem;

@interface HQLVideoItemCell : UICollectionViewCell

@property (nonatomic, strong) HQLVideoItem *videoItem;

- (void)refreshWithTimeScale:(double)timeScale;

@end
