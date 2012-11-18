//
//  PRHGistToCodeRunnerWindowController.h
//  CodeRunner Gist adapter
//
//  Created by Peter Hosey on 2012-11-16.
//  Copyright (c) 2012 Peter Hosey. All rights reserved.
//

@class PRHAppDelegate;
@protocol PRHGistToCodeRunnerWindowControllerDelegate;

@interface PRHGistToCodeRunnerWindowController : NSWindowController

@property(nonatomic, strong) NSURL *gistURL;
@property(nonatomic, strong) id <PRHGistToCodeRunnerWindowControllerDelegate> delegate;

- (void) start;
@end

@protocol PRHGistToCodeRunnerWindowControllerDelegate <NSObject>

- (void) gistToCodeRunnerDidFinish:(PRHGistToCodeRunnerWindowController *)windowController;

@end
