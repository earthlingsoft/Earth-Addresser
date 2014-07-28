//
//  ESAddressLookupOperation.h
//  Earth Addresser
//
//  Created by Sven on 25.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESEAOperation.h"


@interface ESAddressLookupOperation : ESEAOperation

@property NSMutableDictionary * locations;
@property NSMutableDictionary * failLocations;

@property NSTimeInterval previousLookup;
@property NSTimeInterval secondsBetweenCoordinateLookups;

@end
