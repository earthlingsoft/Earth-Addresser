//
//  ESAddressHelper.m
//  Earth Addresser
//
//  Created by Sven on 25.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESAddressHelper.h"
#import "ESTerm.h"
#import <AddressBook/AddressBook.h>

@implementation ESAddressHelper

- (instancetype) init {
	self = [super init];
	if (self) {
		[self loadTermsToRemove];
	}
	return self;
}





#pragma mark User Defaults

NSString * const addressTermsToRemoveKeyPath = @"values.addressTermsToRemove";

- (void) loadTermsToRemove {
	self.termsToRemove = [NSMutableArray array];
	NSArray * parts = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:addressTermsToRemoveKeyPath];
	for (NSDictionary * partDict in parts) {
		ESTerm * partTerm = [[ESTerm alloc] initWithDictionary:partDict];
		[self.termsToRemove addObject:partTerm];
	}
}


- (void) updateDefaults {
	NSMutableArray * terms = [NSMutableArray array];
	for (ESTerm * term in self.termsToRemove) {
		NSDictionary * dict = term.dictionary;
		[terms addObject:dict];
	}
	[[NSUserDefaultsController sharedUserDefaultsController] setValue:terms forKeyPath:addressTermsToRemoveKeyPath];
}





#pragma mark KVO

- (void) observeValueForKeyPath:(NSString *)keyPath
					   ofObject:(id)object
						 change:(NSDictionary *)change
						context:(void *)context {
	if ([keyPath isEqualToString:@"arrangedObjects"]) {
		[self updateDefaults];
	}
}





#pragma mark Address Cleanup

- (NSString *) keyForAddress:(NSDictionary *)address {
	return [[self componentsForAddress:address] componentsJoinedByString:@", "];
}



- (NSArray *) componentsForAddress:(NSDictionary *)address {
	NSMutableArray * addressComponents = [NSMutableArray arrayWithCapacity:5];
	
	NSString * addressComponent = address[kABAddressStreetKey];
	if (addressComponent) {
		NSString * cleanedComponent = [self cleanAddress:addressComponent];
		if (cleanedComponent.length > 0) {
			[self addString:cleanedComponent toArray:addressComponents];
		}
	}
	
	[self addComponent:kABAddressCityKey ofAddress:address toArray:addressComponents];
	[self addComponent:kABAddressZIPKey ofAddress:address toArray:addressComponents];
	[self addComponent:kABAddressStateKey ofAddress:address toArray:addressComponents];
	[self addComponent:kABAddressCountryCodeKey ofAddress:address toArray:addressComponents];
	
	return addressComponents;
}



- (void) addComponent:(NSString *)componentKey ofAddress:(NSDictionary *)address toArray:(NSMutableArray *)array {
	NSString * addressComponent = address[componentKey];
	if (addressComponent) {
		[self addString:addressComponent toArray:array];
	}
}



- (void) addString:(NSString *)string toArray:(NSMutableArray *)array {
	NSString * cleanedString = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	cleanedString = [cleanedString stringByReplacingOccurrencesOfString:@"\n" withString:@", "];
	if ([cleanedString length] > 0) {
		[array addObject:cleanedString];
	}
}



- (NSString *) cleanAddress:(NSString *)address {
	NSArray * addressLines = [address componentsSeparatedByString:@"\n"];
	NSMutableArray * cleanAddressLines = [NSMutableArray arrayWithCapacity:addressLines.count];
	
	for (NSString * addressLine in addressLines) {
		BOOL keepLine = YES;
		for (ESTerm * term in self.termsToRemove) {
			if (term.active) {
				NSRange termRange = [addressLine rangeOfString:term.string options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch];
				if (termRange.location != NSNotFound) {
					keepLine = NO;
					break;
				}
			}
		}
		if (keepLine) {
			[cleanAddressLines addObject:addressLine];
		}
	}
	
	return [cleanAddressLines componentsJoinedByString:@"\n"];
}

@end
