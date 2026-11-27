//
//  DOKRWTestReport.h
//  FFKRW
//
//  Everything a tester has to send back, in one text block: device, chosen
//  exploit, transport state and the tail of the log. Copied to the clipboard and
//  written to Documents so it can be shared without a Mac.
//

#import <Foundation/Foundation.h>

NSString *DOKRWTestReport(void);
NSURL *DOKRWTestReportSave(void);
