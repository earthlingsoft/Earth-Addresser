//
//  Magic.h
//  Mailboxer
//
//  Created by  Sven on 22.03.2007
//  Copyright 2006-2009 earthlingsoft. All rights reserved.
//

/*
#if __LP64__
#else
#define NSInteger long
#define NSUInteger unsigned long
#define CGFloat float
#define integerValue intValue
#endif
*/


#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#include <uuid/uuid.h>
#include "VersionChecker.h"

#define GOOGLEAPIKEY @"ABQIAAAAlHKFjYnAwG075OeYhnD30xRxdMQYmQaEcayIZUdLHbQwQRmWDRQAobR9d1SmZ4paTmBsalsw0pvc4w"
#define MENUNAME @"NAME"
#define MENUOBJECT @"OBJECT"
#define MENUITEMALL @"ALL"
#define FAILSTRING @"FAIL"
#define OMITNAMESDEFAULT @"Omit Names"
#define EAGENERICSTYLEPREFIX @"EarthAddresser-generic-"
#define GENERICHOMEICONNAME @"home"
#define GENERICWORKICONNAME @"work"
#define ALLDICTIONARY [NSDictionary dictionaryWithObjectsAndKeys:MENUITEMALL, MENUOBJECT, NSLocalizedString(@"All Contacts", @"All Contacts"), MENUNAME, nil]
#define SECONDSBETWEENCOORDINATELOOKUPS 0.2
#define UDC [NSUserDefaultsController sharedUserDefaultsController]
#define UPDATEURL @"http://www.earthlingsoft.net/Earth%20Addresser/Earth%20Addresser.xml"
// Text in 'Old' labels whose groups are automatically hidden -> Localised
#define OLDLABELS [NSArray arrayWithObjects:@"Old", @"Alt", @"Ancienne", nil]


@interface Magic : NSObject {
	IBOutlet NSProgressIndicator * progressBar;
//	double KMLProgress;
//	double KMLMaximum;
	BOOL running;
	
	NSThread * geocodingThread;
	IBOutlet NSProgressIndicator * geocodingProgressBar;
	NSString * geocodingError;
	BOOL geocodingRunning;
	
	NSString * relevantPeopleInfo;
	NSString * lookupInfo;
	NSString * doneMessage;
	
	NSInteger addressesAreAvailable;
	NSInteger notSearchedCount;
	BOOL nonLocatableAddressesExist;
	BOOL nonLocatableAddressesButtonHidden;
	IBOutlet NSButton * runGeolocationButton;
	IBOutlet NSButton * createKMLButton;
	
	IBOutlet NSWindow * mainWindow;
	IBOutlet NSPanel * warningMessage;
	
	NSArray * groups;
	BOOL noGroups;

	NSMutableDictionary * locations;
}

- (void) saveLocations;
- (void) buildGroupList;

- (IBAction) addressBookScopeChanged: (id) sender;
- (IBAction) groupListSelectionChanged: (id) sender;

- (IBAction) convertAddresses: (id) sender;
- (IBAction) convertAddresses2: (id) sender;

- (NSString *) imagesFolderPath;
- (NSString *) fullPNGImagePathForName: (NSString *) name;
- (NSXMLElement *) createStyleForImageData: (NSData *) image withID:(NSString *) ID;
- (NSXMLElement *) genericStyleNamed:(NSString *) name;

- (IBAction) do:(id) sender;
- (void) do2:(id) sender;

- (NSArray*) relevantPeople;
- (void) updateRelevantPeopleInfo:(NSArray*) people;

- (NSString*) googleStringForAddressDictionary : (NSDictionary*) address;
- (NSMutableString*) dictionaryKeyForAddressDictionary : (NSDictionary*) address;
- (NSString*) cleanString:(NSString*) s from:(NSString*) evil ;

- (BOOL) needToSearchNoticeHidden;
- (NSData*) AddressBookIcon;
- (NSData*) GoogleEarthIcon;

- (NSString *) localisedLabelName: (NSString*) label;

- (NSString*) uuid;
- (void) error: (NSString*) error;

- (IBAction) dismissSheet:(id) sender;
- (IBAction) showWarningInfo: (id) sender;
- (IBAction) toggleGroupByLabel: (id) sender;
- (IBAction) toggleHideOldByDefault: (id) sender;
- (IBAction) createListOfNonLocatableAddresses:(id) sender;
- (IBAction) lookupNonLocatableAddresses: (id) sender;


- (IBAction) readme:(id) sender;
- (NSString*) myVersionString;
- (IBAction) autoCheckForUpdates: (id) sender;
- (IBAction) menuCheckVersion:(id)sender;


+ (void) disableSuddenTermination;
+ (void) enableSuddenTermination;

@end

@interface ABGroup (ESSortExtension)
- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup ;
@end

NSInteger nameSort(id person1, id person2, void *context);
