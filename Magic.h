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
	
	NSThread * geocodingThread;
	IBOutlet NSProgressIndicator * geocodingProgressBar;
	
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
@property double geocodingProgress;
@property double geocodingMaximum;
@property (readonly) NSString * geocodingButtonLabel;

@property BOOL KMLRunning;
@property double KMLProgress;
@property double KMLMaximum;
@property (readonly) NSString * KMLWritingButtonLabel;

@property NSInteger notSearchedCount;
@property BOOL nonLocatableAddressesExist;
@property BOOL nonLocatableAddressesButtonHidden;

@property NSString * relevantPeopleInfo;
@property NSString * lookupInfo;
@property NSString * doneMessage;

@property NSInteger addressesAreAvailable;
@property NSString * currentLookupAddress;
@property (readonly) BOOL needToSearchNoticeHidden;
@property (readonly) BOOL nothingToSearch;

@property (readonly) NSImage * AddressBookIcon;
@property (readonly) NSImage * MapsIcon;
@property (readonly) NSImage * KMLIcon;

@property (readonly) NSURL * EAApplicationSupportURL;
@property (readonly) NSString * myVersionString;


- (void) buildGroupList;

- (IBAction) addressBookScopeChanged: (id) sender;
- (IBAction) groupListSelectionChanged: (id) sender;

- (IBAction) convertAddresses: (id) sender;
- (void) convertAddresses2: (id) sender;

- (NSString *) fullPNGImagePathForName:(NSString *)name;
- (NSXMLElement *) createStyleForImageData:(NSData *)image withID:(NSString *)ID;
- (NSXMLElement *) genericStyleNamed:(NSString *)name;

- (IBAction) do:(id) sender;
- (void) do2:(id) sender;

- (NSArray *) relevantPeople;
- (void) updateRelevantPeopleInfo:(NSArray*)people;

- (NSString *) dictionaryKeyForAddressDictionary:(NSDictionary *)address;
- (NSString *) cleanString:(NSString*)s from:(NSString*)evil ;

- (NSString *) localisedLabelName: (NSString*) label;

- (IBAction) dismissSheet:(id) sender;
- (IBAction) showWarningInfo: (id) sender;
- (IBAction) toggleGroupByLabel: (id) sender;
- (IBAction) toggleHideOldByDefault: (id) sender;
- (IBAction) createListOfNonLocatableAddresses:(id) sender;
- (IBAction) lookupNonLocatableAddresses: (id) sender;

- (IBAction) readme:(id) sender;
- (void) beginBusy;
- (void) endBusy;
@end

@interface ABGroup (ESSortExtension)
- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup ;
@end

NSInteger nameSort(id person1, id person2, void *context);
