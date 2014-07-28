//
//  ESCreateKMLOperation.h
//  Earth Addresser
//
//  Created by Sven on 26.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESEAOperation.h"


@interface ESCreateKMLOperation : ESEAOperation

@property NSDictionary * locations;
@property NSArray * oldLabels;

@property NSMutableDictionary * addressLabelGroups;

@property NSXMLDocument * KML;
@property NSXMLElement * KMLDocumentElement;

@end
