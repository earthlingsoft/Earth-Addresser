//
//  Magic.h
//  Mailboxer
//
//  Created by  Sven on 22.03.2007
//  Copyright 2006-2009 earthlingsoft. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#include <uuid/uuid.h>
#include "VersionChecker.h"

#define APIKEY @"ABQIAAAAlHKFjYnAwG075OeYhnD30xRxdMQYmQaEcayIZUdLHbQwQRmWDRQAobR9d1SmZ4paTmBsalsw0pvc4w"
#define MENUNAME @"NAME"
#define MENUOBJECT @"OBJECT"
#define MENUITEMALL @"ALL"
#define OMITNAMESDEFAULT @"Omit Names"
#define ALLDICTIONARY [NSDictionary dictionaryWithObjectsAndKeys:MENUITEMALL, MENUOBJECT, NSLocalizedString(@"All Contacts", @"All Contacts"), MENUNAME, nil]
#define SECONDSBETWEENCOORDINATELOOKUPS 0.2

@interface Magic : NSObject {
	IBOutlet NSProgressIndicator * progressBar;
	NSDate * lastProgressBarUpdate;
	BOOL running;
	int recordCount;
	int currentPosition;
	
	IBOutlet NSProgressIndicator * geocodingProgressBar;
	NSDate * lastGeocodingProgressBarUpdate;
	BOOL geocodingRunning;
	int geocodingRecordCount;
	int geocodingCurrentPosition;
	
	NSString * relevantPeopleInfo;

	int notSearchedCount;
	
	IBOutlet NSWindow * mainWindow;
	IBOutlet NSPanel * warningMessage;
	NSString * sheetMessage;
	
	NSArray * groups;

	NSMutableDictionary * locations;
}

- (void) saveLocations;
- (void) buildGroupList;

- (IBAction) addressBookScopeChanged: (id) sender;
- (IBAction) groupListSelectionChanged: (id) sender;

- (IBAction) convertAddresses: (id) sender;
- (IBAction) do:(id) sender;
- (void) do2:(id) sender;


- (NSArray*) relevantPeople;
- (void) updateRelevantPeopleInfo;

- (NSString*) googleStringForAddressDictionary : (NSDictionary*) address;
- (NSMutableString*) dictionaryKeyForAddressDictionary : (NSDictionary*) address;
- (NSString*) cleanString:(NSString*) s from:(NSString*) evil ;

- (NSData*) AddressBookIcon;
- (NSData*) GoogleEarthIcon;

- (NSString *) localisedLabelName: (NSString*) label;

- (NSString*) uuid;
- (void) error: (NSString*) error;

- (IBAction) dismissSheet:(id) sender;
- (IBAction) showWarningInfo: (id) sender;

- (void) readme:(id) sender;
- (NSString*) myVersionString;
- (IBAction) autoCheckForUpdates: (id) sender;
- (IBAction)menuCheckVersion:(id)sender;

@end

@interface ABGroup (ESSortExtension)
- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup ;
@end