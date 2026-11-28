//
//  DOOffsetsViewController.m
//  Dopamine
//

#import "DOOffsetsViewController.h"
#import "DOEnvironmentManager.h"
#import "DOUIManager.h"
#import "DOJailbreaker.h"
#import <libjailbreak/libjailbreak.h>#import "../Jailbreak/DOFreeFireBridge.h"

@interface DOOffsetsViewController ()
{
    NSArray *_rows;
}
@end

@implementation DOOffsetsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = DOLocalizedString(@"Kernel Offsets");
    [self rebuildRows];
}

- (void)rebuildRows
{
    NSMutableArray<NSDictionary<NSString *, id> *> *rows = [NSMutableArray array];

    DOJailbreaker *kernelRW = [DOJailbreaker sharedInstance];
    [rows addObject:@{@"group": DOLocalizedString(@"State"),
                      @"name": DOLocalizedString(@"Kernel R/W"),
                      @"value": kernelRW.kernelRWReady ? DOLocalizedString(@"Ready") : DOLocalizedString(@"Not ready")}];
    [rows addObject:@{@"group": DOLocalizedString(@"State"),
                      @"name": DOLocalizedString(@"Mode"),
                      @"value": kernelRW.isKRWOnlyMode ? @"KRW-only (external)" : DOLocalizedString(@"Full")}];
    [rows addObject:@{@"group": DOLocalizedString(@"State"),
                      @"name": @"extmod",
                      @"value": [NSString stringWithFormat:@"0x%x", kernelRW.extmodOffset]}];

    DOFreeFireBridge *bridge = [DOFreeFireBridge sharedInstance];
    [rows addObject:@{@"group": DOLocalizedString(@"Functions"),
                      @"name": @"FreeFire",
                      @"value": bridge.attached ? DOLocalizedString(@"Attached") : DOLocalizedString(@"Not attached")}];
    [rows addObject:@{@"group": DOLocalizedString(@"Functions"),
                      @"name": @"pid",
                      @"value": bridge.attached ? [NSString stringWithFormat:@"%d", bridge.attachedPid] : @"-"}];
    [rows addObject:@{@"group": DOLocalizedString(@"Functions"),
                      @"name": @"UnityFramework",
                      @"value": bridge.unityBase ? [NSString stringWithFormat:@"0x%016llx", bridge.unityBase] : @"-"}];

    xpc_object_t info = jbinfo_get_serialized();
    if (info) {
        __block NSMutableArray<NSDictionary<NSString *, id> *> *offsets = [NSMutableArray array];
        xpc_dictionary_apply(info, ^bool(const char *key, xpc_object_t value) {
            if (xpc_get_type(value) == XPC_TYPE_UINT64) {
                uint64_t v = xpc_uint64_get_value(value);
                if (v) {
                    [offsets addObject:@{@"group": DOLocalizedString(@"System Info"),
                                         @"name": [NSString stringWithUTF8String:key],
                                         @"value": [NSString stringWithFormat:@"0x%016llx", v]}];
                }
            }
            return true;
        });
        [rows addObjectsFromArray:offsets];
    }

    _rows = rows;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) return DOLocalizedString(@"State");
    if (section == 1) return DOLocalizedString(@"Functions");
    return DOLocalizedString(@"System Info");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *group = nil;
    if (section == 0) group = DOLocalizedString(@"State");
    else if (section == 1) group = DOLocalizedString(@"Functions");
    else group = DOLocalizedString(@"System Info");
    NSUInteger n = 0;
    for (NSDictionary *row in _rows) {
        if ([row[@"group"] isEqualToString:group]) n++;
    }
    return n;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"DOOffsetsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
        cell.textLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
        cell.detailTextLabel.minimumScaleFactor = 0.6;
    }

    NSString *group = nil;
    if (indexPath.section == 0) group = DOLocalizedString(@"State");
    else if (indexPath.section == 1) group = DOLocalizedString(@"Functions");
    else group = DOLocalizedString(@"System Info");
    NSMutableArray *groupRows = [NSMutableArray array];
    for (NSDictionary *row in _rows) {
        if ([row[@"group"] isEqualToString:group]) [groupRows addObject:row];
    }
    NSDictionary *row = groupRows[indexPath.row];
    cell.textLabel.text = row[@"name"];
    cell.detailTextLabel.text = row[@"value"];
    return cell;
}

@end
