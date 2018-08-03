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

/**
 记录videoItem的timeRange
 */
@property (nonatomic, assign) CMTimeRange timeRange; 

/**
 记录在timeLine开始的时间
 */
@property (nonatomic, assign) CMTime startTimeInTimeLine;

@end
