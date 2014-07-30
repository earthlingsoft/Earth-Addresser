/*
  ESEAAppController.m
  Earth Addresser

  Created by Sven on 21.03.07.
  Copyright 2006-2014 earthlingsoft. All rights reserved.
*/

#import "ESEAAppController.h"
#import "ESAddressLookupOperation.h"
#import "ESCreateKMLOperation.h"
#import "ESTerm.h"
#import "ABRecord+ESSort.h"

@implementation ESEAAppController

- (instancetype) init {
	self = [super init];
	if (self != nil) {
		[self buildGroupList];
		
		[self setupAddressBookChangedNotification];
		[self setupTermContentChangedNotification];
		[self setupOperationProgressNotification];
		[self setupOperationStatusMessageNotification];
		[self setupOperationFinishedNotification];

		self.addressHelper = [[ESAddressHelper alloc] init];
		
		[self readDefaults];
		[self readCaches];
		
		self.operationQueue = [[NSOperationQueue alloc] init];
	}
	return self;
}



- (void) awakeFromNib {
	[self.addressTermsToRemoveController addObserver:self.addressHelper forKeyPath:@"arrangedObjects" options:0 context:nil];
	[self.oldLabelsController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
	[self relevantPeople];
}



- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
	if (![[UDC valueForKeyPath:@"values.hasReadInfo"] boolValue]) {
		[self showWarningInfo:nil];
	}
}



- (void) dealloc {
	if (self.geocodingRunning) {
		[self.geocodingOperation cancel];
	}
	if (self.KMLRunning) {
		[self.KMLOperation cancel];
	}
}



/*
	yup we want to quit on closing the window
*/
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}



- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender {
	NSApplicationTerminateReply result = NSTerminateNow;
	if (self.geocodingRunning || self.KMLRunning) {
		result = NSTerminateLater;
	}
	return result;
}



/*
    don't just close then window while threads are running
*/
- (BOOL)windowShouldClose:(id)sender {
	BOOL result = YES;
	if (self.geocodingRunning || self.KMLRunning) {
		result = NO;
	}
	return result;
}





#pragma mark Address Book

/*
 On Address Book changes, update everything that depends on it.
*/
- (void) setupAddressBookChangedNotification {
	[[NSNotificationCenter defaultCenter] addObserverForName:kABDatabaseChangedExternallyNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * notification) {
		[self buildGroupList];
		[self relevantPeople];
	}];
}



/*
 Rebuilds the Group list from the Address Book and re-sets the selection in case the selected object ceased existing after the rebuild.
*/
- (void) buildGroupList {
	// rebuild the group list
	ABAddressBook * AB = [ABAddressBook sharedAddressBook];
	NSMutableArray * groupsList = [NSMutableArray arrayWithCapacity:self.groups.count +1];

	NSArray * ABGroups = [AB groups];
	ABGroups = [ABGroups sortedArrayUsingSelector:@selector(groupByNameCompare:)];
	
	for (ABGroup * group in ABGroups) {
		[groupsList addObject:@{MENUOBJECT:group.uniqueId, MENUNAME:[group valueForProperty:kABGroupNameProperty]}];
	}
	
	if (groupsList.count > 0) {
		// look whether the selected item still exists. If it doesn't reset to ALL group
		NSString * selectedGroup = (NSString*)[UDC valueForKeyPath:@"values.selectedGroup2"][MENUOBJECT];
		
		if (selectedGroup
				&& ([selectedGroup hasSuffix:@":ABGroup"] || [selectedGroup hasSuffix:@":ABSmartGroup"])
				&&  [AB recordForUniqueId:selectedGroup] ) {
		}
		else {				
			[UDC setValue:groupsList[0] forKeyPath:@"values.selectedGroup2"];
		}
		self.noGroups = @NO;
	}
	else {
		// there are NO groups => deactivate the GUI
		// ... and put 'Select Group' string in the popup menu
		NSString * selectGroupName = NSLocalizedString(@"Select Group", @"");
		NSDictionary * selectGroupDictionary = @{MENUOBJECT:selectGroupName, MENUNAME:selectGroupName};
		[groupsList addObject:selectGroupDictionary];
		[UDC setValue:@0 forKeyPath:@"values.addressBookScope"];
		[UDC setValue:selectGroupDictionary forKeyPath:@"values.selectedGroup2"];
		self.noGroups = @YES;
	}
	
	self.groups = groupsList;
}



/*
 Tells us that the radio button changed
*/
- (IBAction) addressBookScopeChanged:(id)sender {
	[self relevantPeople];	
}



/*
 Switch to group instead of whole address book when a group is selected.
*/
- (IBAction) groupListSelectionChanged:(id)sender {
	[UDC setValue:@1 forKeyPath:@"values.addressBookScope"];
	[self relevantPeople];
}



/*
 returns array with the people selected in the UI
 the array is sorted
*/
- (NSArray *) relevantPeople {
	ABAddressBook * AB = [ABAddressBook sharedAddressBook];
	
	NSArray * people = nil ;
	NSString * selectedGroup = (NSString*)[UDC valueForKeyPath:@"values.selectedGroup2"][MENUOBJECT];
	
	if ([[UDC valueForKeyPath:@"values.addressBookScope"] intValue] == 0) {
		people = [AB people];
	}
	else if ([selectedGroup hasSuffix:@":ABGroup"] || [selectedGroup hasSuffix:@":ABSmartGroup"]) {
		ABGroup * myGroup = (ABGroup*)[AB recordForUniqueId:selectedGroup];
		if (myGroup) {
			people = [myGroup members];
		}
		else {
			// the group doesn't exist anymore => switch to all
			NSLog(@"Previously selected group with ID %@ does not exist anymore. Setting selection to All.", selectedGroup);
			[UDC setValue:@0 forKeyPath:@"values.addressBookScope"];
			people = [AB people];
		}
	}
	else {
		// group ID does not look like a group ID
		NSLog(@"Selected group was not recognisable. Setting selection to All.");
		[UDC setValue:@0 forKeyPath:@"values.addressBookScope"];
		people = [AB people];
	}

	people = [people sortedArrayUsingSelector:@selector(nameCompare:)];

	[self updateRelevantPeopleInfo:people];
	
	return people;
}



/*
 Sets strings and numbers determined by the array of relevant people
*/
- (void) updateRelevantPeopleInfo:(NSArray*)people {
	int addressCount = 0;
	int locatedAddressCount = 0;
	int nonLocatedAddressCount = 0;
	int notYetLocatedAddressCount = 0;
	
	for (ABPerson * myPerson in people) {
		ABMultiValue * addresses = [myPerson valueForProperty:kABAddressProperty];
		NSUInteger totalAddresses = [addresses count];
		for (NSUInteger index = 0; index < totalAddresses; index++) {
			NSDictionary * addressDict = [self.addressHelper normaliseAddress:[addresses valueAtIndex:index]];
			NSString * addressKey = [self.addressHelper keyForAddress:addressDict];
			if (self.locations[addressKey]) {
				// object with coordinates exists => successfully located
				locatedAddressCount++;
			}
			else if (self.failLocations[addressKey]) {
				// looked up but not located
				nonLocatedAddressCount++;
			}
			else {
				// not looked up yet
				notYetLocatedAddressCount++;
			}
			addressCount++;
		}
	}
	
	NSString * contactString;
	if (people.count == 1) {
		contactString = NSLocalizedString(@"contact", @"");
	}
	else {
		contactString = NSLocalizedString(@"contacts", @"");
	}
	
	NSString * addressString;
	if (addressCount == 1) {
		addressString = NSLocalizedString(@"address", @"");
	}
	else {
		addressString = NSLocalizedString(@"addresses", @"");
	}
		
	NSString * firstPart = [NSString stringWithFormat:NSLocalizedString(@"%i %@ with %i %@", @""), people.count, contactString, addressCount, addressString];

	NSString * lookupPart = @"";
	BOOL showNonLocatableAddressesButton = NO;
	if (addressCount != 0) {
		if (notYetLocatedAddressCount != 0) {
			// there are addresses and some still NEED lookup
			if (notYetLocatedAddressCount == 1) {
				lookupPart = [NSString stringWithFormat:NSLocalizedString(@"The selected contacts contain 1 address whose coordinates have not been looked up yet. Use the 'Look Up Addresses' command to do that.", @""), notYetLocatedAddressCount];
			}
			else {
				lookupPart = [NSString stringWithFormat:NSLocalizedString(@"The selected contacts contain %i addresses whose coordinates have not been looked up yet. Use the 'Look Up Addresses' command to do that.", @""), notYetLocatedAddressCount];
			}
		}
		else {
			// there are addresses and all of them have been looked up already
			if (nonLocatedAddressCount != 0) {
				showNonLocatableAddressesButton = YES;
				if (nonLocatedAddressCount > 1) {
					lookupPart = [NSString stringWithFormat:NSLocalizedString(@"All the addresses you selected have been looked up already. Unfortunately %i of them could not be located.", @"Info text in middle section of window - variant used when everything has been looked up already and more than one was addresses not found."), nonLocatedAddressCount];
				}
				else {
					lookupPart = NSLocalizedString(@"All the addresses you selected have been looked up already. Unfortunately one of them could not be located.", @"Info text in middle section of window - variant used when everything has been looked up already and exactly one address was not found.");
				}
			}
			else{
				lookupPart = NSLocalizedString(@"All the addresses you selected have been looked up already.", @"");
			}
		}
	}
	else {
		// no addresses
		lookupPart = NSLocalizedString(@"The contacts you selected do not contain any addresses. Try a different selection for things to be more useful.", @"Shown in middle section when the AddressBook selection contains no addresses");		
	}
			
	NSString * infoString = firstPart; // = [firstPart stringByAppendingString:secondPart];
	self.relevantPeopleInfo = infoString;
	self.lookupInfo = lookupPart;
	self.nonLocatableAddressesButtonHidden = !showNonLocatableAddressesButton;
	self.nonLocatableAddressesExist = (self.failLocations.count > 0);
	self.notSearchedCount = notYetLocatedAddressCount;
	self.addressesAreAvailable = (locatedAddressCount != 0);
	self.KMLStatusMessage = @"";

	if (notYetLocatedAddressCount != 0 ) {
		[createKMLButton setKeyEquivalent:@""];
		[runGeolocationButton setKeyEquivalent:@"\r"];
	}
	else {
		[runGeolocationButton setKeyEquivalent:@""];
		[createKMLButton setKeyEquivalent:@"\r"];
	}
}





#pragma mark Main Actions

/*
 action for looking up addresses
*/
- (IBAction) convertAddresses:(id)sender {
	if (!self.geocodingRunning) {
		[self beginBusy];
		
		NSArray * people;
		if (sender == self) {
			// if message comes from self, look up all remaining addresses...
			people = [[ABAddressBook sharedAddressBook] people];
		}
		else {
			// ... otherwise (messages comes from GUI) only look up for current selection.
			people = [self relevantPeople];
		}
		
		ESAddressLookupOperation * geocodingOperation = [[ESAddressLookupOperation alloc] initWithPeople:people];
		geocodingOperation.addressHelper = self.addressHelper;
		geocodingOperation.locations = self.locations;
		geocodingOperation.failLocations = self.failLocations;
		self.geocodingOperation = geocodingOperation;
		
		[self.operationQueue addOperation:self.geocodingOperation];
	}
	else {
		[self.geocodingOperation cancel];
	}
}



/*
 action for writing KML file
*/
- (IBAction) createKML:(id)sender {
	if (!self.KMLRunning) {
		[self beginBusy];
		
		NSArray * people = [self relevantPeople];
		self.KMLMaximum = people.count;
		ESCreateKMLOperation * KMLOperation = [[ESCreateKMLOperation alloc] initWithPeople:people];
		KMLOperation.locations = self.locations;
		KMLOperation.addressHelper = self.addressHelper;
		KMLOperation.oldLabels = self.oldLabels;
		self.KMLOperation = KMLOperation;

		[self.operationQueue addOperation:self.KMLOperation];
	}
	else {
		[self.KMLOperation cancel];
	}
}



- (void) setupOperationProgressNotification {
	[[NSNotificationCenter defaultCenter] addObserverForName:ESEAOperationProgressNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * notification) {
		double progress = ((NSNumber*)notification.userInfo[ESEAOperationProgressKey]).doubleValue;
		
		if (notification.object == self.geocodingOperation) {
			if (abs(progress - self.geocodingProgress) > 0.9) {
				[self relevantPeople];
			}
			self.geocodingProgress = progress;
		}
		else if (notification.object == self.KMLOperation) {
			self.KMLProgress = progress;
		}
	}];
}



- (void) setupOperationStatusMessageNotification {
	[[NSNotificationCenter defaultCenter] addObserverForName:ESEAOperationStatusMessageNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * notification) {
		NSString * message = notification.userInfo[ESEAOperationMessageKey];
		
		if (notification.object == self.geocodingOperation) {
			self.geocodingStatusMessage = message;
		}
		else if (notification.object == self.KMLOperation) {
			self.KMLStatusMessage = message;
		}
	}];
}



- (void) setupOperationFinishedNotification {
	[[NSNotificationCenter defaultCenter] addObserverForName:ESEAOperationFinishedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * notification) {
		if (notification.object == self.geocodingOperation) {
			[self writeCaches];
			[self endBusy];
			[self relevantPeople];
			self.geocodingProgress = 0;
			self.geocodingOperation = nil;
		}
		else if (notification.object == self.KMLOperation) {
			[self endBusy];
			self.KMLProgress = 0;
			self.KMLMaximum = 0;
			self.KMLOperation = nil;
		}
	}];
}





#pragma mark Actions

/*
 Displays warning sheet about privacy issues
*/
- (IBAction) showWarningInfo:(id)sender {
	[NSApp beginSheet:warningMessage modalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}



/*
 for OK button of warning sheet about privacy issues
*/
- (IBAction) dismissSheet:(id)sender {
	[NSApp endSheet:warningMessage];
	[warningMessage orderOut:self];
}



/*
 toggles groupByAddressLabel user default
*/
- (IBAction) toggleGroupByLabel:(id)sender {
}



/*
 toggles hideOldByDefault user default
*/
- (IBAction) toggleHideOldByDefault:(id)sender {
}



/*
	1. clears all FAIL marks for locations
	2. initiates a look-up for addresses
*/
- (IBAction) lookupNonLocatableAddresses:(id)sender {
	[self.failLocations removeAllObjects];
	[self updateRelevantPeopleInfo:[[ABAddressBook sharedAddressBook] people]];
	[self convertAddresses:self];
}





#pragma mark Non-Locatable Addresses

- (IBAction) createListOfNonLocatableAddresses:(id)sender {
	NSMutableString * nonLocatableAddressesString = [NSMutableString string];
	NSArray * people;
	if ([sender isKindOfClass:[NSButton class]]) {
		// the button in the window was user => only use non-found addresses in the current selection
		people = [self relevantPeople];
	}
	else {
		// the menu item was used => use _all_ non-found addresses
		people = [[ABAddressBook sharedAddressBook] people];		
	}
	
	for (ABPerson * myPerson in people) {
		ABMultiValue * addresses = [myPerson valueForProperty:kABAddressProperty];
		NSUInteger totalAddresses = [addresses count];
		for (NSUInteger index = 0; index < totalAddresses; index++) {
			NSDictionary * addressDict = [self.addressHelper normaliseAddress:[addresses valueAtIndex:index]];
			NSString * addressKey = [self.addressHelper keyForAddress:addressDict];
			NSObject * addressObject = self.failLocations[addressKey];
			if (addressObject != nil) {
				[nonLocatableAddressesString appendFormat:@"%@\n***\n", addressKey];
			}
		}
	}
	
	NSString * savePath = [NSString stringWithFormat:@"/tmp/Earth Addresser Non Locatable Addresses %@.text", [NSUUID UUID].UUIDString];
	NSURL * saveURL = [NSURL fileURLWithPath:savePath];
	NSError * myError = nil;
	if ([nonLocatableAddressesString writeToURL:saveURL atomically:NO encoding:NSUTF8StringEncoding error:&myError]) {
		[[NSWorkspace sharedWorkspace] openURL:saveURL];
	}
	else {
		NSAlert * alert = [NSAlert alertWithError:myError];
		[alert performSelectorOnMainThread:@selector(runModal) withObject:nil waitUntilDone:YES];
	}
	
}





#pragma mark KVO / KVC

+ (NSSet *) keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSArray * newKeyPaths;
	if ([key isEqualToString:NSStringFromSelector(@selector(needToSearchNoticeHidden))]) {
		newKeyPaths = @[NSStringFromSelector(@selector(KMLRunning)),
						NSStringFromSelector(@selector(notSearchedCount))];
	}
	else if ([key isEqualToString:NSStringFromSelector(@selector(nothingToSearch))]) {
		newKeyPaths = @[NSStringFromSelector(@selector(notSearchedCount))];
	}
	else if ([key isEqualToString:NSStringFromSelector(@selector(geocodingRunning))]) {
		newKeyPaths = @[NSStringFromSelector(@selector(geocodingOperation)),
						@"geocodingOperation.finished"];
	}
	else if ([key isEqualToString:NSStringFromSelector(@selector(KMLRunning))]) {
		newKeyPaths = @[NSStringFromSelector(@selector(KMLOperation)),
						@"KMLOperation.finished"];
	}
	else if ([key isEqualToString:NSStringFromSelector(@selector(geocodingButtonLabel))]) {
		newKeyPaths = @[NSStringFromSelector(@selector(geocodingRunning))];
	}
	else if ([key isEqualToString:NSStringFromSelector(@selector(KMLWritingButtonLabel))]) {
		newKeyPaths = @[NSStringFromSelector(@selector(KMLRunning))];
	}
	
	NSSet * keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	return [keyPaths setByAddingObjectsFromArray:newKeyPaths];
}



- (void) observeValueForKeyPath:(NSString *)keyPath
					   ofObject:(id)object
						 change:(NSDictionary *)change
					    context:(void *)context {
	if (object == self.oldLabelsController && [keyPath isEqualToString:@"arrangedObjects"]) {
		[self updateDefaults:nil];
	}
}



- (BOOL) needToSearchNoticeHidden {
	BOOL hidden = self.KMLRunning || (self.notSearchedCount == 0);
	return hidden;
}



- (BOOL) nothingToSearch {
	BOOL nothingToSearch = (self.notSearchedCount == 0);
	return nothingToSearch;
}



- (BOOL) geocodingRunning {
	return (self.geocodingOperation != nil) && !self.geocodingOperation.finished;
}



- (BOOL) KMLRunning {
	return (self.KMLOperation != nil) && !self.KMLOperation.finished;
}



- (NSString *) geocodingButtonLabel {
	NSString * label;
	if (self.geocodingRunning) {
		label = NSLocalizedString(@"Cancel Lookup", @"Title of geocoding button while geocoding is running and can be cancelled.");
	}
	else {
		label = NSLocalizedString(@"Look up coordinates", @"Standard Title of geocoding button while geocoding is not running.");
	}
	return label;
}



- (NSString *) KMLWritingButtonLabel {
	NSString * label;
	if (self.KMLRunning) {
		label = NSLocalizedString(@"Cancel Placemark Creation", @"Text displayed in KML Creation button while KML Creation is running.");
	}
	else {
		label = NSLocalizedString(@"Create Placemarks", @"Text displayed in KML Creation button when KML Creation is not running.");
	}
	return label;
	
}



- (NSImage *) AddressBookIcon {
	return [self iconForAppBundleIdentifier:@"com.apple.addressbook"];
}



- (NSImage *) MapsIcon {
	NSImage * image = [self iconForAppBundleIdentifier:@"com.apple.Maps"];
	if (!image) {
		// No Maps application: use Google Earth icon. (For X.8)
		image = [self iconForAppBundleIdentifier:@"com.Google.GoogleEarthPlus"];
	}
	return image;
}



- (NSImage *) iconForAppBundleIdentifier:(NSString *) bundleIdentifier {
	NSImage * image = nil;
	NSString * appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:bundleIdentifier];
	if (appPath) {
		image = [[NSWorkspace sharedWorkspace] iconForFile:appPath];
	}
	return image;
}



- (NSImage *) KMLIcon {
	return [[NSWorkspace sharedWorkspace] iconForFileType:@"kml"];
}





#pragma mark User Defaults

- (void) readDefaults {
	self.oldLabels = [NSMutableArray array];
	NSArray * labels = [UDC valueForKeyPath:@"values.oldLabels"];
	for (NSDictionary * labelDict in labels) {
		ESTerm * labelTerm = [[ESTerm alloc] initWithDictionary:labelDict];
		[self.oldLabels addObject:labelTerm];
	}
}



- (void) setupTermContentChangedNotification {
	[[NSNotificationCenter defaultCenter] addObserverForName:ESTermContentChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * notification) {
		[self updateDefaults:notification];
	}];
}



- (void) updateDefaults:(NSNotification *)notification {
	[self.addressHelper updateDefaults];
	
	NSMutableArray * labels = [NSMutableArray array];
	for (ESTerm * term in self.oldLabels) {
		NSDictionary * dict = term.dictionary;
		[labels addObject:dict];
	}
	[UDC setValue:labels forKeyPath:@"values.oldLabels"];
	
	[self relevantPeople];
}





#pragma mark Caches

NSString * const successFileName = @"Successful Lookups.plist";
NSString * const failFileName = @"Failed Lookups.plist";


- (void) readCaches {
	self.locations = [self mutableDictionaryFromApplicationSupportFileName:successFileName];
	if (!self.locations) {
		self.locations = [[NSMutableDictionary alloc] init];
	}
	
	self.failLocations = [self mutableDictionaryFromApplicationSupportFileName:failFileName];
	if (!self.failLocations) {
		self.failLocations = [[NSMutableDictionary alloc] init];
	}
}



- (void) writeCaches {
	[self writeDictionary:self.locations toApplicationSupportFileName:successFileName];
	[self writeDictionary:self.failLocations toApplicationSupportFileName:failFileName];
}



- (NSMutableDictionary *) mutableDictionaryFromApplicationSupportFileName:(NSString *)fileName {
	NSURL * fileURL = [[[self class] EAApplicationSupportURL] URLByAppendingPathComponent:fileName];
	NSMutableDictionary * dictionary = [NSMutableDictionary dictionaryWithContentsOfURL:fileURL];
	return dictionary;
}



- (BOOL) writeDictionary:(NSDictionary *)dictionary toApplicationSupportFileName:(NSString *)fileName {
	BOOL success = NO;
	NSError * error;
	
	if([[NSFileManager defaultManager] createDirectoryAtURL:[[self class] EAApplicationSupportURL] withIntermediateDirectories:YES attributes:nil error:&error]) {
		if ([[self class] EAApplicationSupportURL]) {
			NSURL * fileURL = [[[self class] EAApplicationSupportURL] URLByAppendingPathComponent:fileName];
			success = [dictionary writeToURL:fileURL atomically:YES];
			if (!success) {
				NSLog(@"Could not write file ”%@“", fileURL.path);
			}
		}
	}
	else {
		NSLog(@"Error when trying to write file “%@”: Could not create folder at “%@”", fileName, [[self class] EAApplicationSupportURL].path);
		if (error) {
			NSLog(@"%@", error.localizedDescription);
		}
	}
	
	return success;
}





#pragma mark Utility Methods

NSString * const applicationSupportFolderName = @"EarthAddresser";

+ (NSURL *) EAApplicationSupportURL {
	NSError * error;
	NSURL * applicationSupportURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
	NSURL * myApplicationSupportURL;
	
	if (applicationSupportURL) {
		myApplicationSupportURL = [applicationSupportURL URLByAppendingPathComponent:applicationSupportFolderName isDirectory:YES];
	}
	else {
		NSLog(@"Could not find/create Application Support folder");
		if (error) {
			NSLog(@"%@", error.localizedDescription);
		}
	}
	
	return myApplicationSupportURL;
}



/*
 for the various actions in the help menu
*/
- (IBAction) readme:(id)sender {
	NSWorkspace * WORKSPACE = [NSWorkspace sharedWorkspace];

	NSInteger tag = [sender tag];
	switch (tag) {
		case 1: // earthlingsoft
			[WORKSPACE openURL:[NSURL URLWithString:@"http://earthlingsoft.net/"]];
			break;
		case 2: // Website
			[WORKSPACE openURL:[NSURL URLWithString:@"http://earthlingsoft.net/Earth%20Addresser"]];
			break;
		case 3: // Send Mail
			[WORKSPACE openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:earthlingsoft%%40earthlingsoft.net?subject=Earth%%20Addresser%%20%@", self.myVersionString]]];
			break;
		case 4: // Paypal
			[WORKSPACE openURL:[NSURL URLWithString:[@"https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=earthlingsoft%40earthlingsoft.net&item_name=Earth%20Addresser&no_shipping=1&cn=Comments&tax=0&currency_code=EUR&lc=" stringByAppendingString:NSLocalizedString(@"PayPal Region Code", @"PayPal Region Code - used in PayPal URL")]]];
			break;
		case 5: // Readme
			[WORKSPACE openFile:[[NSBundle mainBundle] pathForResource:@"readme" ofType:@"html"]];
			break;
	}
}



/*
 returns version string
*/
- (NSString*) myVersionString {
	return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}



/*
 we start being busy: disable sudden termination
*/
- (void) beginBusy {
	[[NSProcessInfo processInfo] disableSuddenTermination];
	[[mainWindow standardWindowButton:NSWindowCloseButton] setEnabled:NO];
}



/*
 we are finished being busy: re-enable sudden termination, quit if so desired
*/
- (void) endBusy {
	[NSApp replyToApplicationShouldTerminate:YES];
	[[mainWindow standardWindowButton:NSWindowCloseButton] setEnabled:YES];
	[[NSProcessInfo processInfo] enableSuddenTermination];
}

@end
