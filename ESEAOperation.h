//
//  ESEAPOperation.h
//  Earth Addresser
//
//  Created by  Sven on 26.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ESAddressHelper.h"


@interface ESEAOperation : NSOperation {
	double _progress;
	NSString * _statusMessage;
}

extern NSString * const ESEAOperationFinishedNotification;
extern NSString * const ESEAOperationProgressNotification;
extern NSString * const ESEAOperationProgressKey;
extern NSString * const ESEAOperationStatusMessageNotification;
extern NSString * const ESEAOperationMessageKey;


@property NSArray * people;

@property double progress;
@property NSString * statusMessage;

@property ESAddressHelper * addressHelper;


- (instancetype) initWithPeople:(NSArray *)people;

@end
