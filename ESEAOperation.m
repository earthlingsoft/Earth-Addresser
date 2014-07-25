//
//  ESEAPOperation.m
//  Earth Addresser
//
//  Created by  Sven on 26.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESEAOperation.h"

@implementation ESEAOperation

- (instancetype) initWithPeople:(NSArray *)people forOwner:(Magic *)owner {
	self = [super init];
	if (self) {
		self.people = people;
		self.owner = owner;
	}
	return self;
}

@end
