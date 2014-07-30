//
//  ESAddressLookupOperation.h
//  Earth Addresser
//
//  Created by Sven on 25.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESEAOperation.h"

@class CLGeocoder;


@interface ESAddressLookupOperation : ESEAOperation

@property NSMutableDictionary * locations;
@property NSMutableDictionary * failLocations;

@property CLGeocoder * geocoder;

@property NSTimeInterval previousLookup;
@property NSTimeInterval secondsBetweenCoordinateLookups;

@end
