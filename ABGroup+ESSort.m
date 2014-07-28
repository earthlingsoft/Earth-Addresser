//
//  ABGroup+ESSort.m
//  Earth Addresser
//
//  Created by Sven on 29.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ABGroup+ESSort.h"

@implementation ABGroup (ESSort)

- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup {
	NSString * myName = [self valueForProperty:kABGroupNameProperty];
	NSString * theirName = [aGroup valueForProperty:kABGroupNameProperty];
	return [myName localizedCaseInsensitiveCompare:theirName];
}

@end
