//
//  ESEAPOperation.h
//  Earth Addresser
//
//  Created by  Sven on 26.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Magic;


@interface ESEAOperation : NSOperation

@property (weak) Magic * owner;
@property NSArray * people;
@property double progress;

- (instancetype) initWithPeople:(NSArray *)people forOwner:(Magic *)owner;

@end
