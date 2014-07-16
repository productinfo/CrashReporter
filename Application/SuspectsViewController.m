/*

   SuspectsViewController.m ... Table of crash suspects
   Copyright (c) 2009  KennyTM~ <kennytm@gmail.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#import "SuspectsViewController.h"

#import <Foundation/Foundation.h>
#import <MessageUI/MessageUI.h>
#import <RegexKitLite/RegexKitLite.h>
#import <libsymbolicate/CRCrashReport.h>
#import "BlameController.h"
#import "CrashLog.h"
#import "CrashLogViewController.h"
#import "IncludeReporterLine.h"
#import "LinkReporterLine.h"
#import "Package.h"

@interface UIAlertView ()
- (void)setNumberOfRows:(int)rows;
@end

@interface SuspectsViewController () <MFMailComposeViewControllerDelegate, UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate>
@end

@implementation SuspectsViewController {
    CrashLog *crashLog_;
    NSString *dateString_;
    NSArray *suspects_;
    NSArray *lastSelectedLinkReporters_;
    Package *lastSelectedPackage_;
    NSString *lastSelectedPath_;
}

- (void)dealloc {
    [crashLog_ release];
    [dateString_ release];
    [suspects_ release];
    [lastSelectedLinkReporters_ release];
    [lastSelectedPackage_ release];
    [lastSelectedPath_ release];
    [super dealloc];
}

static UIButton *logButton() {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor colorWithRed:(36.0 / 255.0) green:(132.0 / 255.0) blue:(232.0 / 255.0) alpha:1.0];
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    CALayer *layer = button.layer;
    layer.borderColor = [[UIColor blackColor] CGColor];
    layer.borderWidth = 1.0;

    return button;
}

- (void)loadView {
    UIScreen *mainScreen = [UIScreen mainScreen];
    CGRect screenBounds = [mainScreen bounds];
    CGFloat scale = [mainScreen scale];
    CGFloat buttonViewHeight = 1.0 + 44.0 * 2.0 + 30.0;
    CGFloat tableViewHeight = (screenBounds.size.height - buttonViewHeight);

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, tableViewHeight)];
    tableView.allowsSelectionDuringEditing = YES;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.dataSource = self;
    tableView.delegate = self;

    UIView *buttonView = [[UIView alloc] initWithFrame:CGRectMake(0.0, tableViewHeight, screenBounds.size.width, buttonViewHeight)];
    buttonView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    buttonView.backgroundColor = [UIColor colorWithRed:(247.0 / 255.0) green:(247.0 / 255.0) blue:(247.0 / 255.0) alpha:1.0];

    UIView *borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, (1.0 / scale))];
    borderView.backgroundColor = [UIColor colorWithRed:(178.0 / 255.0) green:(178.0 / 255.0) blue:(178.0 / 255.0) alpha:1.0];
    [buttonView addSubview:borderView];
    [borderView release];

    UIButton *button;
    button = logButton();
    [button setFrame:CGRectMake(10.0, 10.0, screenBounds.size.width - 20.0, 44.0)];
    [button setTitle:@"View crash log" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(crashlogTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonView addSubview:button];

    button = logButton();
    [button setFrame:CGRectMake(10.0, 10.0 + 44.0 + 10.0, screenBounds.size.width - 20.0, 44.0)];
    [button setTitle:@"View syslog" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(syslogTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonView addSubview:button];

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = [UIColor whiteColor];
    [view addSubview:tableView];
    [view addSubview:buttonView];
    self.view = view;

    [view release];
    [tableView release];
    [buttonView release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Other

- (void)readSuspectsForCrashLog:(CrashLog *)crashLog {
    crashLog_ = [crashLog retain];

    // Retrieve suspects.
    CRCrashReport *report = [[CRCrashReport alloc] initWithFile:[crashLog_ filepath]];
    suspects_ = [[[report properties] objectForKey:@"blame"] retain];
    [report release];

    // Create date string for syslog output.
    // FIXME: Is it necessary to cache this?
    NSDate *date = [crashLog date];
    dateString_ = [[ReporterLine formatSyslogTime:date] retain];

    // Set title using date.
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"HH:mm:ss"];
    self.title = [formatter stringFromDate:date];
    [formatter release];
}

#pragma mark - Button Actions

- (void)presentViewerWithLine:(NSString *)line {
    CrashLogViewController *viewController = [CrashLogViewController new];
    viewController.reporter = (IncludeReporterLine *)[ReporterLine reporterWithLine:line];
    [self.navigationController pushViewController:viewController animated:YES];
    [viewController release];
}

- (void)crashlogTapped {
    NSString *line = [NSString stringWithFormat:@"include as \"Crash log\" file \"%@\"", [crashLog_ filepath]];
    [self presentViewerWithLine:line];
}

- (void)syslogTapped {
    NSString *line = [NSString stringWithFormat:@"include as syslog command grep -F \"%@\" /var/log/syslog", dateString_];
    [self presentViewerWithLine:line];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger count = [suspects_ count];
    if (count > 0) {
        return (section == 0) ? 1 : (count - 1);
    } else {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *key = (section == 0) ?  @"Primary suspect" : @"Other suspects";
    return [[NSBundle mainBundle] localizedStringForKey:key value:nil table:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"."];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"."] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSUInteger index = (indexPath.section == 0) ? 0 : (indexPath.row + 1);
    cell.textLabel.text = [[suspects_ objectAtIndex:index] lastPathComponent];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Get package for selected row.
    NSUInteger index = (indexPath.section == 0) ? 0 : (indexPath.row + 1);
    NSString *path = [suspects_ objectAtIndex:index];
    Package *package = [Package packageForFile:path];

    // Get links for package.
    NSArray *linkReporters = [LinkReporterLine linkReportersForPackage:package];

    // Determine and present choices.
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *cancelTitle = [mainBundle localizedStringForKey:@"Cancel" value:nil table:nil];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:package.name message:nil delegate:self
        cancelButtonTitle:cancelTitle otherButtonTitles:nil];
    for (LinkReporterLine *linkReporter in linkReporters) {
        [alert addButtonWithTitle:[linkReporter title]];
    }
    [alert setNumberOfRows:(1 + [linkReporters count])];
    [alert show];
    [alert release];

    lastSelectedLinkReporters_ = [linkReporters retain];
    lastSelectedPackage_ = [package retain];
    lastSelectedPath_ = [path retain];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        LinkReporterLine *linkReporter = [lastSelectedLinkReporters_ objectAtIndex:(buttonIndex - 1)];
        if (linkReporter.isSupport) {
            // Report issue.
            NSString *crashlogLine = [NSString stringWithFormat:@"include as \"Crash log\" file \"%@\"", [crashLog_ filepath]];
            NSString *syslogLine = [NSString stringWithFormat:@"include as syslog command grep -E \"^%@\" /var/log/syslog", dateString_];
            NSMutableArray *includeReporters = [[NSMutableArray alloc] initWithObjects:
                [IncludeReporterLine reporterWithLine:crashlogLine],
                [IncludeReporterLine reporterWithLine:syslogLine],
                [IncludeReporterLine reporterWithLine:@"include as \"Package List\" command dpkg -l"],
                nil];
            [includeReporters addObjectsFromArray:[IncludeReporterLine includeReportersForPackage:lastSelectedPackage_]];

            BlameController *viewController = [[BlameController alloc] initWithPackage:lastSelectedPackage_ suspect:lastSelectedPath_
                linkReporter:linkReporter includeReporters:includeReporters];
            viewController.title = [lastSelectedPath_ lastPathComponent];
            [self.navigationController pushViewController:viewController animated:YES];
            [viewController release];
            [includeReporters release];
        } else {
            if (linkReporter.isEmail) {
                // Present mail controller.
                if ([MFMailComposeViewController canSendMail]) {
                    MFMailComposeViewController *controller = [MFMailComposeViewController new];
                    [controller setMailComposeDelegate:self];
                    [controller setToRecipients:[[linkReporter recipients] componentsSeparatedByRegex:@",\\s*"]];
                    [self presentModalViewController:controller animated:YES];
                    [controller release];
                } else {
                    NSBundle *mainBundle = [NSBundle mainBundle];
                    NSString *okMessage = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];
                    NSString *cannotMailMessage = [mainBundle localizedStringForKey:@"CANNOT_EMAIL" value:@"Cannot send email from this device." table:nil];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:cannotMailMessage message:nil delegate:nil cancelButtonTitle:okMessage otherButtonTitles:nil];
                    [alert show];
                    [alert release];
                }
            } else {
                // Open associated link.
                [[UIApplication sharedApplication] openURL:[linkReporter url]];
            }
        }
    }

    [lastSelectedLinkReporters_ release];
    lastSelectedLinkReporters_ = nil;
    [lastSelectedPackage_ release];
    lastSelectedPackage_ = nil;
    [lastSelectedPath_ release];
    lastSelectedPath_ = nil;
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self dismissModalViewControllerAnimated:YES];

    if (result == MFMailComposeResultFailed) {
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *message = [[mainBundle localizedStringForKey:@"EMAIL_FAILED_1" value:@"Failed to send email.\nError: " table:nil]
            stringByAppendingString:[error localizedDescription]];
        NSString *okMessage = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil
            cancelButtonTitle:okMessage otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

@end
