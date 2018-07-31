//
//  HQLThumbnailModel.h
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/23.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface HQLThumbnailModel : NSObject

@property (nonatomic, strong) AVAsset *asset;

@property (nonatomic, assign) CMTime thumbnailTime;

@end
