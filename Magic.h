/*
  Magic.h
  Earth Addresser / Mailboxer

  Created by Sven on 22.03.2007
  Copyright 2006-2014 earthlingsoft. All rights reserved.
*/

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>

#define MENUNAME @"NAME"
#define MENUOBJECT @"OBJECT"
#define MENUITEMALL @"ALL"
#define OMITNAMESDEFAULT @"Omit Names"
#define EAGENERICSTYLEPREFIX @"EarthAddresser-generic-"
#define GENERICHOMEICONNAME @"home"
#define GENERICWORKICONNAME @"work"
#define ALLDICTIONARY [NSDictionary dictionaryWithObjectsAndKeys:MENUITEMALL, MENUOBJECT, NSLocalizedString(@"All Contacts", @"All Contacts"), MENUNAME, nil]
#define SECONDSBETWEENCOORDINATELOOKUPS 1.0
#define UDC [NSUserDefaultsController sharedUserDefaultsController]
#define UPDATEURL @"http://www.earthlingsoft.net/Earth%20Addresser/Earth%20Addresser.xml"
// Text in 'Old' labels whose groups are automatically hidden -> Localised
#define OLDLABELS [NSArray arrayWithObjects:@"Old", @"Alt", @"Ancienne", nil]


@interface Magic : NSObject {
	NSThread * KMLThread;
	IBOutlet NSProgressIndicator * progressBar;
	double KMLProgress;
	double KMLMaximum;
	BOOL KMLRunning;
	
	NSThread * geocodingThread;
	IBOutlet NSProgressIndicator * geocodingProgressBar;
	double geocodingProgress;
	double geocodingMaximum;
	
	NSString * relevantPeopleInfo;
	NSString * lookupInfo;
	NSString * doneMessage;
	
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
	NSMutableDictionary * failLocations;
}

@property BOOL geocodingRunning;
@property NSInteger addressesAreAvailable;
@property (strong) NSString * currentLookupAddress;

- (void) buildGroupList;

- (IBAction) addressBookScopeChanged: (id) sender;
- (IBAction) groupListSelectionChanged: (id) sender;

- (IBAction) convertAddresses: (id) sender;
- (void) convertAddresses2: (id) sender;

- (NSString *) imagesFolderPath;
- (NSString *) fullPNGImagePathForName: (NSString *) name;
- (NSXMLElement *) createStyleForImageData: (NSData *) image withID:(NSString *) ID;
- (NSXMLElement *) genericStyleNamed:(NSString *) name;

- (IBAction) do:(id) sender;
- (void) do2:(id) sender;

- (NSArray*) relevantPeople;
- (void) updateRelevantPeopleInfo:(NSArray*) people;

- (NSString*) dictionaryKeyForAddressDictionary:(NSDictionary *)address;
- (NSString*) cleanString:(NSString*) s from:(NSString*) evil ;

- (BOOL) needToSearchNoticeHidden;
- (NSImage*) AddressBookIcon;
- (NSImage*) MapsIcon;
- (NSImage*) KMLIcon;

- (NSString *) localisedLabelName: (NSString*) label;

- (IBAction) dismissSheet:(id) sender;
- (IBAction) showWarningInfo: (id) sender;
- (IBAction) toggleGroupByLabel: (id) sender;
- (IBAction) toggleHideOldByDefault: (id) sender;
- (IBAction) createListOfNonLocatableAddresses:(id) sender;
- (IBAction) lookupNonLocatableAddresses: (id) sender;

- (IBAction) readme:(id) sender;
- (NSString*) myVersionString;
- (void) beginBusy;
- (void) endBusy;
@end

@interface ABGroup (ESSortExtension)
- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup ;
@end

NSInteger nameSort(id person1, id person2, void *context);
