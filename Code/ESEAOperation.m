//
//  ESEAPOperation.m
//  Earth Addresser
//
//  Created by  Sven on 26.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESEAOperation.h"

@implementation ESEAOperation

NSString * const ESEAOperationFinishedNotification = @"ESEAOperation Finished";
NSString * const ESEAOperationProgressNotification = @"ESEAOperation Progress";
NSString * const ESEAOperationProgressKey = @"progress";
NSString * const ESEAOperationStatusMessageNotification = @"ESKMLOperation Status Message";
NSString * const ESEAOperationMessageKey = @"message";



- (instancetype) initWithPeople:(NSArray *)people {
	self = [super init];
	if (self) {
		self.people = [people copy];
		
		ESEAOperation * __weak weakSelf = self;
		self.completionBlock = ^(void) {
			[[NSNotificationCenter defaultCenter] postNotificationName:ESEAOperationFinishedNotification object:weakSelf];
		};
	}
	return self;
}





#pragma mark Accessors

- (double) progress {
	return _progress;
}


- (void) setProgress:(double)newProgress {
	_progress = newProgress;
	[[NSNotificationCenter defaultCenter] postNotificationName:ESEAOperationProgressNotification object:self userInfo:@{ESEAOperationProgressKey:@(_progress)}];
}



- (NSString *) statusMessage {
	return _statusMessage;
}


- (void) setStatusMessage:(NSString *)statusMessage {
	_statusMessage = statusMessage;
	[[NSNotificationCenter defaultCenter] postNotificationName:ESEAOperationStatusMessageNotification object:self userInfo:@{ESEAOperationMessageKey:_statusMessage}];
}

@end
