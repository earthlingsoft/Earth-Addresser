//
//  ESAddressLookupOperation.h
//  Earth Addresser
//
//  Created by Sven on 25.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESEAOperation.h"

@class CLGeocoder;


@interface ESAddressLookupOperation : ESEAOperation {
	BOOL executing;
	BOOL finished;
}

@property NSMutableDictionary * locations;
@property NSMutableDictionary * failLocations;

@property NSMutableArray * addressesToLookup;
@property CLGeocoder * geocoder;

@property NSTimeInterval previousLookup;
@property NSTimeInterval secondsBetweenCoordinateLookups;

- (instancetype) initWithPeople:(NSArray *)people;

@end
