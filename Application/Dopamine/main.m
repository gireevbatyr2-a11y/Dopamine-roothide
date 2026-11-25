//
//  main.m
//  Dopamine
//
//  Created by Lars Fröder on 23.09.23.
//

#import <UIKit/UIKit.h>
#import "DOAppDelegate.h"
#import <libroothider/log.h>

#import "DOEnvironmentManager.h"
#import <libjailbreak/info.h>
#import <libjailbreak/jbclient_xpc.h>
#import <mach/mach.h>
#include <unistd.h>
#include <string.h>

extern kern_return_t task_for_pid(mach_port_t target_tport, int pid, mach_port_t *t);

int main(int argc, char * argv[]) {
    if (argc >= 2 && !strcmp(argv[1], "krw-perturb-helper")) {
        // The parent spawns us so that a task_for_pid lookup from a different
        // task bumps its extmod_statistics counters (self lookups do not).
        mach_port_t parentPort = MACH_PORT_NULL;
        if (task_for_pid(mach_task_self(), getppid(), &parentPort) == KERN_SUCCESS) {
            mach_port_deallocate(mach_task_self(), parentPort);
        }
        sleep(2);
        return 0;
    }

    if (argc >= 3) {
        if (!strcmp(argv[1], "trollstore")) {
            if (!strcmp(argv[2], "delete-bootstrap")) {
                [[DOEnvironmentManager sharedManager] deleteBootstrap];
            }
/*
            else if (!strcmp(argv[2], "hide-jailbreak")) {
                [[DOEnvironmentManager sharedManager] setJailbreakHidden:YES];
            }
*/
            return 0;
        }
    }
    
    if (argc >= 2) {
        // Legacy, called by Dopamine 1.x before initiating a jbupdate
        // As updating from 1.x to 2.x is unsupported, just initiate a device reboot
        if (!strcmp(argv[1], "prepare_jbupdate")) {
            [[DOEnvironmentManager sharedManager] reboot];
            return 0;
        }
    }
    
// Make Dopamine's <Documents> directory visible in the Files app.
NSString* documentsPath = [@(getenv("HOME")) stringByAppendingPathComponent:@"Documents"];
[@"" writeToFile:[documentsPath stringByAppendingPathComponent:@".keep"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
#ifdef ENABLE_LOGS
if(@available(iOS 17.0.1, *)) {
    JBLogSetLogDir([documentsPath stringByAppendingPathComponent:@"logs"].fileSystemRepresentation);
}
#endif
    
    if ([DOEnvironmentManager sharedManager].isJailbroken) {
        setenv("PATH", "/sbin:/bin:/usr/sbin:/usr/bin:/rootfs/sbin:/rootfs/bin:/rootfs/usr/sbin:/rootfs/usr/bin", 1);
        setenv("TERM", "xterm-256color", 1);
    }
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([DOAppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
