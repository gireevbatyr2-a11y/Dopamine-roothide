//
//  DOMainViewController.m
//  Dopamine
//
//  Created by tomt000 on 08/01/2024.
//

#import "DOMainViewController.h"
#import "DOUIManager.h"
#import "DOEnvironmentManager.h"
#import "DOJailbreaker.h"
#import "DOGlobalAppearance.h"
#import "DOActionMenuButton.h"
#import "DOUpdateViewController.h"
#import "DOLogCrashViewController.h"
#import "DOFreeFireBridge.h"
#import <pthread.h>
#import <sys/sysctl.h>
#import <stdio.h>
#import <string.h>
#import <mach/mach.h>
#import <libjailbreak/libjailbreak.h>

extern int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize);
extern int proc_name(int pid, void *buffer, uint32_t buffersize);

#ifndef PROC_ALL_PIDS
#define PROC_ALL_PIDS 1
#endif

@interface DOFreeFireSwitchRow : NSObject
+ (UIView *)rowWithOwner:(DOMainViewController *)owner;
+ (void)updateOwnerStatus:(DOMainViewController *)owner;
+ (void)restoreOwner:(DOMainViewController *)owner;
@end

@interface DOMainViewController ()

@property DOJailbreakButton *jailbreakBtn;
@property NSArray<NSLayoutConstraint *> *jailbreakButtonConstraints;
@property DOActionMenuButton *updateButton;
@property DOActionMenuView *actionView;
@property DOHeaderView *headerView;
@property UIStackView *stackView;
@property(nonatomic) BOOL hideStatusBar;
@property(nonatomic) BOOL hideHomeIndicator;

- (void)finishKernelRWUI:(BOOL)success;
- (void)installFreeFireSwitch;
- (void)freeFireStateChanged;
- (void)freeFireSwitchChanged:(UISwitch *)sender;

@end

@implementation DOMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupStack];
}

-(void)setupStack
{
    UIStackView *stackView = [[UIStackView alloc] init];
    self.stackView = stackView;
    [stackView setAxis:UILayoutConstraintAxisVertical];
    [stackView setAlignment:UIStackViewAlignmentTrailing];
    [stackView setDistribution:UIStackViewDistributionEqualSpacing];
    [stackView setTranslatesAutoresizingMaskIntoConstraints:NO];

    [self.view addSubview:stackView];


    int statusBarHeight = fmax(15, [[UIApplication sharedApplication] keyWindow].safeAreaInsets.top - 20);

    [NSLayoutConstraint activateConstraints:@[
        [stackView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:statusBarHeight],//-35
        [stackView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:[DOGlobalAppearance isHomeButtonDevice] ? 0.78 : 0.73]
    ]];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        NSLayoutConstraint *relativeWidthConstraint = [stackView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.8];
        relativeWidthConstraint.priority = UILayoutPriorityDefaultHigh;
        NSLayoutConstraint *maxWidthConstraint = [stackView.widthAnchor constraintLessThanOrEqualToConstant:UI_IPAD_MAX_WIDTH];
        maxWidthConstraint.priority = UILayoutPriorityRequired;

        [NSLayoutConstraint activateConstraints:@[
            relativeWidthConstraint,
            maxWidthConstraint,
            [stackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
        ]];
    }
    else
    {
        [NSLayoutConstraint activateConstraints:@[
            [stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:UI_PADDING],
            [stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-UI_PADDING],
        ]];
    }

    //Header
    DOHeaderView *headerView = [[DOHeaderView alloc] initWithImage: [DOHeaderView ffkrwLogo] subtitles: @[
        [DOGlobalAppearance mainSubtitleString:[[DOEnvironmentManager sharedManager] versionSupportString]],
        [DOGlobalAppearance secondarySubtitleString:DOLocalizedString(@"Credits_Made_By")],
    ]];
    
    self.headerView = headerView;
    [stackView addArrangedSubview:headerView];

    [NSLayoutConstraint activateConstraints:@[
        [headerView.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor constant:5],
        [headerView.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor]
    ]];
    
    //Action Menu
    DOActionMenuView *actionView = [[DOActionMenuView alloc] initWithActions:@[
        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Settings_Title") image:[UIImage systemImageNamed:@"gearshape" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"settings" handler:^(__kindof UIAction * _Nonnull action) {
            [self.navigationController pushViewController:[[DOSettingsController alloc] init] animated:YES];
        }],

        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Credits_Title") image:[UIImage systemImageNamed:@"info.circle" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"credits" handler:^(__kindof UIAction * _Nonnull action) {
            [self.navigationController pushViewController:[[DOCreditsViewController alloc] init] animated:YES];
        }]
    ] delegate:self];
    
    self.actionView = actionView;
    [stackView addArrangedSubview: actionView];

    [NSLayoutConstraint activateConstraints:@[
        [actionView.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor],
        [actionView.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor],
    ]];
    
    
    UIView *buttonPlaceHolder = [[UIView alloc] init];
    [buttonPlaceHolder setTranslatesAutoresizingMaskIntoConstraints:NO];
    [stackView addArrangedSubview:buttonPlaceHolder];
    [NSLayoutConstraint activateConstraints:@[
        [buttonPlaceHolder.heightAnchor constraintEqualToConstant:60]
    ]];
    
    //Kernel R/W Button
    BOOL isReady = [DOJailbreaker sharedInstance].kernelRWReady;
    BOOL isSupported = [[DOEnvironmentManager sharedManager] isSupported];

    NSString *jailbreakButtonTitle = [self kernelRWButtonTitle];
        
    UIImage *jailbreakButtonImage;
    if (isSupported)
        jailbreakButtonImage = [UIImage systemImageNamed:@"lock.open" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]];
    else
        jailbreakButtonImage = [UIImage systemImageNamed:@"lock.slash" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]];
    
    self.jailbreakBtn = [[DOJailbreakButton alloc] initWithAction: [UIAction actionWithTitle:jailbreakButtonTitle image:jailbreakButtonImage identifier:@"jailbreak" handler:^(__kindof UIAction * _Nonnull action) {


        [actionView hide];
        [self.jailbreakBtn expandButton: self.jailbreakButtonConstraints];

        self.updateButton.userInteractionEnabled = NO;
        [UIView animateWithDuration:0.75 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0  options: UIViewAnimationOptionCurveEaseInOut animations:^{
            [headerView setTransform:CGAffineTransformMakeTranslation(0, -25)];
            self.updateButton.alpha = 0;
        } completion:nil];
        
        [self startKernelRW];
        
    }]];
    self.jailbreakBtn.enabled = !isReady && isSupported;

    [self.view addSubview:self.jailbreakBtn];

    [NSLayoutConstraint activateConstraints:(self.jailbreakButtonConstraints = @[
        [self.jailbreakBtn.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor],
        [self.jailbreakBtn.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor],
        [self.jailbreakBtn.heightAnchor constraintEqualToAnchor:buttonPlaceHolder.heightAnchor],
        [self.jailbreakBtn.centerYAnchor constraintEqualToAnchor:buttonPlaceHolder.centerYAnchor]
    ])];

}

- (NSString *)kernelRWButtonTitle
{
    BOOL isReady = [DOJailbreaker sharedInstance].kernelRWReady;
    BOOL isSupported = [[DOEnvironmentManager sharedManager] isSupported];

    if (!isSupported) return DOLocalizedString(@"Unsupported");
    if (isReady) return @"Kernel R/W Ready";
    return @"Get Kernel R/W";
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([[DOJailbreaker sharedInstance] isJailbroken]) {
        DOKRWLog(@"UI: roothide jailbreak present");
        self.jailbreakBtn.hidden = YES;
        return;
    }
    [self.jailbreakBtn.button setTitle:[self kernelRWButtonTitle] forState:UIControlStateNormal];
    BOOL restored = [[DOJailbreaker sharedInstance] restoreKernelRWFromHelper];
    if (restored || [DOJailbreaker sharedInstance].kernelRWReady) {
        DOKRWLog(@"UI: kernel R/W present");
        self.jailbreakBtn.hidden = YES;
        [self installFreeFireSwitch];
        [DOFreeFireSwitchRow restoreOwner:self];
    } else {
        // A new process has no live primitives even if a previous run set the
        // boot flag; always allow a fresh attempt instead of blocking on reboot.
        self.jailbreakBtn.hidden = NO;
    }
}

- (void)startKernelRW
{
    DOJailbreaker *kernelRW = [DOJailbreaker sharedInstance];

    DOKRWLog(@"UI: kernel R/W requested");
    [[DOUIManager sharedInstance] startLogCapture];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self.jailbreakBtn lockMutex];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hideHomeIndicator = YES;
        });

        NSError *error = [kernelRW obtainKernelRW];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                DOKRWLog(@"UI: kernel R/W failed: %@", error.localizedDescription);
                [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:@"Kernel R/W failed: %@", error] debug:NO];
                [self finishKernelRWUI:NO];
                [self.navigationController pushViewController:[[DOLogCrashViewController alloc] initWithTitle:[error localizedDescription]] animated:YES];
            }
            else {
                [[DOUIManager sharedInstance] completeKernelRW];
                [self finishKernelRWUI:YES];
                DOKRWLog(@"UI: kernel R/W ready base=0x%llx slide=0x%llx",
                         (unsigned long long)kernelRW.kernelBase,
                         (unsigned long long)kernelRW.kernelSlide);
                NSString *message = [NSString stringWithFormat:@"Kernel R/W ready\n\nbase:  0x%016llx\nslide: 0x%016llx\nkcall: %@\nlog: %@", kernelRW.kernelBase, kernelRW.kernelSlide, kernelRW.isKcallAvailable ? @"available" : @"unavailable", DOKRWLogPath()];
                [[DOUIManager sharedInstance] sendLog:message debug:NO];
                [self.jailbreakBtn.button setTitle:@"Kernel R/W Ready" forState:UIControlStateNormal];
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Kernel R/W" message:message preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alertController animated:YES completion:nil];
            }
        });
        [self.jailbreakBtn unlockMutex];
    });
}


- (void)finishKernelRWUI:(BOOL)success
{
    [self.jailbreakBtn collapseButton];
    self.jailbreakBtn.hidden = success;
    [self.actionView show];
    self.updateButton.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.3 animations:^{
        self.updateButton.alpha = 1.0;
        [self.headerView setTransform:CGAffineTransformIdentity];
    }];
    self.hideHomeIndicator = NO;
    if (success && [DOJailbreaker sharedInstance].kernelRWReady) {
        [self installFreeFireSwitch];
        [DOFreeFireSwitchRow restoreOwner:self];
    }
    DOKRWLog(@"UI: finish success=%d jailbreakHidden=%d jailbreakFrame=%@ stackHidden=%d stackAlpha=%.2f menuAlpha=%.2f",
             success, self.jailbreakBtn.hidden, NSStringFromCGRect(self.jailbreakBtn.frame),
             self.headerView.superview.hidden, self.headerView.superview.alpha, self.actionView.alpha);
}

-(void)setupUpdateAvailable:(BOOL)environmentUpdate
{
    if (self.jailbreakBtn.didExpand)
        return;

    NSString *title = environmentUpdate ? DOLocalizedString(@"Button_Update_Environment") : DOLocalizedString(@"Button_Update_Available");
    
    NSString *releaseFrom = [[DOUIManager sharedInstance] getLaunchedReleaseTag];
    NSString *releaseTo = [[DOUIManager sharedInstance] getLatestReleaseTag];

    if (environmentUpdate)
    {
/************************************* roothide specfic ***********************************/
        releaseFrom = [[DOEnvironmentManager sharedManager] jailbrokenVersionRootHide];
/************************************* roothide specfic ***********************************/
        releaseTo = [[DOUIManager sharedInstance] getLaunchedReleaseTag];
    }

    self.updateButton = [DOActionMenuButton buttonWithAction:[UIAction actionWithTitle:title image:[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"update-available" handler:^(__kindof UIAction * _Nonnull action) {
        [self.navigationController pushViewController:[[DOUpdateViewController alloc] initFromTag:releaseFrom toTag:releaseTo] animated:YES];
    }] chevron:NO];

    self.updateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.updateButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.updateButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.updateButton.heightAnchor constraintEqualToConstant:30],
        [self.updateButton.bottomAnchor constraintEqualToAnchor:self.jailbreakBtn.topAnchor constant:[DOGlobalAppearance isHomeButtonDevice] ? -10 : -20]
    ]];

    [self.updateButton setTransform:CGAffineTransformMakeTranslation(0, 25)];
    [self.updateButton setAlpha:0];
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0  options: UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.updateButton setTransform:CGAffineTransformIdentity];
        [self.updateButton setAlpha:1];
    } completion:nil];
}

- (void)fadeToBlack:(void (^)(void))completion
{
    static bool didFade = false;
    if (didFade)
        return;
    didFade = true;
    UIView *mainView = self.parentViewController.view;
    float deviceCornerRadius = [[[UIScreen mainScreen] valueForKey:@"_displayCornerRadius"] floatValue];

    mainView.layer.cornerRadius = deviceCornerRadius;
    mainView.layer.cornerCurve = kCACornerCurveContinuous;
    mainView.layer.masksToBounds = YES;
    
    self.hideStatusBar = YES;

    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0 options: UIViewAnimationOptionCurveEaseInOut animations:^{
        mainView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        mainView.alpha = 0.0;
    } completion:^(BOOL success) {
        completion();
    }];
}

#pragma mark - Action Menu Delegate

- (BOOL)actionMenuShowsChevronForAction:(UIAction *)action
{

    return NO;
}

- (BOOL)actionMenuActionIsEnabled:(UIAction *)action
{
    return YES;
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return self.hideStatusBar;
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return self.hideHomeIndicator;
}

- (void)setHideStatusBar:(BOOL)hideStatusBar
{
    _hideStatusBar = hideStatusBar;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)setHideHomeIndicator:(BOOL)hideHomeIndicator
{
    _hideHomeIndicator = hideHomeIndicator;
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
}

@end

#pragma mark - FreeFire switch

#define DOFREEFIRE_ROW_TAG 0xD00F

@implementation DOMainViewController (FreeFireSwitch)

- (void)installFreeFireSwitch
{
    for (UIView *existing in self.stackView.arrangedSubviews) {
        if (existing.tag == DOFREEFIRE_ROW_TAG) return;
    }
    UIView *row = [DOFreeFireSwitchRow rowWithOwner:self];
    row.tag = DOFREEFIRE_ROW_TAG;
    [self.stackView addArrangedSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:self.stackView.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:self.stackView.trailingAnchor],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(freeFireStateChanged) name:DOFreeFireBridgeAttachDidChangeNotification object:nil];
}

- (void)freeFireStateChanged
{
    [DOFreeFireSwitchRow updateOwnerStatus:self];
}

- (void)freeFireSwitchChanged:(UISwitch *)sender
{
    BOOL on = sender.isOn;
    if (![DOJailbreaker sharedInstance].kernelRWReady) {
        sender.on = NO;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Kernel R/W required" message:@"Get kernel R/W first, then enable the FreeFire switch." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:@"DOKRWFreeFireAttach"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        if (on) {
            [[DOFreeFireBridge sharedInstance] attachWithError:&error];
            if (error) DOKRWLog(@"FreeFire: attach failed: %@", error.localizedDescription);
        } else {
            [[DOFreeFireBridge sharedInstance] detach];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [DOFreeFireSwitchRow updateOwnerStatus:self];
        });
    });
}

@end

@implementation DOFreeFireSwitchRow

+ (UISwitch *)switchIn:(UIView *)row
{
    for (UIView *sub in row.subviews) {
        if ([sub isKindOfClass:[UISwitch class]]) return (UISwitch *)sub;
    }
    return nil;
}

+ (UILabel *)detailIn:(UIView *)row
{
    for (UIView *sub in row.subviews) {
        if ([sub isKindOfClass:[UILabel class]] && sub.tag == 0xD00D) return (UILabel *)sub;
    }
    return nil;
}

+ (UIView *)rowWithOwner:(DOMainViewController *)owner
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [[UILabel alloc] init];
    title.text = @"FreeFire";
    title.font = [UIFont boldSystemFontOfSize:16];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:title];

    UILabel *detail = [[UILabel alloc] init];
    detail.tag = 0xD00D;
    detail.font = [UIFont systemFontOfSize:12];
    detail.textColor = [UIColor secondaryLabelColor];
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:detail];

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"DOKRWFreeFireAttach"];
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    [sw addTarget:owner action:@selector(freeFireSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];

    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:5],
        [title.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [detail.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:5],
        [detail.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [row.heightAnchor constraintEqualToConstant:48],
    ]];

    return row;
}

+ (void)updateOwnerStatus:(DOMainViewController *)owner
{
    DOJailbreaker *krw = [DOJailbreaker sharedInstance];
    DOFreeFireBridge *bridge = [DOFreeFireBridge sharedInstance];
    NSString *detailText = nil;
    if (!krw.kernelRWReady) {
        detailText = @"Get Kernel R/W first";
    } else if (bridge.attached) {
        detailText = [NSString stringWithFormat:@"pid %d · UnityFramework 0x%llx",
                      bridge.attachedPid, bridge.unityBase];
    } else {
        detailText = @"Not attached";
    }
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
        for (UIViewController *vc in scene.windows.firstObject.rootViewController.navigationController.viewControllers) {
            if (![vc isKindOfClass:[DOMainViewController class]]) continue;
            DOMainViewController *main = (DOMainViewController *)vc;
            for (UIView *row in main.stackView.arrangedSubviews) {
                if (row.tag != DOFREEFIRE_ROW_TAG) continue;
                for (UIView *sub in row.subviews) {
                    if ([sub isKindOfClass:[UISwitch class]]) {
                        UISwitch *sw = (UISwitch *)sub;
                        if (sw.isOn != bridge.attached) [sw setOn:bridge.attached animated:YES];
                    }
                    if ([sub isKindOfClass:[UILabel class]] && sub.tag == 0xD00D) {
                        ((UILabel *)sub).text = detailText;
                    }
                }
            }
        }
    }
}

+ (void)restoreOwner:(DOMainViewController *)owner
{
    BOOL want = [[NSUserDefaults standardUserDefaults] boolForKey:@"DOKRWFreeFireAttach"];
    if (want && [DOJailbreaker sharedInstance].kernelRWReady) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [[DOFreeFireBridge sharedInstance] attachWithError:nil];
        });
    }
}

@end
