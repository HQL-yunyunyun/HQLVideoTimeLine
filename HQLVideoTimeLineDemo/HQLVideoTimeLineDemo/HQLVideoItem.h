//
//  HQLVideoItem.h
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/26.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

@interface HQLVideoItem : NSObject

@property (nonatomic, strong) AVAsset *asset;

@property (nonatomic, assign) CMTimeRange timeRange; // 记录videoItem的timeRange

@end
