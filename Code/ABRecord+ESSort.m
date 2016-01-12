//
//  ABRecord+ESSort.m
//  Earth Addresser
//
//  Created by Sven on 30.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ABRecord+ESSort.h"

@implementation ABRecord (ESSort)

- (NSComparisonResult) nameCompare:(ABRecord *)otherRecord {
	NSString * lastName1 = [self valueForProperty:kABLastNamePhoneticProperty];
	if (!lastName1) {
		lastName1 = [self valueForProperty:kABLastNameProperty];
	}
	NSString * lastName2 = [otherRecord valueForProperty:kABLastNamePhoneticProperty];
	if (!lastName2) {
		lastName2 = [otherRecord valueForProperty:kABLastNameProperty];
	}
	
	NSComparisonResult result = [lastName1 localizedCaseInsensitiveCompare:lastName2];
	
	if (result == NSOrderedSame) {
		NSString * firstName1 = [self valueForProperty:kABFirstNamePhoneticProperty];
		if (!firstName1) {
			firstName1 = [self valueForProperty:kABFirstNameProperty];
		}
		NSString * firstName2 = [otherRecord valueForProperty:kABFirstNamePhoneticProperty];
		if (!firstName2) {
			firstName2 = [otherRecord valueForProperty:kABFirstNameProperty];
		}
		
		result = [firstName1 localizedCaseInsensitiveCompare:firstName2];
		
		if (result == NSOrderedSame) {
			NSString * middleName1 = [self valueForProperty:kABMiddleNamePhoneticProperty];
			if (!middleName1) {
				middleName1 = [self valueForProperty:kABMiddleNameProperty];
			}
			NSString * middleName2 = [otherRecord valueForProperty:kABMiddleNamePhoneticProperty];
			if (!middleName2) {
				middleName2 = [otherRecord valueForProperty:kABMiddleNameProperty];
			}
			
			result = [middleName1 localizedCaseInsensitiveCompare:middleName2];
		}
	}
	
	return result;
}

@end
