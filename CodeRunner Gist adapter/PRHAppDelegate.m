//
//  PRHAppDelegate.m
//  CodeRunner Gist adapter
//
//  Created by Peter Hosey on 2012-11-16.
//  Copyright (c) 2012 Peter Hosey. All rights reserved.
//

#import "PRHAppDelegate.h"

#import "PRHGistToCodeRunnerWindowController.h"

@interface PRHAppDelegate () <PRHGistToCodeRunnerWindowControllerDelegate>
@end

@implementation PRHAppDelegate
{
	NSMutableArray *servicesInProgress;
}

- (void) applicationWillFinishLaunching:(NSNotification *)notification {
	servicesInProgress = [[NSMutableArray alloc] init];

	[NSApp setServicesProvider:self];
}

- (void) sendGistURLToCodeRunner:(NSPasteboard *)pasteboard userData:(id)userData error:(out NSString **)errorString {
	NSURL *URL = [self URLFromPasteboard:pasteboard errorString:errorString];
	if (!URL) {
		return;
	}

	//Now we have the URL. Use it.
	PRHGistToCodeRunnerWindowController *wc = [[PRHGistToCodeRunnerWindowController alloc] init];
	wc.gistURL = URL;
	wc.delegate = self;
	[wc start];
	[servicesInProgress addObject:wc];
}

- (NSURL *) URLFromPasteboard:(NSPasteboard *)pasteboard errorString:(out NSString **)errorString {
	NSURL *URL = [NSURL URLFromPasteboard:pasteboard];
	if (!URL) {
		NSString *URLString = [pasteboard stringForType:NSStringPboardType];
		if (!URLString) {
			*errorString = NSLocalizedString(@"That isn't a URL", @"Error for input not describing a URL");
		} else {
			if ([URLString hasPrefix:@"http://gist.github.com/"] || [URLString hasPrefix:@"https://gist.github.com/"]) {
				URL = [NSURL URLWithString:URLString];
			} else {
				*errorString = NSLocalizedString(@"That URL doesn't refer to a GitHub Gist", @"Error for input that isn't a GitHub Gist URL");
			}
		}
	}
	return URL;
}

- (void) gistToCodeRunnerDidFinish:(PRHGistToCodeRunnerWindowController *)windowController {
	[windowController close];
	[servicesInProgress removeObjectIdenticalTo:windowController];
}

@end
