//
//  ESAddressHelper.h
//  Earth Addresser
//
//  Created by Sven on 25.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ESAddressHelper : NSObject

@property NSMutableArray * termsToRemove;

- (void) updateDefaults;

- (NSString *) keyForAddress:(NSDictionary *)address;
- (NSArray *) componentsForAddress:(NSDictionary *)address;

@end
