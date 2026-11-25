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
#import <pthread.h>
#import <sys/sysctl.h>
#import <libjailbreak/libjailbreak.h>

@interface DOMainViewController ()

@property DOJailbreakButton *jailbreakBtn;
@property NSArray<NSLayoutConstraint *> *jailbreakButtonConstraints;
@property DOActionMenuButton *updateButton;
@property(nonatomic) BOOL hideStatusBar;
@property(nonatomic) BOOL hideHomeIndicator;

@end

@implementation DOMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupStack];
}

-(void)setupStack
{
    UIStackView *stackView = [[UIStackView alloc] init];
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
    DOHeaderView *headerView = [[DOHeaderView alloc] initWithImage: [UIImage imageNamed:@"Dopamine"] subtitles: @[
        [DOGlobalAppearance mainSubtitleString:[[DOEnvironmentManager sharedManager] versionSupportString]],
        [DOGlobalAppearance secondarySubtitleString:DOLocalizedString(@"Credits_Made_By")],
    ]];
    
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
    [self.jailbreakBtn.button setTitle:[self kernelRWButtonTitle] forState:UIControlStateNormal];
}

- (void)startKernelRW
{
    DOJailbreaker *kernelRW = [DOJailbreaker sharedInstance];

    DOKRWLog(@"UI: kernel R/W requested");
    [[DOUIManager sharedInstance] startLogCapture];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if ([kernelRW contiguousMappingWorkaroundNeeded]) {

            cpu_subtype_t cpuFamily = 0;
            size_t cpuFamilySize = sizeof(cpuFamily);
            sysctlbyname("hw.cpufamily", &cpuFamily, &cpuFamilySize, NULL, 0);
            NSString *workaroundMessage = DOLocalizedString(@"Respring_Required_Message");
            if (cpuFamily == CPUFAMILY_ARM_TYPHOON) {
                workaroundMessage = [workaroundMessage stringByAppendingString:[NSString stringWithFormat:@"\n\n%@", DOLocalizedString(@"Respring_Required_Notice_A8")]];
            }

            UIAlertController *contiguousMappingWorkaroundAlertController = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Respring_Required") message:workaroundMessage preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Respring_Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                exit(0);
            }];

            UIAlertAction *workaroundAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Apply_Workaround") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [kernelRW applyContiguousMappingWorkaround];
            }];

            [contiguousMappingWorkaroundAlertController addAction:cancelAction];
            [contiguousMappingWorkaroundAlertController addAction:workaroundAction];
            contiguousMappingWorkaroundAlertController.preferredAction = workaroundAction;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:contiguousMappingWorkaroundAlertController animated:YES completion:nil];
            });
            return;
        }

        [self.jailbreakBtn lockMutex];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hideHomeIndicator = YES;
        });

        NSError *error = [kernelRW obtainKernelRW];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                DOKRWLog(@"UI: kernel R/W failed: %@", error.localizedDescription);
                [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:@"Kernel R/W failed: %@", error] debug:NO];
                [self.navigationController pushViewController:[[DOLogCrashViewController alloc] initWithTitle:[error localizedDescription]] animated:YES];
            }
            else {
                [[DOUIManager sharedInstance] completeJailbreak];
                DOKRWLog(@"UI: kernel R/W ready base=0x%llx slide=0x%llx",
                         (unsigned long long)kernelRW.kernelBase,
                         (unsigned long long)kernelRW.kernelSlide);
                NSString *message = [NSString stringWithFormat:@"Kernel R/W ready\n\nbase:  0x%016llx\nslide: 0x%016llx\nkcall: %@", kernelRW.kernelBase, kernelRW.kernelSlide, kernelRW.isKcallAvailable ? @"available" : @"unavailable"];
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
    if ([action.identifier isEqualToString:@"settings"] || [action.identifier isEqualToString:@"credits"]) return YES;
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
