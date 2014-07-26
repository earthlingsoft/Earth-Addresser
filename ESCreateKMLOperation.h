//
//  ESCreateKMLOperation.h
//  Earth Addresser
//
//  Created by Sven on 26.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESEAOperation.h"

@interface ESCreateKMLOperation : ESEAOperation

@property NSXMLDocument * KML;
@property NSXMLElement * KMLDocumentElement;
@property NSMutableDictionary * addressLabelGroups;

@end
