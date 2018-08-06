//
//  HQLThumbnailCellImageGetter.m
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/24.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import "HQLThumbnailCellImageGetter.h"

#import "HQLThumbnailCell.h"
#import "HQLThumbnailModel.h"

@interface HQLThumbnailCellImageGetter ()

@property (nonatomic, strong) NSOperationQueue *queue;

@property (nonatomic, strong) NSOperation *operation;

@property (nonatomic, strong) HQLThumbnailModel *currentModel;

@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;

@end

@implementation HQLThumbnailCellImageGetter

#pragma mark - initialize method

- (instancetype)init {
    if (self = [super init]) {
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.name = @"hql.HQLThumbnailCellImageGetter.queue";
        [self.queue setMaxConcurrentOperationCount:1]; // 最大并发数为1
    }
    return self;
}

- (void)dealloc {
    [self cleanMemory];
    NSLog(@"dealloc ---> %@", NSStringFromClass([self class]));
}

#pragma mark - event

- (void)cleanMemory {
    
    [self.operation cancel];
    self.operation = nil;
    [self.queue cancelAllOperations];
    self.queue = nil;
    
    self.fetchImageHandle = nil;
    self.currentModel = nil;
    [self.imageGenerator cancelAllCGImageGeneration];
    self.imageGenerator = nil;
}

- (AVAssetImageGenerator *)generatorWithModel:(HQLThumbnailModel *)model {
    return [self createAssetImageGeneratorWithModel:model];
}

- (void)generateThumbnailWithModel:(HQLThumbnailModel *)model {
    
    [self generateThumbnailWithModel:model mainThread:NO];
}

- (void)generateThumbnailWithModel:(HQLThumbnailModel *)model mainThread:(BOOL)isMainThread {
    self.currentModel = model;
    if (!model) {
        return;
    }
    
    if (isMainThread) { // 在主线程获取图片
        
        // 取消子线程当前获取图片的动作
        if (self.operation) {
            [self.operation cancel];
            self.operation = nil;
        }
        [self.queue cancelAllOperations];
        
        // 不能在异步调用主线程 --- 直接赋值
        //dispatch_async(dispatch_get_main_queue(), ^{
            AVAssetImageGenerator *imageGenerator = [self createAssetImageGeneratorWithModel:self.currentModel];
            if (!imageGenerator || !self.currentModel) {
                return;
            }
            
            // 创建图片
            CGImageRef image = [imageGenerator copyCGImageAtTime:self.currentModel.thumbnailTime actualTime:NULL error:nil];
            UIImage *aImage = [UIImage imageWithCGImage:image scale:0.1 orientation:UIImageOrientationUp];
            CGImageRelease(image);
            
            self.fetchImageHandle ? self.fetchImageHandle(aImage) : nil;
        //});
        
        return;
    }
    
    // 子线程获取
    if (self.operation) {
        [self.operation cancel];
        self.operation = nil;
    }
    
    __weak typeof(self) _self = self;
    self.operation = [NSBlockOperation blockOperationWithBlock:^{
        
        [_self generateThumbnail];
        
    }];
    
    [self.queue addOperation:self.operation];
}

- (void)generateThumbnail {
    AVAssetImageGenerator *imageGenerator = [self createAssetImageGeneratorWithModel:self.currentModel];
    if (!imageGenerator || !self.currentModel) {
        return;
    }
    
    // 创建图片
    CGImageRef image = [imageGenerator copyCGImageAtTime:self.currentModel.thumbnailTime actualTime:NULL error:nil];
    UIImage *aImage = [UIImage imageWithCGImage:image scale:0.1 orientation:UIImageOrientationUp];
    CGImageRelease(image);
    
    // 主线程中刷新
    dispatch_async(dispatch_get_main_queue(), ^{
        self.fetchImageHandle ? self.fetchImageHandle(aImage) : nil;
    });
}

- (AVAssetImageGenerator *)createAssetImageGeneratorWithModel:(HQLThumbnailModel *)model {
    
    if (!model.asset) {
        return nil;
    }
    
    if (self.imageGenerator) {
        [self.imageGenerator cancelAllCGImageGeneration]; // 取消所有的操作
        // 判断asset是否相同
        AVURLAsset *aAsset = (AVURLAsset *)self.imageGenerator.asset;
        AVURLAsset *bAsset = (AVURLAsset *)model.asset;
        if (![aAsset isKindOfClass:[AVURLAsset class]] || ![bAsset isKindOfClass:[AVURLAsset class]]) {
            // 创建一个新的
            self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:bAsset];
            self.imageGenerator.appliesPreferredTrackTransform = YES;
            return self.imageGenerator;
        }
        
        // 判断是否一样
        if ([aAsset.URL.absoluteString isEqualToString:bAsset.URL.absoluteString]) {
            return self.imageGenerator;
        }
        
        // 不一样
        self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:bAsset];
        self.imageGenerator.appliesPreferredTrackTransform = YES;
        return self.imageGenerator;
    }
    
    // 创建新的
    self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:model.asset];
    self.imageGenerator.appliesPreferredTrackTransform = YES;
    return self.imageGenerator;
}

@end
