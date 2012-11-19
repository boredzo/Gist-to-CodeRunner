//
//  PRHGistToCodeRunnerWindowController.m
//  CodeRunner Gist adapter
//
//  Created by Peter Hosey on 2012-11-16.
//  Copyright (c) 2012 Peter Hosey. All rights reserved.
//

#import "PRHGistToCodeRunnerWindowController.h"

@interface PRHGistToCodeRunnerWindowController () <NSURLDownloadDelegate, NSWindowDelegate>

@property(weak) IBOutlet NSProgressIndicator *loadingProgressBar;

@property(strong) IBOutlet NSView *fileToOpenPickerView;
@property(weak) IBOutlet NSPopUpButton *fileToOpenPopUp;

@property(strong) NSURL *selectedMainFileURL;

- (IBAction)openSelectedMainFile:(id)sender;
- (IBAction)cancel:(id)sender;

@end

static NSString *const codeRunnerBundleIdentifier = @"com.krill.CodeRunner";

@implementation PRHGistToCodeRunnerWindowController
{
	NSString *gistName;
	NSMutableDictionary *downloadsByFilename;
	NSArray *allDownloadFilenames;
	NSArray *allFileURLs;
	NSArray *mainFileCandidates;
	NSTimer *showWindowTimer;
}

- (id) initWithWindow:(NSWindow *)window {
	self = [super initWithWindow:window];
	if (self) {
		downloadsByFilename = [NSMutableDictionary new];
	}

	return self;
}

- (id) init {
	return [self initWithWindowNibName:[self className]];
}


- (void) windowDidLoad {
	[super windowDidLoad];
}

- (void)updateWindowTitle {
    self.window.title = gistName ?: NSLocalizedString(@"Loading Gist…", @"Window title for loading window");
}

- (void) showWindow:(id)sender {
	[self updateWindowTitle];
	[super showWindow:sender];
}

- (void) start {
	NSParameterAssert(self.gistURL != nil);

	showWindowTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
	                                                   target:self
	                                                 selector:@selector(showWindowAfterTimer:)
			                                         userInfo:nil
			                                          repeats:NO];

	NSSet *setOfMainFileTypes = nil;
	NSArray *arrayOfMainFileTypes = [[NSUserDefaults standardUserDefaults]
		stringArrayForKey:@"Main file types"] ? : @[];
	setOfMainFileTypes = [NSSet setWithArray:[@[@"m", @"mm", @"M", @"c", @"cc", @"C", @"cpp", @"py", @"rb"] arrayByAddingObjectsFromArray:arrayOfMainFileTypes]];

	NSURL *URLToRequest = [self githubAPIGistURLWithWebGistURL:self.gistURL];
	NSURLRequest *request = [NSURLRequest requestWithURL:URLToRequest];
	[NSURLConnection sendAsynchronousRequest:request
	                                   queue:[NSOperationQueue mainQueue]
		                   completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {

		NSMutableArray *filenames;
		NSMutableArray *mainFileCandidatesToBe;
		NSMutableArray *allFileURLsToBe;

		if (data && !error) {
			NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
			                                                     options:(NSJSONReadingOptions)0
				                                                   error:&error];
			gistName = dict[@"description"];
			if (![self objectIsKindOfClass:[NSString class] andIsNonNilAndNonEmpty:gistName]) {
				error = [self invalidFormatError];
			}

			if ([self isWindowLoaded]) {
				[self updateWindowTitle];
			}

			NSString *gistFilename = [gistName stringByAppendingPathExtension:@"gist"];
			if (gistFilename.length > NAME_MAX) {
				NSUInteger lengthDiff = NAME_MAX - gistFilename.length;
				NSUInteger correctLength = gistFilename.length - lengthDiff;
				gistFilename = [[gistName substringToIndex:correctLength]
					stringByAppendingPathExtension:@"gist"];
			}

			//TODO: Should we run a save panel instead?
			NSFileManager *manager = [NSFileManager defaultManager];
			NSURL *cachesDirURL = [manager URLForDirectory:NSCachesDirectory
			                                      inDomain:NSUserDomainMask
					                     appropriateForURL:nil create:YES error:&error];
			NSString *mainBundleIdentifier = [[NSBundle mainBundle]
				bundleIdentifier];
			NSURL *appCachesDirURL = [cachesDirURL URLByAppendingPathComponent:mainBundleIdentifier
			                                                       isDirectory:YES];
			NSURL *gistDirectoryURL = [appCachesDirURL URLByAppendingPathComponent:gistFilename
			                                                           isDirectory:YES];
			[manager createDirectoryAtURL:gistDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];

			allFileURLsToBe = [@[] mutableCopy];
			mainFileCandidatesToBe = [@[] mutableCopy];
			filenames = [@[] mutableCopy];

			NSDictionary *filesByFilename = dict[@"files"];
			if (![self objectIsKindOfClass:[NSDictionary class]
			        andIsNonNilAndNonEmpty:filesByFilename]) {
				error = [self invalidFormatError];
			}
			for (NSDictionary *fileDict in [filesByFilename allValues]) {
				if (![self objectIsKindOfClass:[NSDictionary class]
				        andIsNonNilAndNonEmpty:fileDict]) {
					error = [self invalidFormatError];
					break;
				}

				NSString *filename = fileDict[@"filename"];
				if (![self objectIsKindOfClass:[NSString class]
				        andIsNonNilAndNonEmpty:filename]) {
					error = [self invalidFormatError];
				}
				NSURL *fileURL = [gistDirectoryURL URLByAppendingPathComponent:filename
				                                                   isDirectory:NO];
				NSURL *fileParentURL = [fileURL URLByDeletingLastPathComponent];
				if (![fileParentURL isEqual:gistDirectoryURL]) {
					[manager createDirectoryAtURL:fileParentURL
					  withIntermediateDirectories:YES attributes:nil error:&error];
				}

				NSString *contentString = fileDict[@"content"];
				if (contentString) {
					NSData *contentData = [contentString dataUsingEncoding:NSUTF8StringEncoding];
					if ([contentData writeToURL:fileURL options:(NSDataWritingOptions)0
					                      error:&error]) {
						error = nil;
					}
				} else {
					NSString *contentURLString = fileDict[@"raw_url"];
					if (![self objectIsKindOfClass:[NSString class]
					        andIsNonNilAndNonEmpty:contentURLString]) {
						error = [self invalidFormatError];
					}
					NSURL *contentURL = [NSURL URLWithString:contentURLString];

					NSURLDownload *download = [[NSURLDownload alloc]
						initWithRequest:[NSURLRequest requestWithURL:contentURL] delegate:self];
					[download setDestination:fileURL.path allowOverwrite:YES];
					[filenames addObject:filename];
					downloadsByFilename[filename] = download;
				}

				[allFileURLsToBe addObject:fileURL];
				if ([setOfMainFileTypes containsObject:[filename pathExtension]]) {
					[mainFileCandidatesToBe addObject:fileURL];
				}
			}
		}
		if (error) {
			[self cancelDownloadsAndPresentError:error];
		} else {
			allDownloadFilenames = [filenames copy];
			mainFileCandidates = [mainFileCandidatesToBe copy];
			allFileURLs = [allFileURLsToBe copy];

			if (downloadsByFilename.count > 0) {
				//TODO: Only show the window after downloads (plus the initial API request) have progressed for some seconds.
				//TODO: Set the window's title.
				[self.loadingProgressBar startAnimation:nil];
			} else {
				//No need to show the main window—we have everything already.
				[self cancelShowWindowTimer];

				[self launchMainFileInCodeRunner];
			}
		}
	}];
}

- (void) cancelShowWindowTimer {
	[showWindowTimer invalidate];
	showWindowTimer = nil;
}

- (void) showWindowAfterTimer:(NSTimer *)showWindowAfterTimer {
	//Make sure we have the progress bar to be able to start it.
	(void)[self window];

	[self.loadingProgressBar startAnimation:nil];
	[self showWindow:nil];
}

- (NSURL *) githubAPIGistURLWithWebGistURL:(NSURL *)url {
	NSString *gistID = [url lastPathComponent];
	NSURL *githubAPIRootURL = [NSURL URLWithString:@"https://api.github.com/gists/"];
	NSURL *githubAPIGistURL = [githubAPIRootURL URLByAppendingPathComponent:gistID];
	return githubAPIGistURL;
}

- (void) cancelDownloadsAndPresentError:(NSError *)error {
	[self cancelAllDownloads];

	[self.window presentError:error modalForWindow:self.window
	                 delegate:self didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:)
			      contextInfo:NULL];
}

- (void) cancelAllDownloads {
	[[downloadsByFilename allValues] makeObjectsPerformSelector:@selector(cancel)];
	[downloadsByFilename removeAllObjects];
	allDownloadFilenames = nil;
}

- (bool) objectIsKindOfClass:(Class)class andIsNonNilAndNonEmpty:(id)obj {
	if (![obj isKindOfClass:class]) return false;
	if ([obj respondsToSelector:@selector(length)] && [obj length] == 0) return false;
	if ([obj respondsToSelector:@selector(count)] && [obj count] == 0) return false;
	return true;
}

- (NSError *) invalidFormatError {
	return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
}

- (void) didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo {
	[self close];
	[self notifyDelegateOfCompletion];
}

- (void) notifyDelegateOfCompletion {
	[self.delegate gistToCodeRunnerDidFinish:self];
}

- (void) downloadDidFinish:(NSURLDownload *)download {
	for (NSString *filename in allDownloadFilenames) {
		if (downloadsByFilename[filename] == download) {
			[downloadsByFilename removeObjectForKey:filename];
		}
	}

	if (downloadsByFilename.count == 0) {
		[self launchMainFileInCodeRunner];
	}
}

- (void) launchMainFileInCodeRunner {
	if (mainFileCandidates.count > 1) {
		NSWindow *window = [self window];
		[self populatePopUpMenu];
		window.contentView = self.fileToOpenPickerView;

		//Just in case we weren't already visible.
		[self cancelShowWindowTimer];
		[self showWindow:nil];
	} else {
		NSURL *mainFileURL =
			mainFileCandidates.count >= 1
				? [mainFileCandidates objectAtIndex:0]
				: allFileURLs.count == 1
				? [allFileURLs objectAtIndex:0]
				: nil;
		if (!mainFileURL) {
			//TODO: Present an error.
		} else {
			[self launchFileInCodeRunner:mainFileURL];
		}
	}
}

- (void) populatePopUpMenu {
	NSMenu *menu = [self.fileToOpenPopUp menu];
	[menu removeAllItems];
	for (NSURL *URL in allFileURLs) {
		NSMenuItem *menuItem = [menu addItemWithTitle:[URL lastPathComponent]
		                                       action:@selector(selectMainFileURLWithMenuItem:)
			                            keyEquivalent:@""];
		menuItem.target = self;
		menuItem.representedObject = URL;
	}
}

- (IBAction) selectMainFileURLWithMenuItem:(id)sender {
	self.selectedMainFileURL = [sender representedObject];
}

- (void) launchFileInCodeRunner:(NSURL *)fileURL {
	[[NSWorkspace sharedWorkspace] openURLs:@[fileURL]
	                withAppBundleIdentifier:codeRunnerBundleIdentifier
						            options:NSWorkspaceLaunchAsync
			 additionalEventParamDescriptor:nil launchIdentifiers:NULL];

	[self notifyDelegateOfCompletion];
}

- (void) download:(NSURLDownload *)download didFailWithError:(NSError *)error {
	[self cancelDownloadsAndPresentError:error];
}

- (void) windowWillClose:(NSNotification *)notification {
	[self cancelAllDownloads];
}

- (IBAction)openSelectedMainFile:(id)sender {
	[self launchFileInCodeRunner:self.selectedMainFileURL];
}

- (IBAction)cancel:(id)sender {
	[self cancelAllDownloads];
	[self close];
}

@end
