//
//  HQLVideoTimeLineManager.m
//  HQLVideoTimeLineDemo
//
//  Created by 何启亮 on 2018/7/26.
//  Copyright © 2018年 hql_personal_team. All rights reserved.
//

#import "HQLVideoTimeLineManager.h"

#import "HQLVideoItem.h"

#import "HQLThumbnailModel.h"
#import "HQLThumbnailCell.h"
#import "HQLThumbnailCellImageGetter.h"

#import "HQLTimeLineLayout.h"

#import <pthread.h>
#import <AVFoundation/AVFoundation.h>

@interface HQLVideoTimeLineManager () <UICollectionViewDelegate, UICollectionViewDataSource,HQLTimeLineLayoutDelegate>

@property (nonatomic, strong) NSMutableArray <HQLVideoItem *>*videoItems;

/**
 表示一个标准cell显示的时间
 */
@property (nonatomic, strong) HQLTimeAndLengthRatio *timeLengthRatio;

/**
 当前计算的timeScale
 目前缩放的时候，collectionView的numberOfSection计算是根据self.timeScale的，而reloadData不是线性的调用，所以就会出现一种情况当计算numberOfSection 和 cellForItem 这两个delegate之间会改变timeScale，而造成数据不对，所以就记录每一次reloadData的timeScale
 */
@property (nonatomic, strong) HQLTimeAndLengthRatio *calculateTimeLengthRatio;

/**
 视频长度 --- 只有在updateVideoItems的时候才会更新
 */
@property (nonatomic, assign) CMTime totalDuration;

@property (nonatomic, assign) double lastScale;

/**
 时间线
 */
@property (nonatomic, strong) HQLTimeLineView *timeLineView;

@property (nonatomic, assign) BOOL isDurationPinch;

/**
 记录缩放前的宽度
 */
@property (nonatomic, assign) double beforePinchWidth;

/**
 记录当前正在显示的videoItem
 */
@property (nonatomic, strong) HQLVideoItem *currentVideoItem;

/**
 记录timeLineViewcontentSize开始的X
 */
@property (nonatomic, assign) CGFloat timeLineViewBeginOffsetX;

/**
 当前时间
 */
@property (nonatomic, assign) CMTime currentTime;

@end

@implementation HQLVideoTimeLineManager {
    
    dispatch_queue_t _updateScaleQueue;
    pthread_mutex_t _updateScaleWait;
    
    /**
     最小的timeScale
     */
    CMTime _minTimeRatio;
    
    /**
     标准的cellsize
     */
    double _cellSize;
    
    CGFloat _lastContentOffsetX;
    CMTime _lastSeekTime;
    
    BOOL _canRemove;
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
    
    _canRemove = YES;
    
    // 不会改变的
    _cellSize = 100;
    _minTimeRatio = CMTimeMakeWithSeconds(1.0, 600); // 最小刻度为1秒
    
    self.timeLengthRatio = [[HQLTimeAndLengthRatio alloc] initWithTimeDuration:_minTimeRatio lengthPerTimeDuration:_cellSize];
    self.calculateTimeLengthRatio = [[HQLTimeAndLengthRatio alloc] initWithTimeDuration:_minTimeRatio lengthPerTimeDuration:_cellSize];
    
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
 绑定collectionView
 */
- (void)bindWithCollectionView:(HQLTimeLineView *)collectionView {
    
    if (![collectionView isKindOfClass:[HQLTimeLineView class]]) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Unsupport timeline view");
        return;
    }
    
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
    
    HQLTimeLineLayout *layout = (HQLTimeLineLayout *)collectionView.collectionViewLayout;
    
    if (![layout isKindOfClass:[HQLTimeLineLayout class]]) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, layout);
        return;
    }
    
    // layout.delegate 指向self
    layout.delegate = self;
    collectionView.delegate = self;
    collectionView.dataSource = self;
    
    [collectionView registerClass:[HQLThumbnailCell class] forCellWithReuseIdentifier:@"reuseId"];
    
    [collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"headerReuseId"];
    [collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"footerReuseId"];
    
    // 添加手势
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    [collectionView addGestureRecognizer:pinch];
    
    
    self.timeLineView = collectionView;
}

#pragma mark - DataSource operation method

/**
 更新视频源 --- 会触发[self.videoItems removeAllObject]
 */
- (void)updateVideoItems:(NSArray <HQLVideoItem *>*)videoItems {
    [self.videoItems removeAllObjects];
    [self.videoItems addObjectsFromArray:videoItems];
    
    ///!!!:更新数据源之后，必须要更新self.totalDuration，在这期间会更新videoItem.startTimeInTimeLine
    self.totalDuration = [self calculateTotalDuation];
    
    // 更新
    [self.timeLineView reloadData];
}

- (void)insertVideoItemsAfterCurrentVideoItem:(NSArray<HQLVideoItem *> *)videoItems {
    
    NSUInteger index = [self.videoItems indexOfObject:self.currentVideoItem];
    [self insertVideoItems:videoItems index:(index + 1)];
}

- (void)insertVideoItems:(NSArray<HQLVideoItem *> *)videoItems index:(NSUInteger)index {
    if (index >= self.videoItems.count) { // 大于数组的个数
        NSInteger origin = self.videoItems.count;
        CMTime originDuration = self.totalDuration;
        // 更新startInTimeLine
        [self.videoItems addObjectsFromArray:videoItems];
        ///!!!:更新数据源之后，必须要更新self.totalDuration，在这期间会更新videoItem.startTimeInTimeLine
        self.totalDuration = [self calculateTotalDuation];
        // collectionView 进行刷新
        ///!!!: 刷新前会先scroll到插入的位置
//        [self scrollToTime:originDuration animate:NO];
        @try {
            
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(origin, videoItems.count)];
            [self.timeLineView performBatchUpdates:^{
                [self.timeLineView insertSections:indexSet];
            } completion:^(BOOL finished) {
                // 更新
                [self updateCurrentTimeAndCurrentItem];
            }];
            
        } @catch (NSException *exception) {
            NSAssert(NO, @"%s %d %@", __func__, __LINE__, exception);
        }
        
        return;
    }
    
    NSInteger lastIndex = index == 0 ? 0 : (index - 1);
    HQLVideoItem *lastItem = self.videoItems[lastIndex];
    CMTime scrollTime = CMTimeAdd(lastItem.startTimeInTimeLine, lastItem.timeRange.duration);
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index, videoItems.count)];
    [self.videoItems insertObjects:videoItems atIndexes:indexSet];
    ///!!!: 更新数据源之后，必须要更新self.totalDuration，在这期间会更新videoItem.startTimeInTimeLine
    self.totalDuration = [self calculateTotalDuation];
    ///!!!: 刷新前会先scroll到插入的位置
//    [self scrollToTime:scrollTime animate:NO];
    
    @try {
        
        // 在调用前调用 会触发重新布局

        [self.timeLineView performBatchUpdates:^{
            [self.timeLineView insertSections:indexSet];
        } completion:^(BOOL finished) {
            // 更新
            [self updateCurrentTimeAndCurrentItem];
        }];
        
    } @catch (NSException *exception) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, exception);
    }
}

- (void)removeVideoItemAtIndex:(NSUInteger)index {
    if (self.videoItems.count == 0) {
        return;
    }
    
    if (!_canRemove) {
        return;
    }
    _canRemove = NO;
    
    if (index >= self.videoItems.count) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Invalid index");
        _canRemove = YES;
        return;
    }
    // 刷新
    @try {
#warning 这里使用[collectionView deleteSections:]方法,需要在调用之后才改变数据源
        // 在调用前调用 会触发重新布局
        [self.timeLineView performBatchUpdates:^{
            
            [self.timeLineView deleteSections:[NSIndexSet indexSetWithIndex:index]];
            
            [self.videoItems removeObjectAtIndex:index];
            ///!!!: 更新数据源之后，必须要更新self.totalDuration，在这期间会更新videoItem.startTimeInTimeLine
            self.totalDuration = [self calculateTotalDuation];
            
        } completion:^(BOOL finished) {
            // 更新
            [self updateCurrentTimeAndCurrentItem];
            self->_canRemove = YES;
        }];
        
    } @catch (NSException *exception) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, exception);
    }
    
}

- (void)removeCurrentVideoItem {
    NSUInteger index = [self.videoItems indexOfObject:self.currentVideoItem];
    [self removeVideoItemAtIndex:index];
}

- (HQLVideoItem *)getCurrentVideoItem {
    // 根据offset来算出当前时间
    
    if (self.videoItems.count == 0) {
        self.currentVideoItem = nil;
        return nil;
    }
    
    CMTime currentTime = self.currentTime;
    
    NSInteger index = 0;
    BOOL isReverseOrder = NO;
    
    if (self.currentVideoItem) {
        
        CMTimeRange timeRange =CMTimeRangeMake(self.currentVideoItem.startTimeInTimeLine, self.currentVideoItem.timeRange.duration);
        
        // 刚好位于边界的话，会默认为不包含
        if (CMTimeRangeContainsTime(timeRange, currentTime) ||
            (CMTimeCompare(timeRange.start, currentTime) == 0) ||
            (CMTimeCompare(CMTimeAdd(timeRange.start, timeRange.duration), currentTime) == 0)) {
            return self.currentVideoItem;
        }
        
        // 可以根据currentItem来计算出方向
        index = [self.videoItems indexOfObject:self.currentVideoItem];
        // 表明currentTime小于currentItem 应倒序地查找
        isReverseOrder = CMTimeCompare(self.currentVideoItem.startTimeInTimeLine, currentTime) >= 0 ? YES : NO;
        index += isReverseOrder ? (-1) : 1;
    }
    
    if (index <= 0) {
        index = 0;
    }
    if (index >= self.videoItems.count) {
        index = self.videoItems.count - 1;
    }
    
    for (NSInteger i = index; (isReverseOrder ? i >= 0 : i < self.videoItems.count); (isReverseOrder ? i-- : i ++)) {
        HQLVideoItem *item = self.videoItems[i];
        if (item == self.currentVideoItem) {
            continue;
        }
        CMTimeRange timeRange =CMTimeRangeMake(item.startTimeInTimeLine, item.timeRange.duration);
        // 刚好位于边界的话，会默认为不包含
        if (CMTimeRangeContainsTime(timeRange, currentTime) ||
            (CMTimeCompare(timeRange.start, currentTime) == 0) ||
            (CMTimeCompare(CMTimeAdd(timeRange.start, timeRange.duration), currentTime) == 0)) {
            // 在范围之内
            self.currentVideoItem = item;
            return item;
        }
    }
    
    NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Can not find current item");
    
    return nil;
}

#pragma mark - event

/**
 根据当前缩放scale来更新timeScale
 */
- (void)updateTimeAndLengthRatioWithScale:(double)scale completion:(void(^)(void))completion {
    
    dispatch_async(_updateScaleQueue, ^{
       
        pthread_mutex_lock(&self->_updateScaleWait);
        
        // 计算
        CMTime maxTime = kCMTimeZero;
        for (HQLVideoItem *videoItem in self.videoItems) {
            CMTime duration = videoItem.timeRange.duration;
            if (CMTimeCompare(duration, maxTime) >= 0) {
                maxTime = duration;
            }
        }
        
        // 缩放 --- 缩放宽度，再根据宽度计算timeScale
        double aTargetWidth = scale * self.beforePinchWidth;
        // 总时长
        double totalDuration = CMTimeGetSeconds(self.totalDuration);
        // 根据 “总时长” 和 “单位长度” 计算出来的 “单位长度时间”
        double currentTimeRatio = totalDuration / (aTargetWidth / self.timeLengthRatio.lengthPerTimeDuration);
        
        // 目标"单位时间长度"
        CMTime targetRatio = CMTimeMakeWithSeconds(currentTimeRatio, 600);
        
        // 最小
        CMTime min = self->_minTimeRatio;
        // 判断范围
        if (CMTimeCompare(targetRatio, min) <= 0) {
            targetRatio = min;
        }
        if (CMTimeCompare(targetRatio, maxTime) >= 0) {
            targetRatio = maxTime;
        }
        
        // 一样的倍率
        if (CMTimeCompare(targetRatio, self.timeLengthRatio.timeDuration) == 0) {
            pthread_mutex_unlock(&self->_updateScaleWait);
            return;
        }
        
        [self.timeLengthRatio updateTimeDuration:targetRatio];
        
        dispatch_async(dispatch_get_main_queue(), ^{
           
            completion ? completion() : nil;
            
        });
        
        pthread_mutex_unlock(&self->_updateScaleWait);
        
    });
}

- (void)cleanMemory {
    _updateScaleQueue = NULL;
    
}

/**
 移动到相应的位置
 */
- (void)scrollToTime:(CMTime)time animate:(BOOL)animate {
    
    // 根据time计算出位置
    double length = [self calculateWidthWithDuartion:time timeLengthRatio:self.calculateTimeLengthRatio];
    // 要加上beginX
    double offset = self.timeLineViewBeginOffsetX + length;
    
    [self.timeLineView setContentOffset:CGPointMake(offset, 0) animated:animate];
}

#pragma mark - tool

/**
 根据indexPath计算每个cell显示的画面时间
 */
- (CMTimeRange)calculateItemTimeWithIndexPath:(NSIndexPath *)indexPath timeLengthRatio:(HQLTimeAndLengthRatio *)timeLengthRatio {
    
    HQLVideoItem *item = self.videoItems[indexPath.section];
    
    // 计算真正的时间
    // 解决在计算的时候，self.timeScale可能会改变的情况
    CMTime timeScale = timeLengthRatio.timeDuration;
    CMTime time = CMTimeMultiply(timeScale, (int)indexPath.item);
    if (CMTimeCompare(time, item.timeRange.duration) >= 0) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Invalid time.");
        time = item.asset.duration; // 永远不会达到这个范围
    }
    CMTime start = item.timeRange.start;
    time = CMTimeAdd(start, time);
    
    // 显示一个timeScale的时间
    CMTime aTime = CMTimeAdd(time, timeScale);
    CMTime bTime = CMTimeAdd(item.timeRange.start, item.timeRange.duration);
    if (CMTimeCompare(aTime, bTime) >= 0) {
        // 超出范围
        timeScale = CMTimeSubtract(bTime, time);
    }
    
    return CMTimeRangeMake(time, timeScale);
}

/**
 长度转换为时间
 */
- (CMTime)calculateTimeWithLength:(double)cellWidth timeLengthRatio:(HQLTimeAndLengthRatio *)timeLengthRatio {
    return ([timeLengthRatio calculateTimeWithLength:cellWidth]);
}

/**
 时间转换为长度
 */
- (double)calculateWidthWithDuartion:(CMTime)duration timeLengthRatio:(HQLTimeAndLengthRatio *)timeLengthRatio {
    return ([timeLengthRatio calculateLengthWithTime:duration]);
}

/**
 计算总时长
 */
- (CMTime)calculateTotalDuation {
    CMTime kCursor = kCMTimeZero;
    for (HQLVideoItem *videoItem in self.videoItems) {
        videoItem.startTimeInTimeLine = kCursor;
        kCursor = CMTimeAdd(kCursor, videoItem.timeRange.duration);
    }
    
    if (CMTimeCompare(self.totalDuration, kCursor) != 0) {
        if ([self checkDelegateMethod:@selector(timeLineManager:timeLineView:totalDuartionDidChange:)]) {
            [self.delegate timeLineManager:self timeLineView:self.timeLineView totalDuartionDidChange:kCursor];
        }
    }
    
    return kCursor;
}

/**
 计算numberOfItemInSection
 */
- (NSInteger)calculateNumberOfSection:(NSUInteger)section timeLengthRatio:(HQLTimeAndLengthRatio *)timeLengthRatio {
    if (section >= self.videoItems.count) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Invalid section");
        return 0;
    }
    HQLVideoItem *videoItem = self.videoItems[section];
    
    // 根据时长来计算cell.count
    double duration = CMTimeGetSeconds(videoItem.timeRange.duration);
    double timeScale = CMTimeGetSeconds(timeLengthRatio.timeDuration);
    NSInteger count = duration / timeScale;
    double remainder = duration - (count * timeScale);
    if (remainder > 0) {
        count += 1;
    }
    return count;
}

- (BOOL)checkDelegateMethod:(SEL)method {
    if (self.delegate && [self.delegate respondsToSelector:method]) {
        return YES;
    }
    
    NSAssert(NO, @"%s %d \n Delegate could not implement %@", __func__, __LINE__, NSStringFromSelector(method));
    
    return NO;
}

/**
 计算当前时间 --- 会赋值currentTime
 同时会触发回调
 同时会获取当前显示的Item
 */
- (CMTime)calculateCurrentTime {
    // 获取contentOffset
    CGPoint contentOffsetPoint = self.timeLineView.contentOffset;
    
    // 如果跟上次一样则不再计算
    if (_lastContentOffsetX == contentOffsetPoint.x) {
        return self.currentTime;
    }
    _lastContentOffsetX = contentOffsetPoint.x;
    
    // 要获取正在的offset需要减去beginX
    CGFloat targetOffsetX = contentOffsetPoint.x - self.timeLineViewBeginOffsetX;
    
    // 判断时间 --- 当offset超出范围时 已最大和最小范围表示
    if (targetOffsetX <= 0.0) {
        targetOffsetX = 0.0;
    }
    CGFloat max = self.timeLineView.contentSize.width;
    if (targetOffsetX >= max) {
        targetOffsetX = max;
    }
    
    // 根据targetOffsetX来计算时间
    CMTime time = [self calculateTimeWithLength:targetOffsetX timeLengthRatio:self.calculateTimeLengthRatio];
    
    self.currentTime = time;
    // 获取当前显示的Item
    [self getCurrentVideoItem];
    
    // 回调
    if ([self checkDelegateMethod:@selector(timeLineManager:timeLineView:didChangeOffset:targetOffset:time:)]) {
        [self.delegate timeLineManager:self timeLineView:self.timeLineView didChangeOffset:contentOffsetPoint.x targetOffset:targetOffsetX time:time];
    }
    
    return time;
}

/**
 刷新画面
 */
- (void)refreshAndSeekTimeWithSpeed:(CGFloat)speed {
    if ([self.timeLineView panGestureRecognizer].state == 0) {
        return;
    }
    
    // 如果和上次一样 那么不做回调
    if (CMTimeCompare(_lastSeekTime, self.currentTime) == 0) {
        return;
    }
    _lastSeekTime = self.currentTime;
    
    if ([self checkDelegateMethod:@selector(timeLineManager:timeLineView:shouldSeekTime:)]) {
        [self.delegate timeLineManager:self timeLineView:self.timeLineView shouldSeekTime:self.currentTime];
    }
}

/**
 更新当前时间和当前显示的Item
 */
- (void)updateCurrentTimeAndCurrentItem {
    // 更新
    self.currentVideoItem = nil;
    _lastContentOffsetX = self.timeLineViewBeginOffsetX - 1;
    [self calculateCurrentTime];
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
            
            self.beforePinchWidth = [self calculateWidthWithDuartion:self.totalDuration timeLengthRatio:self.calculateTimeLengthRatio];
        
            // 重置
            self.lastScale = -1;
            
            break;
        }
        case UIGestureRecognizerStateChanged: {
            
            // 将scale保留四位小数
            NSInteger aScale = pinch.scale * 10000.0;
            double bScale = aScale / 10000.0;
            
            if (self.lastScale == bScale) { // 减少reload的次数
                break;
            }
            self.lastScale = bScale;
            
            // 更新
            [self updateTimeAndLengthRatioWithScale:bScale completion:^{
                // 刷新
                [self.calculateTimeLengthRatio updateTimeDuration:self.timeLengthRatio.timeDuration];
                [self.timeLineView reloadData];
            }];
            
            break;
        }
        case UIGestureRecognizerStateEnded: {
            
            self.isDurationPinch = NO;
            
            // 重置
            self.lastScale = -1;
            
            break;
        }
        default: { break; }
    }
    
}

#pragma mark - scrollView delegate

/*
  在这个方法里面不应该做滚动必须要做的事情，因为在这个方法里面做的是刷新画面的动作，刷新频率比较低
 */

- (void)scrollViewDidScroll:(UIScrollView * _Nonnull)scrollView {
    
    if (scrollView != self.timeLineView) {
        return;
    }
    
    // 更新时间
    [self calculateCurrentTime];
    
    // 判断速度 --- 在滑动速度比较低的时候可以刷新画面
    CGPoint velocity = [[scrollView panGestureRecognizer] velocityInView:scrollView];
    CGFloat scrollSpeed = fabs(velocity.x);
    [self refreshAndSeekTimeWithSpeed:scrollSpeed];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    if (scrollView != self.timeLineView) {
        return;
    }
    
    CGFloat scrollSpeed = fabs(velocity.x);
    // 刷新画面滑动速度比较低的时候可以刷新画面
    [self refreshAndSeekTimeWithSpeed:scrollSpeed];
}

- (void) scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
}

#pragma mark - collectionView delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.videoItems.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger count = [self calculateNumberOfSection:section timeLengthRatio:self.calculateTimeLengthRatio];
    return count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    HQLVideoItem *item = self.videoItems[indexPath.section];
    
    // 计算真正的时间
    CMTimeRange timeRange = [self calculateItemTimeWithIndexPath:indexPath timeLengthRatio:self.calculateTimeLengthRatio];
    CMTime time = timeRange.start;

    // 获取图片
    HQLThumbnailModel *model = [[HQLThumbnailModel alloc] init];
    model.asset = item.asset;
    model.thumbnailTime = time;
    HQLThumbnailCell *_cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"reuseId" forIndexPath:indexPath];
    
    _cell.currentPath = indexPath.item;
    
    // 如果在缩放的时候刷新collectionView 那么就在主线程中获取图片
    [_cell.imageGetter generateThumbnailWithModel:model mainThread:self.isDurationPinch];
    
    NSInteger numberOfSection = self.videoItems.count;
    NSInteger itemCount = [self collectionView:collectionView numberOfItemsInSection:indexPath.section];
    
    double cellWidth = [self calculateWidthWithDuartion:timeRange.duration timeLengthRatio:self.calculateTimeLengthRatio];
    
    // 更新圆角
    [_cell updateRoundCornersWithIsSingleCell:(itemCount == 1) isLastCell:(indexPath.item == (itemCount - 1)) isFirstCell:(indexPath.item == 0) isFirstSection:(indexPath.section == 0) isLastSection:(indexPath.section == (numberOfSection - 1)) isSingleSection:(numberOfSection == 1) cellSize:CGSizeMake(cellWidth, _cellSize)];
    
    return _cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
   
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        UICollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"headerReuseId" forIndexPath:indexPath];
        [headerView setBackgroundColor:[UIColor redColor]];
        return headerView;
    }
    
    UICollectionReusableView *footerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footerReuseId" forIndexPath:indexPath];
    [footerView setHidden:YES];
    return footerView;
}

#pragma mark - HQLTimelineLayoutDelegate

- (CMTime)timeLineDurationWithCollectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout {
    return self.totalDuration;
}

- (HQLTimeAndLengthRatio *)timeLineTimeAndLengthRatioWithCollectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout {
    return self.calculateTimeLengthRatio;
}

- (NSUInteger)numberOfCoverSectionWithCollectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout {
    return 0;
}

- (double)itemHeightWithCollectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout {
    return _cellSize;
}

- (CMTimeRange)collectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout itemTimeRangeForIndexPath:(NSIndexPath *)indexPath {
    // 只是计算了videoItem的在该Asset上的timeRange
    CMTimeRange range = [self calculateItemTimeWithIndexPath:indexPath timeLengthRatio:self.calculateTimeLengthRatio];
    // 再计算该cell在时间线上的start
    HQLVideoItem *item = self.videoItems[indexPath.section];
    CMTime start = CMTimeMultiply(self.calculateTimeLengthRatio.timeDuration, (int)indexPath.item);
    if (CMTimeCompare(start, item.timeRange.duration) >= 0) {
        NSAssert(NO, @"%s %d %@", __func__, __LINE__, @"Invalid time.");
        start = item.asset.duration; // 永远不会达到这个范围
    }
    // 加上在时间线上的开始时间
    start = CMTimeAdd(item.startTimeInTimeLine, start);
    range.start = start;
    return range;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(HQLTimeLineLayout *)layout sizeForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return CGSizeZero;
    }
    
    return CGSizeMake(50, 30);
}

#pragma mark - setter

#pragma mark - getter

- (CGFloat)timeLineViewBeginOffsetX {
    return (-self.timeLineView.contentInset.left);
}

@end
