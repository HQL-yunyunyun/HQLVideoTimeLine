//
//  HQLTimeLineView.m
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/31.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import "HQLTimeLineView.h"

@implementation HQLTimeLineView

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout {
    NSAssert([layout isKindOfClass:[HQLTimeLineLayout class]], @"%s %d %@", __func__, __LINE__, @"Unsupport layout");
    if (self = [super initWithFrame:frame collectionViewLayout:layout]) {
        
    }
    return self;
}

@end
