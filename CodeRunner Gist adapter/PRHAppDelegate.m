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
	NSString *URLString;
	if (URL) {
		URLString = [URL absoluteString];
	} else {
		URLString = [pasteboard stringForType:NSStringPboardType];
		if (!URLString) {
			NSDictionary *documentAttributes = nil;
			NSData *RTFData = [pasteboard dataForType:(__bridge NSString *)kUTTypeRTF];
			NSAttributedString *document = RTFData
				? [[NSAttributedString alloc] initWithRTF:RTFData documentAttributes:&documentAttributes]
				: nil;
			__block NSURL *foundURL;
			__block NSString *foundURLString;
			[document enumerateAttribute:NSLinkAttributeName
			                     inRange:(NSRange){ 0, [document length] }
				                 options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
						      usingBlock:^(id value, NSRange range, BOOL *stop) {
				if ([value isKindOfClass:[NSURL class]]) {
					foundURL = value;
					foundURLString = [foundURL absoluteString];
				} else if ([value isKindOfClass:[NSString class]]) {
					foundURLString = value;
					foundURL = [NSURL URLWithString:foundURLString];
				}
			}];
			URL = foundURL;
			URLString = foundURLString;
		}
	}

	if (URL) {
		if (![self isGistURLString:URLString]) {
			*errorString = NSLocalizedString(@"That URL doesn't refer to a GitHub Gist", @"Error for input that isn't a GitHub Gist URL");
			URL = nil;
		}
	} else {
		*errorString = NSLocalizedString(@"That isn't a URL", @"Error for input not describing a URL");
		URL = nil;
	}

	return URL;
}

- (BOOL) isGistURLString:(NSString *)URLString {
	return [URLString hasPrefix:@"http://gist.github.com/"] || [URLString hasPrefix:@"https://gist.github.com/"];
}

- (void) gistToCodeRunnerDidFinish:(PRHGistToCodeRunnerWindowController *)windowController {
	[windowController close];
	[servicesInProgress removeObjectIdenticalTo:windowController];
}

@end
