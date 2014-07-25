//
//  ESAddressLookupOperation.m
//  Earth Addresser
//
//  Created by Sven on 25.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESAddressLookupOperation.h"
#import "Magic.h"
#import "ESAddressHelper.h"
#import <AddressBook/AddressBook.h>
#import <CoreLocation/CoreLocation.h>

@implementation ESAddressLookupOperation

const NSTimeInterval secondsBetweenCoordinateLookups = 1.0;

- (void) main {
	self.progress = .000001;
	
	ABPerson * myPerson;
	self.previousLookup = 0;
	
	for (ABPerson * person in self.people) {
		if (self.isCancelled) {
			break;
		}
		[self lookupAddressesForPerson:person];
	}
}


- (void (^)(void)) completionBlock {
	self.owner.currentLookupAddress = @"";
	[self.owner writeCaches];
	[self.owner endBusy];
	self.owner.geocodingOperation = nil;
}


- (void) lookupAddressesForPerson:(ABPerson *)person {
	@autoreleasepool {
		ABMultiValue * addresses = [person valueForProperty:kABAddressProperty];
		NSUInteger addressCount = [addresses count];
		NSUInteger index = 0;
		while (addressCount > index) {
			NSDictionary * addressDict = [addresses valueAtIndex:index];
			
			[self lookupAddress:addressDict];
			
			index++;
		}
	}
}


- (void) lookupAddress:(NSDictionary *)addressDict {
	NSString * addressString = [self.owner.addressHelper keyForAddress:addressDict];
	
	if (!self.owner.locations[addressString] && !self.owner.failLocations[addressString]) {
		// Look up address if we don’t know its coordinates already
		self.owner.currentLookupAddress = addressString;
		
		// throttle queries
		if (self.previousLookup != 0) {
			NSDate * wakeUpTime = [NSDate dateWithTimeIntervalSinceReferenceDate:self.previousLookup + secondsBetweenCoordinateLookups];
			[NSThread sleepUntilDate:wakeUpTime];
		}
		self.previousLookup = [NSDate timeIntervalSinceReferenceDate];
		
		[[[CLGeocoder alloc] init]
			geocodeAddressDictionary:addressDict
			completionHandler:^(NSArray * placemarks, NSError * lookupError) {
				if ([placemarks count] == 1) {
					CLPlacemark * placemark = placemarks[0];
					CLLocation * location = placemark.location;
					self.owner.locations[addressString] = @{
						@"lat": @(location.coordinate.latitude),
						@"lon": @(location.coordinate.longitude),
						@"accuracy": @(location.horizontalAccuracy),
						@"timestamp": @(location.timestamp.timeIntervalSince1970),
						@"resultType": @"unique"
					};
				}
				else if ([placemarks count] > 1) {
					NSLog(@"Found %lu locations for address: %@", [placemarks count], addressString);
					NSMutableArray * locationStrings = [NSMutableArray array];
					[placemarks enumerateObjectsUsingBlock:^(CLPlacemark * placemark, NSUInteger idx, BOOL * stop) {
						[locationStrings addObject:[placemark.location description]];
					}];
					NSDictionary * failInfo = @{
						@"type": @"multiple",
						@"locations": locationStrings
					};
					self.owner.failLocations[addressString] = failInfo;
				}
				else {
					if (lookupError) {
						NSLog(@"Could not locate address: %@", addressString);
						NSLog(@"error: %@", lookupError);
						NSDictionary * errorInfo = @{
						   @"type": @"error",
						   @"domain": [lookupError domain],
						   @"code": [NSNumber numberWithInt:[lookupError code]],
						   @"userInfo": [lookupError userInfo]
						};
						self.owner.failLocations[addressString] = errorInfo;
					}
				}
			}
		];
		
		self.progress += 1;
		[self.owner relevantPeople];
	}
}

@end
