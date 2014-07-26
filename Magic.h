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
#define ALLDICTIONARY [NSDictionary dictionaryWithObjectsAndKeys:MENUITEMALL, MENUOBJECT, NSLocalizedString(@"All Contacts", @"All Contacts"), MENUNAME, nil]
#define UDC [NSUserDefaultsController sharedUserDefaultsController]

@class ESAddressLookupOperation;
@class ESCreateKMLOperation;
@class ESAddressHelper;

@interface Magic : NSObject {
	IBOutlet NSButton * runGeolocationButton;
	IBOutlet NSButton * createKMLButton;
	
	IBOutlet NSWindow * mainWindow;
	IBOutlet NSPanel * warningMessage;
}

@property NSArray * groups;
@property BOOL noGroups;

@property ESAddressLookupOperation * geocodingOperation;
@property (readonly) BOOL geocodingRunning;
@property (readonly) NSString * geocodingButtonLabel;

@property ESCreateKMLOperation * KMLOperation;
@property (readonly) BOOL KMLRunning;
@property (readonly) NSString * KMLWritingButtonLabel;

@property NSMutableDictionary * locations;
@property NSMutableDictionary * failLocations;

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

@property ESAddressHelper * addressHelper;
@property IBOutlet NSArrayController * addressTermsToRemoveController;

@property NSMutableArray * oldLabels;
@property IBOutlet NSArrayController * oldLabelsController;


- (IBAction) convertAddresses:(id)sender;
- (IBAction) createKML:(id)sender;

- (IBAction) addressBookScopeChanged:(id)sender;
- (IBAction) groupListSelectionChanged:(id)sender;

- (IBAction) showWarningInfo:(id)sender;
- (IBAction) dismissSheet:(id)sender;

- (IBAction) toggleGroupByLabel:(id)sender;
- (IBAction) toggleHideOldByDefault:(id)sender;
- (IBAction) createListOfNonLocatableAddresses:(id)sender;
- (IBAction) lookupNonLocatableAddresses:(id)sender;

- (IBAction) readme:(id)sender;

- (void) buildGroupList;

- (NSArray *) relevantPeople;
- (void) updateRelevantPeopleInfo:(NSArray*)people;

- (void) writeCaches;
- (void) beginBusy;
- (void) endBusy;

@end

@interface ABGroup (ESSortExtension)
- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup ;
@end

NSInteger nameSort(id person1, id person2, void *context);
