//
//  Magic.h
//  Mailboxer
//
//  Created by  Sven on 22.03.2007
//  Copyright 2006 earthlingsoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#include <uuid/uuid.h>
#include "VersionChecker.h"

#define MENUNAME @"NAME"
#define MENUOBJECT @"OBJECT"
#define MENUITEMALL @"ALL"
#define ALLDICTIONARY [NSDictionary dictionaryWithObjectsAndKeys:MENUITEMALL, MENUOBJECT, NSLocalizedString(@"All Contacts", @"All Contacts"), MENUNAME, nil]


@interface Magic : NSObject {
	IBOutlet NSProgressIndicator * progressBar;
	NSDate * lastProgressBarUpdate;
	IBOutlet NSWindow * mainWindow;
	IBOutlet NSPanel * warningMessage;
	NSString * sheetMessage;
	NSArray * groups;
	BOOL running;
	int recordCount;
	int currentPosition;
	NSUserDefaultsController * UDC;
}
- (void) buildGroupList;
- (IBAction) do:(id) sender;
- (void) do2:(id) sender;
- (IBAction) dismissSheet:(id) sender;
- (NSString*) cleanString:(NSString*) s from:(NSString*) evil ;
- (NSString*) uuid;
- (NSData*) AddressBookIcon;
- (NSData*) GoogleEarthIcon;
- (void) error: (NSString*) error;
- (void) readme:(id) sender;
- (NSString*) myVersionString;
- (IBAction)menuCheckVersion:(id)sender;
@end

@interface ABGroup (ESSortExtension)
- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup ;
@end