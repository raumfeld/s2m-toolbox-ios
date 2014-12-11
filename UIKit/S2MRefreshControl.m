//
//  S2MRefreshControl.m
//  S2MToolbox
//
//  Created by François Benaiteau on 15/08/14.
//  Copyright (c) 2014 SinnerSchrader Mobile. All rights reserved.
//

#import "S2MRefreshControl.h"

#import "UIView+S2MAdditions.h"
#import "UIView+S2MAutolayout.h"

@interface S2MRefreshControl ()<UIScrollViewDelegate>
@property(nonatomic, strong)UIScrollView* scrollView;
@property(nonatomic, weak)id<UIScrollViewDelegate>originalScrollViewDelegate;
@property(nonatomic, assign)BOOL isRefreshing;

@property(nonatomic, assign)UIEdgeInsets scrollViewInitialInsets;
@property(nonatomic, strong, readwrite)UIImageView* loadingImage;
@property(nonatomic, strong, readwrite)UIActivityIndicatorView* indicatorView;

@end

@implementation S2MRefreshControl

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self) {
        self.refreshControlHeight = 40;
        self.startLoadingThreshold = self.refreshControlHeight + 25;
        if (!image) {
            self.indicatorView = [self s2m_addActivityIndicatorView];
        }else{
            self.loadingImage = [self s2m_addImage:image];
        }
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.frame = CGRectMake(0, 0, self.superview.bounds.size.width, self.refreshControlHeight);
    self.center = CGPointMake(self.superview.center.x, self.superview.bounds.origin.y - self.refreshControlHeight / 2);
}

- (void)didMoveToSuperview
{
    [self.loadingView s2m_addCenterInSuperViewConstraint];
    if ([self.superview isKindOfClass:[UIScrollView class]]) {
        self.scrollView = (UIScrollView*)self.superview;
    }
    [self layoutIfNeeded];
}

- (void)setScrollView:(UIScrollView *)scrollView
{
    if (_scrollView) {
        [_scrollView removeObserver:self forKeyPath:NSStringFromSelector(@selector(delegate))];
    }
    _scrollView = scrollView;
    if (scrollView.delegate) {
        self.originalScrollViewDelegate = scrollView.delegate;
    }
    scrollView.delegate = self;
    [_scrollView addObserver:self forKeyPath:NSStringFromSelector(@selector(delegate)) options:NSKeyValueObservingOptionNew context:NULL];
}

#pragma mark - Animation


- (UIView*)loadingView
{
    return self.indicatorView ? self.indicatorView : self.loadingImage;
}

- (void)startAnimating
{
    if (self.indicatorView) {
        [self.indicatorView startAnimating];
    }else{
        self.loadingImage.alpha = 1.0;
        [self.loadingImage s2m_removeRotationAnimation];
        [self.loadingImage s2m_rotateWithDuration:0.5 repeat:INFINITY];
    }
}

- (void)stopAnimating
{
    if (self.indicatorView) {
        [self.indicatorView stopAnimating];
    }else{
        self.loadingImage.alpha = 0.0;
        [self.loadingView s2m_removeRotationAnimation];
    }
}

- (void)beginRefreshing
{
    if (self.isRefreshing) {
        return;
    }

    self.scrollViewInitialInsets = self.scrollView.contentInset;
    self.isRefreshing = YES;

    self.scrollView.contentInset = UIEdgeInsetsMake(self.startLoadingThreshold, 0, 0, 0);
    self.scrollView.scrollEnabled = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendActionsForControlEvents:UIControlEventValueChanged];
        [self startAnimating];
        self.scrollView.scrollEnabled = YES;
    });
}

- (void)endRefreshing
{
    if (!self.isRefreshing) {
        [self stopAnimating];
        return;
    }

    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.loadingView.alpha = 0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:0.1 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            [self.scrollView setContentOffset:CGPointZero];
            self.scrollView.contentInset = self.scrollViewInitialInsets;
        } completion:^(BOOL finished2) {
            [self stopAnimating];
            self.isRefreshing = NO;
        }];
    }];
}

#pragma mark - ScrollView

- (void)containingScrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    // do nothing
}

- (void)containingScrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat offset = scrollView.contentOffset.y + scrollView.contentInset.top;
    if (offset <= 0.0 && !self.isRefreshing && !scrollView.isDecelerating) {
        CGFloat fractionDragged = -offset/self.startLoadingThreshold;
        self.loadingView.alpha = 1;
        self.loadingView.transform = CGAffineTransformMakeRotation(2*M_PI * MAX(0.0, fractionDragged));

        if (fractionDragged >= 1.0) {
            [self beginRefreshing];
        }
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqual:NSStringFromSelector(@selector(delegate))]) {
        id newDelegate = change[NSKeyValueChangeNewKey];
        self.originalScrollViewDelegate = newDelegate;
    }
}


#pragma mark - UIScrollViewDelegate
//// We forward delegate calls

- (BOOL)respondsToSelector:(SEL)aSelector
{
    return [super respondsToSelector:aSelector] || [self.originalScrollViewDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if([self.originalScrollViewDelegate respondsToSelector:aSelector]){
        return self.originalScrollViewDelegate;
    }
    return nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self containingScrollViewDidScroll:scrollView];
    if ([self.originalScrollViewDelegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [self.originalScrollViewDelegate scrollViewDidScroll:scrollView];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self containingScrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    if ([self.originalScrollViewDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {
        [self.originalScrollViewDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
}

@end
