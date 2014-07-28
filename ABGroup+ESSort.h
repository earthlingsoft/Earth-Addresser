//
//  ABGroup+ESSort.h
//  Earth Addresser
//
//  Created by Sven on 29.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import <AddressBook/AddressBook.h>

@interface ABGroup (ESSort)

- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup;

@end
