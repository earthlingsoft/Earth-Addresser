//
//  ABRecord+ESSort.h
//  Earth Addresser
//
//  Created by Sven on 30.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

@interface ABRecord (ESSort)

- (NSComparisonResult)nameCompare:(ABRecord *)otherRecord;

@end
