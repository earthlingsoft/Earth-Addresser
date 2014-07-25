//
//  ESTerm.h
//  Earth Addresser
//
//  Created by Sven on 24.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ESTerm : NSObject

extern NSString * const ESTermActiveKey;
extern NSString * const ESTermStringKey;
extern NSString * const ESTermContentChangedNotification;


@property BOOL active;
@property NSString * string;

@property NSDictionary * dictionary;

- (instancetype) initWithDictionary:(NSDictionary *)dictionary;

@end
