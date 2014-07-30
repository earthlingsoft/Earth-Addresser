//
//  ESAddressLookupOperation.m
//  Earth Addresser
//
//  Created by Sven on 25.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESAddressLookupOperation.h"
#import <AddressBook/AddressBook.h>
#import <CoreLocation/CoreLocation.h>

@implementation ESAddressLookupOperation

- (void) main {
	self.progress = .000001;
	
	ABPerson * myPerson;
	self.previousLookup = 0;
	self.secondsBetweenCoordinateLookups = ((NSNumber *)[[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.secondsBetweenCoordinateLookups"]).doubleValue;
	
	NSArray * addresses = [self addressesForPeople:self.people];
	for (NSDictionary * addressDict in addresses) {
		if (self.isCancelled) {
			break;
		}
		@autoreleasepool {
			[self lookupAddress:addressDict];
		}
	}
	
	self.statusMessage = @"";
}





#pragma mark Address lookup

- (NSArray *) addressesForPeople:(NSArray *)people {
	NSMutableArray * allAddresses = [NSMutableArray array];
	
	for (ABPerson * person in people) {
		ABMultiValue * personAddresses = [person valueForProperty:kABAddressProperty];
		NSUInteger addressCount = [personAddresses count];
		
		for (NSUInteger addressIndex = 0; addressIndex < addressCount; addressIndex++) {
			NSDictionary * addressDict = [self.addressHelper normaliseAddress:[personAddresses valueAtIndex:addressIndex]];
			[allAddresses addObject:addressDict];
		}
	}
	
	return allAddresses;
}



- (void) lookupAddress:(NSDictionary *)addressDict {
	NSString * addressString = [self.addressHelper keyForAddress:addressDict];
	if (!self.locations[addressString] && !self.failLocations[addressString]) {
		// This address has not been looked up yet.
		[self geocodeAddress:addressDict];
	}
}



- (void) geocodeAddress:(NSDictionary *)addressDict {
	NSString * addressString = [self.addressHelper keyForAddress:addressDict];
	NSString * displayString = [[ABAddressBook sharedAddressBook] formattedAddressFromDictionary:addressDict].string;
	displayString = [displayString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	displayString = [displayString stringByReplacingOccurrencesOfString:@"\n\\s*" withString:@", " options:NSRegularExpressionSearch range:NSMakeRange(0, displayString.length)];
	self.statusMessage = [NSString stringWithFormat:NSLocalizedString(@"Looking up: %@", @"Status message for address lookup with current address."), displayString];
	
	// throttle queries
	if (self.previousLookup != 0) {
		NSDate * wakeUpTime = [NSDate dateWithTimeIntervalSinceReferenceDate:self.previousLookup + self.secondsBetweenCoordinateLookups];
		[NSThread sleepUntilDate:wakeUpTime];
	}
	self.previousLookup = [NSDate timeIntervalSinceReferenceDate];
	
	self.geocoder = [[CLGeocoder alloc] init];
	[self.geocoder geocodeAddressDictionary:addressDict completionHandler:^(NSArray * placemarks, NSError * lookupError) {
		if (placemarks.count == 1) {
			CLPlacemark * placemark = placemarks[0];
			CLLocation * location = placemark.location;
			self.locations[addressString] = @{
				@"lat": @(location.coordinate.latitude),
				@"lon": @(location.coordinate.longitude),
				@"accuracy": @(location.horizontalAccuracy),
				@"timestamp": @(location.timestamp.timeIntervalSince1970),
				@"resultType": @"unique"
			};
		}
		else if (placemarks.count > 1) {
			NSMutableArray * locationStrings = [NSMutableArray array];
			[placemarks enumerateObjectsUsingBlock:^(CLPlacemark * placemark, NSUInteger idx, BOOL * stop) {
				[locationStrings addObject:placemark.location.description];
			}];
			NSDictionary * failInfo = @{
				@"type": @"multiple",
				@"locations": locationStrings
			};
			self.failLocations[addressString] = failInfo;
		}
		else {
			if (lookupError && !self.isCancelled) {
				if (lookupError.domain == kCLErrorDomain && lookupError.code == kCLErrorNetwork) {
					// Network problem
					self.statusMessage = NSLocalizedString(@"Network error. Will attempt to look this address up the next time.", @"Error message shown when address lookup failed with a netork error.");
				}
				else {
					NSDictionary * errorInfo = @{
						@"type": @"error",
						@"domain": lookupError.domain,
						@"code": @(lookupError.code)
					};
					self.failLocations[addressString] = errorInfo;
					self.statusMessage = [NSString stringWithFormat:NSLocalizedString(@"Lookup failed for: %@", @"Error message shown when address lookup failed."), addressString];
				}
			}
		}

		self.progress += 1;
		self.geocoder = nil;
	}];
	
	
	NSTimeInterval geocoderPollInterval = 0.05;
	while (self.geocoder) {
		if (self.isCancelled) {
			self.statusMessage = NSLocalizedString(@"Address lookup cancelled", @"Status message for cancelled address lookup.");
			[self.geocoder cancelGeocode];
		}
		[NSThread sleepForTimeInterval:geocoderPollInterval];
	}
}

@end
