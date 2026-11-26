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
#import <stdio.h>
#import <string.h>
#import <mach/mach.h>
#import <libjailbreak/libjailbreak.h>

extern int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize);
extern int proc_name(int pid, void *buffer, uint32_t buffersize);

#ifndef PROC_ALL_PIDS
#define PROC_ALL_PIDS 1
#endif

@interface DOProcessListViewController : UITableViewController
@end

@interface DOMainViewController ()

@property DOJailbreakButton *jailbreakBtn;
@property NSArray<NSLayoutConstraint *> *jailbreakButtonConstraints;
@property DOActionMenuButton *updateButton;
@property DOActionMenuView *actionView;
@property DOHeaderView *headerView;
@property(nonatomic) BOOL hideStatusBar;
@property(nonatomic) BOOL hideHomeIndicator;

- (void)finishKernelRWUI:(BOOL)success;

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
        [UIAction actionWithTitle:@"Processes" image:[UIImage systemImageNamed:@"list.bullet" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"processes" handler:^(__kindof UIAction * _Nonnull action) {
            [self.navigationController pushViewController:[[DOProcessListViewController alloc] init] animated:YES];
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
    } else {
        BOOL ran = [[DOJailbreaker sharedInstance] exploitRanThisBoot];
        BOOL started = [[DOJailbreaker sharedInstance] exploitStartedThisBoot];
        if (started || ran) {
            DOKRWLog(@"UI: kernel R/W already acquired this boot; reboot required");
            self.jailbreakBtn.hidden = YES;
        } else {
            self.jailbreakBtn.hidden = NO;
        }
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
    if ([action.identifier isEqualToString:@"settings"] || [action.identifier isEqualToString:@"credits"] || [action.identifier isEqualToString:@"processes"]) return YES;
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

#pragma mark - Process list

@interface DOProcessListViewController ()
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, id> *> *processes;
@property (nonatomic, assign) pid_t connectedPid;
- (void)reloadProcesses;
- (void)connectToPid:(pid_t)pid name:(NSString *)name;
@end

@implementation DOProcessListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Processes";
    self.tableView.rowHeight = 44.0;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadProcesses)];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(reloadProcesses) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;

    [self reloadProcesses];
}

- (void)reloadProcesses
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int size = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
        NSMutableArray<NSDictionary<NSString *, id> *> *list = [NSMutableArray array];
        if (size > 0) {
            NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)size];
            int used = proc_listpids(PROC_ALL_PIDS, 0, data.mutableBytes, size);
            int count = used / (int)sizeof(pid_t);
            pid_t *pids = (pid_t *)data.mutableBytes;
            for (int i = 0; i < count; i++) {
                pid_t pid = pids[i];
                if (pid <= 0) continue;
                char name[256] = {0};
                if (proc_name(pid, name, sizeof(name)) <= 0) {
                    snprintf(name, sizeof(name), "pid %d", pid);
                }
                [list addObject:@{@"pid": @(pid), @"name": [NSString stringWithUTF8String:name] ?: @"?"}];
            }
        }
        [list sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"pid"] compare:b[@"pid"]];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.processes = list;
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
        });
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.processes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"DOProcessCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    }
    NSDictionary *proc = self.processes[(NSUInteger)indexPath.row];
    cell.textLabel.text = proc[@"name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"pid %@", proc[@"pid"]];
    cell.accessoryType = ([proc[@"pid"] intValue] == self.connectedPid) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *proc = self.processes[(NSUInteger)indexPath.row];
    [self connectToPid:[proc[@"pid"] intValue] name:proc[@"name"]];
}

- (void)connectToPid:(pid_t)pid name:(NSString *)name
{
    DOJailbreaker *krw = [DOJailbreaker sharedInstance];
    if (!krw.kernelRWReady) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Kernel R/W required" message:@"Get kernel R/W first, then connect to a process." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    DOKRWLog(@"process: connecting to %d (%@) via kernel task", pid, name);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL zeroed = [krw zeroExtmodStatisticsForPid:pid];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!zeroed) {
                DOKRWLog(@"process: extmod zero failed for %d (%@)", pid, name);
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Connection failed" message:[NSString stringWithFormat:@"Could not zero extmod for pid %d (%@).", pid, name] preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                return;
            }

            self.connectedPid = pid;
            [self.tableView reloadData];

            DOKRWLog(@"process: connected to %d (%@), extmod zeroed=yes (kernel task)", pid, name);
            NSString *message = [NSString stringWithFormat:@"Connected to %@ (pid %d).\nextmod counters zeroed: yes", name, pid];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Connected" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
