//
//  ESTerm.m
//  Earth Addresser
//
//  Created by Sven on 24.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESTerm.h"

@implementation ESTerm

NSString * const ESTermActiveKey = @"active";
NSString * const ESTermStringKey = @"string";
NSString * const ESTermContentChangedNotification = @"ESTerm content changed";


- (instancetype) init {
	self = [super init];
	if (self) {
		self.active = YES;
		self.string = @"";
	}
	return self;
}


- (instancetype) initWithDictionary:(NSDictionary *)dictionary {
	self = [self init];
	if (self != nil) {
		self.dictionary = dictionary;
	}
	return self;
}


- (void) didChangeValueForKey:(NSString *)key {
	[super didChangeValueForKey:key];
	[[NSNotificationCenter defaultCenter] postNotificationName:ESTermContentChangedNotification object:self];
}


- (NSDictionary *) dictionary {
	return @{
		ESTermActiveKey: @(self.active),
		ESTermStringKey: (self.string ? self.string : @"")
	};
}


- (void) setDictionary:(NSDictionary *)dictionary {
	if (dictionary[ESTermActiveKey]) {
		self.active = ((NSNumber *)dictionary[ESTermActiveKey]).boolValue;
	}
	else {
		self.active = YES;
	}
	self.string = dictionary[ESTermStringKey];
}


- (NSString *) description {
	return [NSString stringWithFormat:@"string: %@, active: %@", self.string, @(self.active)];
}

@end
