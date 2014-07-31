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

NSString * const isExecutingName = @"isExecuting";
NSString * const isFinishedName = @"isFinished";


- (instancetype) initWithPeople:(NSArray *)people {
	self = [super initWithPeople:people];
	if (self) {
		executing = NO;
		finished = NO;
		_addressesToLookup = [NSMutableArray array];
	}
	return self;
}





# pragma mark Run the Operation asynchronously

- (void) start {
	if (self.isCancelled) {
		[self cancelOperation];
		return;
	}
	
	// If the operation is not cancelled, begin executing the task.
	[self willChangeValueForKey:isExecutingName];
	[self main];
	executing = YES;
	[self didChangeValueForKey:isExecutingName];
}



- (void) cancelOperation {
	self.statusMessage = NSLocalizedString(@"Address lookup cancelled", @"Status message for cancelled address lookup.");
	[self.addressesToLookup removeAllObjects];
	
	[self willChangeValueForKey:isFinishedName];
	finished = YES;
	[self didChangeValueForKey:isFinishedName];
}



- (void) main {
	self.progress = .000001;
	
	ABPerson * myPerson;
	self.previousLookup = 0;
	self.secondsBetweenCoordinateLookups = ((NSNumber *)[[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.secondsBetweenCoordinateLookups"]).doubleValue;
	
	[self fillAddressesToLookup];
	[self processNextAddress];
}



- (void) completeOperation {
	[self willChangeValueForKey:isFinishedName];
	[self willChangeValueForKey:isExecutingName];
	executing = NO;
	finished = YES;
	[self didChangeValueForKey:isExecutingName];
	[self didChangeValueForKey:isFinishedName];
}





#pragma mark Address lookup

- (void) fillAddressesToLookup {
	for (ABPerson * person in self.people) {
		ABMultiValue * personAddresses = [person valueForProperty:kABAddressProperty];
		NSUInteger addressCount = [personAddresses count];
		
		for (NSUInteger addressIndex = 0; addressIndex < addressCount; addressIndex++) {
			NSDictionary * addressDict = [self.addressHelper normaliseAddress:[personAddresses valueAtIndex:addressIndex]];
			NSString * addressString = [self.addressHelper keyForAddress:addressDict];
			if (!self.locations[addressString] && !self.failLocations[addressString]) {
				// This address has not been looked up yet.
				[self.addressesToLookup addObject:addressDict];
			}
		}
	}
}



- (void) processNextAddress {
	if (self.isCancelled) {
		[self cancelOperation];
	}
	
	if (self.addressesToLookup.count > 0) {
		// Take the first address from the list and look it up.
		NSDictionary * addressDict = self.addressesToLookup[0];
		[self.addressesToLookup removeObjectAtIndex:0];
		[self geocodeAddress:addressDict];
	}
	else {
		// If there are no addresses left, finish the operation.
		[self completeOperation];
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
		
		[self processNextAddress];
	}];
}





#pragma mark KVO

- (BOOL) isExecuting {
	return executing;
}



- (BOOL) isFinished {
	return finished;
}

@end
