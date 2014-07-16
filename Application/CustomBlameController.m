/*

   CustomBlameConstroller.m ... Text editor for creating custom blame scripts.
   Copyright (C) 2009  KennyTM~ <kennytm@gmail.com>

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

#import "CustomBlameController.h"

#import "BlameController.h"
#import "IncludeReporterLine.h"
#import "LinkReporterLine.h"

@interface CustomBlameController () <UIAlertViewDelegate>
@end

@implementation CustomBlameController {
    UITextView *textView_;
}

- (void)loadView {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    textView.font = [UIFont fontWithName:@"Courier" size:[UIFont systemFontSize]];
    [textView becomeFirstResponder];
    textView_ = textView;

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    //view.backgroundColor = [UIColor whiteColor];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [view addSubview:textView];
    self.view = view;
    [view release];

    UIBarButtonItem* done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(submit)];
    self.navigationItem.rightBarButtonItem = done;
    [done release];

    NSBundle *mainBundle = [NSBundle mainBundle];
    self.title = [mainBundle localizedStringForKey:@"Script" value:nil table:nil];

    NSString *message = [mainBundle localizedStringForKey:@"CUSTOM_BLAME_WARNING"
        value:@"Warning: Entering invalid data may corrupt your system. Use this page only in guidance of the developer."
        table:nil];
    UIAlertView *confirmDialog = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self
        cancelButtonTitle:[mainBundle localizedStringForKey:@"Back" value:nil table:nil]
        otherButtonTitles:[mainBundle localizedStringForKey:@"Continue" value:nil table:nil], nil];
    [confirmDialog performSelector:@selector(show) withObject:nil afterDelay:0.1];
    // confirmDialog's +1 retain count is intentional.
}

- (void)dealloc {
    [textView_ release];
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        [self.navigationController popViewControllerAnimated:YES];
    }
    [alertView release];
}

- (void)submit {
    LinkReporterLine *linkReporter = nil;
    NSMutableArray *includeReporters = [NSMutableArray new];

    NSArray *lines = [textView_.text componentsSeparatedByString:@"\n"];
    Class $LinkReporterLine = [LinkReporterLine class];
    for (NSString *line in lines) {
        ReporterLine *reporter = [ReporterLine reporterWithLine:line];
        if (reporter != nil) {
            if ([reporter isKindOfClass:$LinkReporterLine]) {
                linkReporter = [LinkReporterLine reporterWithLine:line];
            } else {
                [includeReporters addObject:reporter];
            }
        }
    }

    BlameController *controller = [[BlameController alloc] initWithPackage:nil suspect:nil linkReporter:linkReporter includeReporters:includeReporters];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];

    [includeReporters release];
}

@end

