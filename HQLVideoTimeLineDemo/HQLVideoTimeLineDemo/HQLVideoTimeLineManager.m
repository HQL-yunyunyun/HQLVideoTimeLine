//
//  HQLVideoTimeLineManager.m
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/26.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import "HQLVideoTimeLineManager.h"

#import "HQLVideoItem.h"

//#import "HQLVideoItemCell.h"

#import "HQLThumbnailModel.h"
#import "HQLThumbnailCell.h"
#import "HQLThumbnailCellImageGetter.h"

#import <pthread.h>
#import <AVFoundation/AVFoundation.h>

@interface HQLVideoTimeLineManager () <UICollectionViewDelegate, UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) NSMutableArray <HQLVideoItem *>*videoItems;

/**
 表示一个标准cell显示的时间
 */
@property (nonatomic, assign) double timeScale;

@property (nonatomic, assign) double lastScale;

/**
 视频长度 --- 只有在updateVideoItems的时候才会更新
 */
@property (nonatomic, assign) double totalDuration;

/**
 时间线
 */
@property (nonatomic, strong) UICollectionView *timeLineView;

@property (nonatomic, assign) BOOL isDurationPinch;

/**
 记录缩放前的宽度
 */
@property (nonatomic, assign) double beforePinchWidth;

/**
 当前计算的timeScale
 目前缩放的时候，collectionView的numberOfSection计算是根据self.timeScale的，而reloadData不是线性的调用，所以就会出现一种情况当计算numberOfSection 和 cellForItem 这两个delegate之间会改变timeScale，而造成数据不对，所以就记录每一次reloadData的timeScale
 */
@property (nonatomic, assign) double calcualteTimeScale;

@end

@implementation HQLVideoTimeLineManager {
    CGPoint _lastTouchPosition;
    
    dispatch_queue_t _updateScaleQueue;
    pthread_mutex_t _updateScaleWait;
    
    /**
     最小的timeScale
     */
    double _minTimeScale;
    
    /**
     标准的cellsize
     */
    double _cellSize;
}

#pragma mark - life cycle

- (instancetype)init {
    if (self = [super init]) {
        [self configManager];
    }
    return self;
}

- (void)dealloc {
    [self cleanMemory];
    NSLog(@"dealloc ---> %@", NSStringFromClass([self class]));
}

#pragma mark - config manager

- (void)configManager {
    self.videoItems = [NSMutableArray array];
    self.timeScale = 1.0; // 一个标准长度的cell表示一秒
    self.lastScale = 1.0;
    self.calcualteTimeScale = self.timeScale;
    
    // 不会改变的
    _cellSize = 100;
    _minTimeScale = 1.0; // 最小刻度为1秒
    
    /*
     创建线程
     */
    _updateScaleQueue = dispatch_queue_create("hql.videoTimeLineManager.updateTimeScaleQueue", DISPATCH_QUEUE_SERIAL);
    /*
     创建锁
     */
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
    pthread_mutex_init(&_updateScaleWait, &attr);
    pthread_mutexattr_destroy(&attr);
}

#pragma mark - Public

/**
 更新视频源 --- 会触发[self.videoItems removeAllObject]
 */
- (void)updateVideoItems:(NSArray <HQLVideoItem *>*)videoItems {
    [self.videoItems removeAllObjects];
    [self.videoItems addObjectsFromArray:videoItems];
    
    // 更新
    [self.timeLineView reloadData];
}

/**
 绑定collectionView
 */
- (void)bindWithCollectionView:(UICollectionView *)collectionView {
    
    if (_timeLineView) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Time line view already exist.");
        return;
    }
    
    if (!collectionView || ![collectionView isKindOfClass:[UICollectionView class]]) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Invalid collectionView.");
        return;
    }
    
    if (!collectionView.superview) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Invalid superView");
        return;
    }
    
    collectionView.delegate = self;
    collectionView.dataSource = self;
    
    [collectionView registerClass:[HQLThumbnailCell class] forCellWithReuseIdentifier:@"reuseId"];
//    [collectionView registerClass:[HQLVideoItemCell class] forCellWithReuseIdentifier:@"reuseId"];
    
    [collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"headerReuseId"];
    [collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"footerReuseId"];
    
    // 添加手势
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    [collectionView addGestureRecognizer:pinch];
    
    
    self.timeLineView = collectionView;
}

#pragma mark - event

/**
 根据indexPath计算每个cell显示的画面时间
 */
- (CMTime)calculateItemTimeWithIndexPath:(NSIndexPath *)indexPath timeScale:(double)scale {
    HQLVideoItem *item = self.videoItems[indexPath.section];
    
    // 计算真正的时间
    // 解决在计算的时候，self.timeScale可能会改变的情况
    CMTime timeScale = CMTimeMakeWithSeconds(scale, 600);
    CMTime time = CMTimeMultiply(timeScale, (int)indexPath.item);
    if (CMTimeCompare(time, item.timeRange.duration) >= 0) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Invalid time.");
        time = item.asset.duration; // 永远不会达到这个范围
    }
    CMTime start = item.timeRange.start;
    time = CMTimeAdd(start, time);
    return time;
}

/**
 长度转换为时间
 */
- (double)cellWidthChangeToTime:(double)cellWidth timeScale:(double)timeScale {
    double a = cellWidth / _cellSize;
    double targetTime = timeScale * a;
    return targetTime;
}

- (double)calculateTotalDuation {
    double target = 0.0;
    for (HQLVideoItem *videoItem in self.videoItems) {
        target += CMTimeGetSeconds(videoItem.timeRange.duration);
    }
    return target;
}

// 计算numberOfSection
- (NSInteger)calculateNumberOfSection:(NSUInteger)section timeScale:(double)timeScale {
    if (section < 0 || section >= self.videoItems.count) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Invalid section");
        return 0;
    }
    HQLVideoItem *videoItem = self.videoItems[section];
    
    // 根据时长来计算cell.count
    double duration = CMTimeGetSeconds(videoItem.timeRange.duration);
    NSInteger count = duration / timeScale;
    double remainder = duration - (count * timeScale);
    if (remainder > 0) {
        count += 1;
    }
    return count;
}

/**
 根据当前缩放scale来更新timeScale
 */
- (void)updateTimeScaleWithScale:(double)scale completion:(void(^)(void))completion {
    
    dispatch_async(_updateScaleQueue, ^{
       
        pthread_mutex_lock(&self->_updateScaleWait);
        
//        double targetScale = 1.0 / scale;
        // 计算
        double maxTime = 0;
        for (HQLVideoItem *videoItem in self.videoItems) {
            double duration = CMTimeGetSeconds(videoItem.timeRange.duration);
            if (duration > maxTime) {
                maxTime = duration;
            }
        }
        
        // 缩放 --- 缩放宽度，再根据宽度计算timeScale
        double aTargetWidth = scale * self.beforePinchWidth;
        
        double currentTime = [self calculateTotalDuation] / (aTargetWidth / self->_cellSize);
        
//        double currentTime = self.timeScale;
//        double addTime = 4;
//        addTime *= targetScale;
//        currentTime = currentTime + (addTime * (targetScale < 1 ? (-1) : (1)));
        if (currentTime <= self->_minTimeScale) {
            currentTime = self->_minTimeScale;
        }
        if (currentTime >= maxTime) {
            currentTime = maxTime;
        }
        
        if (currentTime == self.timeScale) {
            pthread_mutex_unlock(&self->_updateScaleWait);
            return;
        }
        
//        NSLog(@"current time : %f", currentTime);
        
        self.timeScale = currentTime;
        
        dispatch_async(dispatch_get_main_queue(), ^{
           
            completion ? completion() : nil;
            
        });
        
        pthread_mutex_unlock(&self->_updateScaleWait);
        
    });
}

- (void)cleanMemory {
    _updateScaleQueue = NULL;
    
}

- (double)calculateWidthWithDuartion:(double)duration timeScale:(double)timeScale {
    double target = duration / timeScale * _cellSize;
    return target;
}

#pragma mark - gesture handle

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)pinch {

    UIView *superView = self.timeLineView.superview;
    if (!superView) {
        NSAssert(NO, @"%s %d", __func__, __LINE__);
        return;
    }
    
    switch (pinch.state) {
        case UIGestureRecognizerStateBegan: {
            
            self.isDurationPinch = YES;
            
            self.beforePinchWidth = [self calculateWidthWithDuartion:[self calculateTotalDuation] timeScale:self.calcualteTimeScale];
            
            self.lastScale = 1;
            _lastTouchPosition = [pinch locationInView:superView];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            
//            [self updateTimeScaleWithScale:pinch.scale completion:^{
//                self.calcualteTimeScale = self.timeScale;
//                [self.timeLineView reloadData];
//            }];
            
            CGPoint currentTouchLocation = [pinch locationInView:superView];

            double aDistance = currentTouchLocation.x - _lastTouchPosition.x;
//            NSLog(@"distance : %f", aDistance);
//
//            NSLog(@"scale : %f", pinch.scale);

            CGPoint deltaMove = CGPointMake(_lastTouchPosition.x - currentTouchLocation.x, _lastTouchPosition.y - currentTouchLocation.y);
            float distance = sqrt(deltaMove.x * deltaMove.x + deltaMove.y * deltaMove.y);
            if (distance == 0) {
                return;
            }
            float hScale = 1 - fabs(deltaMove.x) / distance * (1 - pinch.scale);

            BOOL bScale = (hScale > 1) && ((NSUInteger)(fabs(hScale) * 20) > ((NSUInteger)(fabs(_lastScale) * 20) + 1));
            BOOL mScale = (hScale < 1) && ((NSUInteger)(fabs(hScale) * 20) < ((NSUInteger)(fabs(_lastScale) * 20) - 1));

            if ((bScale||mScale)&&(hScale != 1.0)) {
                self.lastScale = hScale;

                // 更新
                [self updateTimeScaleWithScale:hScale completion:^{
                    self.calcualteTimeScale = self.timeScale;
                    [self.timeLineView reloadData];
                }];
            }
            _lastTouchPosition = currentTouchLocation;
            
            
            CGPoint firstPoint = [pinch locationOfTouch:0 inView:superView];
            CGPoint secondPoint = CGPointZero;
            if (pinch.numberOfTouches == 2) {
                secondPoint = [pinch locationOfTouch:1 inView:superView];
            }
            NSLog(@"pinch ------ firstPoint %@ secondPoint %@",NSStringFromCGPoint(firstPoint),NSStringFromCGPoint(secondPoint));
            
            break;
        }
        case UIGestureRecognizerStateEnded: {
            
            self.isDurationPinch = NO;
            
//            for (HQLThumbnailCell *cell in [self.timeLineView visibleCells]) {
//                [cell.imageGetter run];
//            }
            
            break;
        }
        default: { break; }
    }
    
}

#pragma mark - collectionView delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
//    return 1;
    return self.videoItems.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (section != 0) {
        return 0;
    }
    return [self calculateNumberOfSection:section timeScale:self.calcualteTimeScale];
//    return 1;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
//    HQLVideoItem *item = self.videoItems[indexPath.section];
//
//    double duration = CMTimeGetSeconds(item.timeRange.duration);
//    CGFloat width = duration / self.timeScale * _cellSize;
//    return CGSizeMake(width, _cellSize);
    
    // 计算每个cell的大小
    NSInteger sectionCount = [self calculateNumberOfSection:indexPath.section timeScale:self.calcualteTimeScale];
    if (indexPath.item != (sectionCount - 1)) {
        // 不是最后一个
        return CGSizeMake(_cellSize, _cellSize);
    }
    // 最后一个 --- 需要计算cell的宽度
    HQLVideoItem *item = self.videoItems[indexPath.section];
    // 这个时间是相对于asset的
    CMTime currentItemTime = [self calculateItemTimeWithIndexPath:indexPath timeScale:self.calcualteTimeScale];
    // 所以这里也得相对于asset的时间来计算
    CMTime currentItemDuration = CMTimeSubtract(CMTimeAdd(item.timeRange.start, item.timeRange.duration), currentItemTime);

    double duration = CMTimeGetSeconds(currentItemDuration);
    double width = duration / self.calcualteTimeScale * _cellSize;
    return CGSizeMake(width, _cellSize);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionReusableView *view = nil;
    
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        
        view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"headerReuseId" forIndexPath:indexPath];
        
    } else {
        
        view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footerReuseId" forIndexPath:indexPath];
        
    }
    
    return view;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeMake(10, _cellSize);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    return CGSizeMake(10, _cellSize);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    HQLVideoItem *item = self.videoItems[indexPath.section];

//    HQLVideoItemCell *_cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"reuseId" forIndexPath:indexPath];
//    [_cell setVideoItem:item];
//    [_cell refreshWithTimeScale:self.timeScale];
    
    // 计算真正的时间
    CMTime time = [self calculateItemTimeWithIndexPath:indexPath timeScale:self.calcualteTimeScale];

    // 获取图片
    HQLThumbnailModel *model = [[HQLThumbnailModel alloc] init];
    model.asset = item.asset;
    model.thumbnailTime = time;
    HQLThumbnailCell *_cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"reuseId" forIndexPath:indexPath];
    
    _cell.currentPath = indexPath.item;
    
    // 如果在缩放的时候刷新collectionView 那么就在主线程中获取图片
    [_cell.imageGetter generateThumbnailWithModel:model mainThread:self.isDurationPinch];

//    if (self.isDurationPinch) {
//        [_cell.imageGetter wait];
//    } else {
//        [_cell.imageGetter run];
//    }
    
    return _cell;
}

#pragma mark - setter

#pragma mark - getter

@end
