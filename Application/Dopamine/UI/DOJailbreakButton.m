//
//  DOJailbreakButton.m
//  Dopamine
//
//  Created by tomt000 on 13/01/2024.
//

#import "DOJailbreakButton.h"
#import "DODoubleHelixIndicator.h"
#import "DOUIManager.h"
#import "DOGlobalAppearance.h"
#import "DOThemeManager.h"
#import "DOJailbreaker.h"

@interface DOJailbreakButton ()
@property NSArray<NSLayoutConstraint *> *expandedConstraints;
@property NSArray<NSLayoutConstraint *> *originalConstraints;
@property UILabel *titleLabel;
@property DODoubleHelixIndicator *indicator;
@end

@implementation DOJailbreakButton

- (instancetype)initWithAction:(UIAction *)actions
{
    if (self = [super init])
    {
        self.backgroundColor = [DOThemeManager menuColorWithAlpha:1.0];
        self.layer.cornerRadius = 14;
        self.layer.masksToBounds = YES;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        self.button = [DOActionMenuButton buttonWithAction:actions chevron:NO];
        [self.button setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
        self.button.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.button];
        [NSLayoutConstraint activateConstraints:@[
            [self.button.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.button.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.button.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.button.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (void)expandButton:(NSArray<NSLayoutConstraint *> *)constraints
{
    if (self.didExpand)
        return;

    //We're doing some setup, let's lock the mutex
    [self lockMutex];
        
    self.didExpand = TRUE;

    UIWindow *window = [[UIApplication sharedApplication] keyWindow];

    float topPadding = (window.frame.size.height * (1 - 0.74));
    topPadding += 35;
    
    [self setupLog: topPadding];
    
    self.originalConstraints = constraints;
    [NSLayoutConstraint deactivateConstraints:constraints];


    self.expandedConstraints = @[
        [self.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
        [self.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
        [self.topAnchor constraintEqualToAnchor:window.topAnchor constant:topPadding],
        [self.bottomAnchor constraintEqualToAnchor:window.bottomAnchor constant:100] // slightly out of the screen to hide corners on i8
    ];
    [NSLayoutConstraint activateConstraints:self.expandedConstraints];
    
    [self.button setUserInteractionEnabled:NO];

    [UIView animateWithDuration: 0.2 animations:^{ [self.button setAlpha:0.0]; }];
    [UIView animateWithDuration:0.75 delay:0.0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0  options: UIViewAnimationOptionCurveEaseInOut animations:^{
        [window layoutIfNeeded];
        [self.button setAlpha:0.0];
    } completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (self.didExpand) [self setupTitle];
    });

    // Kernel-R/W-only: no package manager picker, start immediately.
    [self unlockMutex];

}

- (void)setupLog: (float)topPadding
{
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];

    if ([[DOUIManager sharedInstance] isDebug])
        self.logView = [[DODebugLogView alloc] init];
    else
        self.logView = [[DOLyricsLogView alloc] init];
    
    [[DOUIManager sharedInstance] setLogView:self.logView];

    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.logView];

    [NSLayoutConstraint activateConstraints:@[
        [self.logView.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
        [self.logView.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
        [self.logView.topAnchor constraintEqualToAnchor:window.topAnchor constant:topPadding],
        [self.logView.bottomAnchor constraintEqualToAnchor:window.bottomAnchor constant:0]
    ]];

    [window layoutIfNeeded];
}

- (void)setupTitle
{
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"Kernel R/W";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightRegular];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.alpha = 0.0;
    [self addSubview:self.titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:window.centerXAnchor constant:20],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:20],
    ]];

    [UIView animateWithDuration:0.2 animations:^{
        self.titleLabel.alpha = 1.0;
    }];

    self.indicator = [[DODoubleHelixIndicator alloc] init];
    [self addSubview:self.indicator];
    self.indicator.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.indicator.trailingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor constant:-10],
        [self.indicator.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.indicator.widthAnchor constraintEqualToConstant:30],
        [self.indicator.heightAnchor constraintEqualToConstant:12],
    ]];
}

- (void)collapseButton
{
    if (!self.didExpand) return;
    self.didExpand = NO;

    [self.logView removeFromSuperview];
    self.logView = nil;
    [[DOUIManager sharedInstance] setLogView:nil];

    [self.titleLabel removeFromSuperview];
    self.titleLabel = nil;
    [self.indicator removeFromSuperview];
    self.indicator = nil;

    NSUInteger expandedCount = self.expandedConstraints.count;
    [NSLayoutConstraint deactivateConstraints:self.expandedConstraints];
    self.expandedConstraints = nil;
    if (self.originalConstraints) {
        [NSLayoutConstraint activateConstraints:self.originalConstraints];
    }

    DOKRWLog(@"UI: collapse frame=%@ expanded=%lu original=%lu",
             NSStringFromCGRect(self.frame),
             (unsigned long)expandedCount,
             (unsigned long)self.originalConstraints.count);

    [self.button setAlpha:1.0];
    [self.button setUserInteractionEnabled:YES];
    [UIView animateWithDuration:0.3 animations:^{
        [self.superview layoutIfNeeded];
    }];
}

- (void)setEnabled:(BOOL)enabled
{
    self.button.userInteractionEnabled = enabled;
    if (enabled) {
        self.alpha = 1.0;
    } else {
        self.alpha = 0.7;
    }
}

- (BOOL)isEnabled
{
    return self.button.userInteractionEnabled;
}

#pragma mark - Mutex

-(void)lockMutex
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pthread_mutex_init(&self->_canStartJailbreak, NULL);
    });
    pthread_mutex_lock(&self->_canStartJailbreak);
}

-(void)unlockMutex
{
    pthread_mutex_unlock(&self->_canStartJailbreak);
}

@end
