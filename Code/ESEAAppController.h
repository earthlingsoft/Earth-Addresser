/*
  ESEAAppController.h
  Earth Addresser

  Created by Sven on 22.03.2007
  Copyright 2006-2016 earthlingsoft. All rights reserved.
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


@interface ESEAAppController : NSObject {
	IBOutlet NSButton * runGeolocationButton;
	IBOutlet NSButton * createKMLButton;
	
	IBOutlet NSWindow * mainWindow;
	IBOutlet NSPanel * warningMessage;
}

@property NSArray * groups;

@property NSOperationQueue * operationQueue;

@property ESAddressLookupOperation * geocodingOperation;
@property (readonly) BOOL geocodingRunning;
@property double geocodingProgress;
@property double geocodingMaximum;
@property (readonly) NSString * geocodingButtonLabel;
@property NSString * geocodingStatusMessage;

@property ESCreateKMLOperation * KMLOperation;
@property (readonly) BOOL KMLRunning;
@property double KMLProgress;
@property double KMLMaximum;
@property (readonly) NSString * KMLWritingButtonLabel;
@property NSString * KMLStatusMessage;

@property NSMutableDictionary * locations;
@property NSMutableDictionary * failLocations;

@property NSInteger notSearchedCount;
@property BOOL nonLocatableAddressesExist;
@property BOOL nonLocatableAddressesButtonHidden;

@property NSString * relevantPeopleInfo;
@property NSString * lookupInfo;

@property NSInteger addressesAreAvailable;
@property (readonly) BOOL needToSearchNoticeHidden;
@property (readonly) BOOL nothingToSearch;
@property (readonly) BOOL hasGroups;

@property (readonly) NSImage * AddressBookIcon;
@property (readonly) NSImage * MapsIcon;
@property (readonly) NSImage * KMLIcon;

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

+ (NSURL *) EAApplicationSupportURL;

@end
