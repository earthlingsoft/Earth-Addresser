/*
  Magic.m
  Earth Addresser / Mailboxer

  Created by Sven on 21.03.07.
  Copyright 2006-2014 earthlingsoft. All rights reserved.
*/

#import "Magic.h"
#import <AddressBook/ABAddressBookC.h>
#import <CoreLocation/CoreLocation.h>
#import "ESTerm.h"

@implementation Magic

- (instancetype) init {
	self = [super init];
	if (self != nil) {
		[self buildGroupList];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(addressBookChanged:)
													 name:kABDatabaseChangedExternallyNotification
												   object:NULL];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(updateDefaults:)
													 name:ESTermContentChangedNotification
												   object:NULL];

		[self readDefaults];
		[self readCaches];
	}
	return self;
}


- (void)awakeFromNib {
	[self.addressTermsToRemoveController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
	[self.oldLabelsController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
	[self relevantPeople];
}


- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
	if ( ![[UDC valueForKeyPath:@"values.hasReadInfo"] boolValue] ) {
		[self showWarningInfo:nil];
	}
}


+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *)key {
	NSSet * keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"needToSearchNoticeHidden"]) {
		NSSet * affectingKeys = [NSSet setWithObjects:@"KMLRunning", @"notSearchedCount",nil];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	}
	else if ([key isEqualToString:@"nothingToSearch"]) {
		NSSet * affectingKeys = [NSSet setWithObjects:@"notSearchedCount", nil];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	}
	else if ([key isEqualToString:@"geocodingButtonLabel"]) {
		NSSet * affectingKeys = [NSSet setWithObjects:@"geocodingRunning", nil];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	}
	else if ([key isEqualToString:@"KMLWritingButtonLabel"]) {
		NSSet * affectingKeys = [NSSet setWithObjects:@"KMLRunning", nil];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	}

	return keyPaths;
}


+ (void)initialize {
	NSDictionary * standardDefaults = @{
		@"dontShowWarning": @NO,
		@"imageSize": @1.5,
		@"addressBookScope": @0,
		@"placemarkWithName": @YES,
		@"placemarkWithLabel": @YES,
		@"placemarkNameReplacement": @"\342\235\200",
		@"placemarkWithAddress": @YES,
		@"placemarkWithImage": @YES,
		@"placemarkWithEMail": @NO,
		@"placemarkWithPhone": @NO,
		@"placemarkWithWeblinks": @YES,
		@"placemarkWithAddressBookLink": @YES,
		@"placemarkWithContacts": @NO,
		@"placemarkWithNotes": @NO,
		@"noHomeWorkIcons": @NO,
		@"hasReadInfo": @NO,
		@"groupByAddressLabel": @NO,
		@"addressTermsToRemove": @[
			@{ESTermStringKey:@"c/o ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Geb. ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@" Dept", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Dept ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Dept.", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Department ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@" Department", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Zi. ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Zimmer ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Room ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Raum ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"University of", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Universität ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Flat ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"App ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"App.", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Apt ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Apt.", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"#", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"P.O. Box", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"P.O.Box", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Postfach ", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Büro", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Office", ESTermActiveKey:@YES}
		],
		@"oldLabels": @[
			@{ESTermStringKey:@"Old", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Alt", ESTermActiveKey:@YES},
			@{ESTermStringKey:@"Ancienne", ESTermActiveKey:@YES},
		]
	};
	
	[UDC setInitialValues:standardDefaults];
	[UDC setAppliesImmediately:YES];
}


- (void) dealloc {
	if (self.geocodingRunning && geocodingThread) {
		[geocodingThread cancel];
	}
	if (self.KMLRunning && KMLThread) {
		[KMLThread cancel];
	}
}



/*
	yup we want to quit on closing the window
*/
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}




- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	NSApplicationTerminateReply result = NSTerminateNow;
	
	if (self.KMLRunning || self.geocodingRunning) {
		result = NSTerminateLater;
	}
	
	return result;
}





/*
    don't just close then window while threads are running
*/
- (BOOL)windowShouldClose:(id)sender {
	BOOL result = YES;
	if (self.KMLRunning || self.geocodingRunning) {
		result = NO;
	}
	return result;
}



#pragma mark User Defaults

- (void) readDefaults {
	self.addressTermsToRemove = [NSMutableArray array];
	NSArray * parts = [UDC valueForKeyPath:@"values.addressTermsToRemove"];
	for (NSDictionary * partDict in parts) {
		ESTerm * partTerm = [[ESTerm alloc] initWithDictionary:partDict];
		[self.addressTermsToRemove addObject:partTerm];
	}
	
	self.oldLabels = [NSMutableArray array];
	NSArray * labels = [UDC valueForKeyPath:@"values.oldLabels"];
	for (NSDictionary * labelDict in labels) {
		ESTerm * labelTerm = [[ESTerm alloc] initWithDictionary:labelDict];
		[self.oldLabels addObject:labelTerm];
	}
}


- (void) updateDefaults:(NSNotification *) notification {
	NSMutableArray * terms = [NSMutableArray array];
	for (ESTerm * term in self.addressTermsToRemove) {
		NSDictionary * dict = term.dictionary;
		[terms addObject:dict];
	}
	[UDC setValue:terms forKeyPath:@"values.addressTermsToRemove"];
	
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
	locations = [self mutableDictionaryFromApplicationSupportFileName:successFileName];
	if (!locations) {
		locations = [[NSMutableDictionary alloc] init];
	}
	
	failLocations = [self mutableDictionaryFromApplicationSupportFileName:failFileName];
	if (!failLocations) {
		failLocations = [[NSMutableDictionary alloc] init];
	}
}


- (void) writeCaches {
	[self writeDictionary:locations toApplicationSupportFileName:successFileName];
	[self writeDictionary:failLocations toApplicationSupportFileName:failFileName];
}


- (NSMutableDictionary *) mutableDictionaryFromApplicationSupportFileName:(NSString *)fileName {
	NSURL * fileURL = [self.EAApplicationSupportURL URLByAppendingPathComponent:fileName];
	NSMutableDictionary * dictionary = [NSMutableDictionary dictionaryWithContentsOfURL:fileURL];
	return dictionary;
}


- (BOOL) writeDictionary:(NSDictionary *)dictionary toApplicationSupportFileName:(NSString *)fileName {
	BOOL success = NO;
	NSError * error;
	
	if([[NSFileManager defaultManager] createDirectoryAtURL:self.EAApplicationSupportURL withIntermediateDirectories:YES attributes:nil error:&error]) {
		if (self.EAApplicationSupportURL) {
			NSURL * fileURL = [self.EAApplicationSupportURL URLByAppendingPathComponent:fileName];
			success = [dictionary writeToURL:fileURL atomically:YES];
			if (!success) {
				NSLog(@"Could not write file ”%@“", [fileURL path]);
			}
		}
	}
	else {
		NSLog(@"Error when trying to write file “%@”: Could not create folder at “%@”", fileName, [self.EAApplicationSupportURL path]);
		if (error) {
			NSLog(@"%@", [error localizedDescription]);
		}
	}
	
	return success;
}



#pragma mark Address Book

/*
	when Address Book changes, update everything that depends on it
*/
- (void) addressBookChanged: (NSNotification *)notification {
	[self buildGroupList];
	[self relevantPeople];
}



/*
	Rebuilds the Group list from the Address Book and re-sets the selection in case the selected object ceased existing after the rebuild.
*/
- (void) buildGroupList {
	// rebuild the group list
	ABAddressBook * ab = [ABAddressBook sharedAddressBook];
	NSMutableArray * a = [NSMutableArray arrayWithCapacity:[groups count] +1 ];

	NSArray * ABGroups = [ab groups];
	ABGroups = [ABGroups sortedArrayUsingSelector:@selector(groupByNameCompare:)];
	
	NSEnumerator * myEnum = [ABGroups objectEnumerator];
	ABGroup * group;
	while (group = [myEnum nextObject]) {
		[a addObject:@{MENUOBJECT: [group uniqueId], MENUNAME: [group valueForProperty:kABGroupNameProperty]}];
	}
	[self setValue:a forKey:@"groups"];
	
	
	if ([a count] > 0 ) {
		// look whether the selected item still exists. If it doesn't reset to ALL group
		NSString * selectedGroup = (NSString*) [UDC valueForKeyPath:@"values.selectedGroup2"][MENUOBJECT];
		
		if (selectedGroup
				&& ([selectedGroup hasSuffix:@":ABGroup"] || [selectedGroup hasSuffix:@":ABSmartGroup"])
				&&  [ab recordForUniqueId:selectedGroup] ) {
		}
		else {				
			group = groups[0];
			[UDC setValue:group forKeyPath:@"values.selectedGroup2"];
		}

		[self setValue:@NO forKey:@"noGroups"];
	}
	else {
		// there are NO groups => deactivate the GUI
		NSString * selectGroupName = NSLocalizedString(@"Select Group", @"");
		NSDictionary * selectGroupDictionary = @{MENUOBJECT: selectGroupName, MENUNAME: selectGroupName};
		[a addObject: selectGroupDictionary];
		[UDC setValue:@0 forKeyPath:@"values.addressBookScope"];
		[UDC setValue:selectGroupDictionary forKeyPath:@"values.selectedGroup2"];
		[self setValue:@YES forKey:@"noGroups"];
		// ... and put 'Select Group' string in the popup menu
	}

}



/*
	Tells us that the radio button changed
*/
- (IBAction) addressBookScopeChanged: (id) sender {
	[self relevantPeople];	
}



/*
	Switch to group instead of whole address book when a group is selected.
*/
- (IBAction) groupListSelectionChanged: (id) sender {
	[UDC setValue:@1 forKeyPath:@"values.addressBookScope"];
	[self relevantPeople];
}



/*
 returns array with the people selected in the UI
 the array is sorted
*/
- (NSArray*) relevantPeople {
	ABAddressBook * ab = [ABAddressBook sharedAddressBook];
	
	NSArray * people = nil ;
	NSString * selectedGroup = (NSString*) [UDC valueForKeyPath:@"values.selectedGroup2"][MENUOBJECT];
	if ([[UDC valueForKeyPath:@"values.addressBookScope"] intValue] == 0) {
		people = [ab people];
	}
	else if ([selectedGroup hasSuffix:@":ABGroup"] || [selectedGroup hasSuffix:@":ABSmartGroup"]) {
		ABGroup * myGroup = (ABGroup*) [ab recordForUniqueId:selectedGroup];
		if (myGroup) {
			people = [myGroup members];
		}
		else {
			// the group doesn't exist anymore => switch to all
			NSLog(@"Previously selected group with ID %@ does not exist anymore. Setting selection to All.", selectedGroup);
			[UDC setValue:@0 forKeyPath:@"values.addressBookScope"];
			people = [ab people];
		}
	}
	else {
		// group ID does not look like a group ID
		NSLog(@"Selected group was not recognisable. Setting selection to All.");
		[UDC setValue:@0 forKeyPath:@"values.addressBookScope"];
		people = [ab people];
	}

	NSNumber * sortByFirstName = @NO;
	people =  [people sortedArrayUsingFunction:nameSort context:(__bridge void *)(sortByFirstName)];

	[self updateRelevantPeopleInfo:people];
	
	return people;
}



/*
	Sets strings and numbers determined by the array of relevant people
*/
- (void) updateRelevantPeopleInfo: (NSArray*) people {
	int addressCount = 0;
	int locatedAddressCount = 0;
	int nonLocatedAddressCount = 0;
	int notYetLocatedAddressCount = 0;
	
	NSEnumerator * myEnum = [people objectEnumerator];
	ABPerson * myPerson;
	while (myPerson = [myEnum nextObject]) {
		ABMultiValue * addresses = [myPerson valueForProperty:kABAddressProperty];
		NSUInteger totalAddresses = [addresses count];
		NSUInteger index = 0;
		
		while (totalAddresses > index) {
			NSDictionary * addressDict = [addresses valueAtIndex:index];
			NSString * addressKey = [self dictionaryKeyForAddressDictionary:addressDict];
			if (locations[addressKey]) {
				// object with coordinates exists => successfully located
				locatedAddressCount++;
			}
			else if (failLocations[addressKey]) {
				// looked up but not located
				nonLocatedAddressCount++;
			}
			else {
				// not looked up yet
				notYetLocatedAddressCount++;
			}
			addressCount++;
			index++;
		}
	}
	
	NSString * contactString;
	if ([people count] == 1) {
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
		
	NSString * firstPart = [NSString stringWithFormat:NSLocalizedString(@"%i %@ with %i %@", @""), [people count], contactString, addressCount, addressString];

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
	self.nonLocatableAddressesExist = ([failLocations count] > 0);
	self.notSearchedCount = notYetLocatedAddressCount;
	self.addressesAreAvailable = (locatedAddressCount != 0);
	self.doneMessage = @"";

	if (notYetLocatedAddressCount != 0 ) {
		[createKMLButton setKeyEquivalent:@""];
		[runGeolocationButton setKeyEquivalent:@"\r"];
	}
	else {
		[runGeolocationButton setKeyEquivalent:@""];
		[createKMLButton setKeyEquivalent:@"\r"];
	}
}





#pragma mark Extract address information for dictionary keys

- (NSString *) dictionaryKeyForAddressDictionary:(NSDictionary *)address {
	return [[self componentsFromAddressDictionary:address] componentsJoinedByString:@", "];
}


- (NSArray *) componentsFromAddressDictionary:(NSDictionary *)address {
	NSMutableArray * addressComponents = [NSMutableArray arrayWithCapacity:5];
	
	NSString * addressComponent;
	if ((addressComponent = [address valueForKey:kABAddressStreetKey])) {
		NSString * cleanedComponent = [self cleanAddress:addressComponent];
		if (cleanedComponent.length > 0) {
			[self addString:cleanedComponent toArray:addressComponents];
		}
	}

	[self addComponent:kABAddressCityKey ofAddress:address toArray:addressComponents];
	[self addComponent:kABAddressZIPKey ofAddress:address toArray:addressComponents];
	[self addComponent:kABAddressStateKey ofAddress:address toArray:addressComponents];
	[self addComponent:kABAddressCountryCodeKey ofAddress:address toArray:addressComponents];

	return addressComponents;
}


- (void) addComponent:(NSString *)componentKey ofAddress:(NSDictionary *)address toArray:(NSMutableArray *)array {
	NSString * addressComponent = [address valueForKey:componentKey];
	
	if (addressComponent) {
		[self addString:addressComponent toArray:array];
	}
}


- (void) addString:(NSString *)string toArray:(NSMutableArray *)array {
	NSString * cleanedString = [[string
								stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
								stringByReplacingOccurrencesOfString:@"\n" withString:@", "];
	
	if ([cleanedString length] > 0) {
		[array addObject:cleanedString];
	}
}


#pragma mark Address Lookup


/*
 action for looking up addresses
*/
- (IBAction) convertAddresses: (id) sender {
	if (!self.geocodingRunning) {
		[self beginBusy];
		self.geocodingProgress = 0;
		self.geocodingRunning = @YES;
		[NSThread detachNewThreadSelector:@selector(convertAddresses2:) toTarget:self withObject:sender];
	}
	else if (self.geocodingRunning) {
		[geocodingThread cancel];
	}
}



/*
 method looking up addresses
 to be run in separate thread
*/
- (void) convertAddresses2: (id) sender {
	@autoreleasepool {
		geocodingThread = [NSThread currentThread];
		double geocodingCurrentPosition = .000001;

		NSArray * people;
		if (sender == self) {
			// if message comes from self, look up all remaining addresses...
			people = [[ABAddressBook sharedAddressBook] people];
		}
		else {
			// ... otherwise (messages comes from GUI) only look up for current selection.
			people = [self relevantPeople];
		}
		NSEnumerator * myEnum = [people objectEnumerator];
		ABPerson * myPerson;
		NSTimeInterval previousLookup = 0;
		BOOL error = NO;
		
		self.geocodingMaximum = self.notSearchedCount;
		
		while ((myPerson = [myEnum nextObject]) && !error && ![[NSThread currentThread] isCancelled]) {
			@autoreleasepool {
				ABMultiValue * addresses = [myPerson valueForProperty:kABAddressProperty];
				NSUInteger addressCount = [addresses count];
				NSUInteger index = 0;

				while (addressCount > index && !error) {
					NSDictionary * addressDict = [addresses valueAtIndex:index];
					NSString * addressString = [self dictionaryKeyForAddressDictionary:addressDict];
					
					if (!locations[addressString] && !failLocations[addressString]) {
						// Look up address if we don't know its coordinates already

						self.currentLookupAddress = addressString;
						self.geocodingProgress = geocodingCurrentPosition;
						geocodingCurrentPosition += 1.;
						
						// throttle queries
						if (previousLookup != 0) {
							NSDate * wakeUpTime = [NSDate dateWithTimeIntervalSinceReferenceDate:previousLookup + SECONDSBETWEENCOORDINATELOOKUPS];
							[NSThread sleepUntilDate:wakeUpTime];
						}
						previousLookup = [NSDate timeIntervalSinceReferenceDate];
						
						[[[CLGeocoder alloc] init] geocodeAddressDictionary:addressDict
														  completionHandler:^(NSArray * placemarks, NSError * lookupError) {
							if ([placemarks count] == 1) {
								CLPlacemark * placemark = placemarks[0];
								CLLocation * location = placemark.location;
								locations[addressString] = @{
									@"lat": @(location.coordinate.latitude),
									@"lon": @(location.coordinate.longitude),
									@"accuracy": @(location.horizontalAccuracy),
									@"timestamp": @(location.timestamp.timeIntervalSince1970),
									@"resultType": @"unique"
								};
							}
							else if ([placemarks count] > 1) {
								NSLog(@"Found %lu locations for address: %@", [placemarks count], addressString);
								NSMutableArray * locationStrings = [NSMutableArray array];
								[placemarks enumerateObjectsUsingBlock:^(CLPlacemark * placemark, NSUInteger idx, BOOL * stop) {
									[locationStrings addObject:[placemark.location description]];
								}];
								NSDictionary * failInfo = @{
									@"type": @"multiple",
									@"locations": locationStrings
								};
								failLocations[addressString] = failInfo;
							}
							else {
								if (lookupError) {
									NSLog(@"Could not locate address: %@", addressString);
									NSLog(@"error: %@", lookupError);
									NSDictionary * errorInfo = @{
										@"type": @"error",
										@"domain": [lookupError domain],
										@"code": [NSNumber numberWithInt:[lookupError code]],
										@"userInfo": [lookupError userInfo]
									};
									failLocations[addressString] = errorInfo;
								}
							}
						}];
						[self relevantPeople];
					}
					index++;
				}
			} // @autoreleasepool (inner)
		}

		self.currentLookupAddress = @"";
		self.geocodingRunning = @NO;
		geocodingThread = nil;
		
		[geocodingProgressBar setHidden:YES];

		[self writeCaches];
		[self endBusy];
	} // @autoreleasepool (for thread)
}



#pragma mark XML Helper Methods

NSString * const applicationSupportFolderName = @"EarthAddresser";

- (NSURL *) EAApplicationSupportURL {
	NSError * error;
	NSURL * applicationSupportURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
	NSURL * myApplicationSupportURL;
	
	if (applicationSupportURL) {
		myApplicationSupportURL = [applicationSupportURL URLByAppendingPathComponent:applicationSupportFolderName isDirectory:YES];
	}
	else {
		NSLog(@"Could not find/create Application Support folder");
		if (error) {
			NSLog(@"%@", [error localizedDescription]);
		}
	}
	
	return myApplicationSupportURL;
}



/*
 Returns absolute path to our Images folder in Application Support
*/
- (NSString *) imagesFolderPath {
	NSFileManager * myFM = [NSFileManager defaultManager];
	NSString * imagesFolderPath = [self.EAApplicationSupportURL URLByAppendingPathComponent:@"Images"].path;
	if (![myFM fileExistsAtPath:imagesFolderPath]) { // create folders if needed
		NSError * error;
		if (![myFM createDirectoryAtPath:imagesFolderPath withIntermediateDirectories:YES attributes:nil error:&error]) {
			[[NSThread currentThread] cancel];
			NSAlert * alert = [NSAlert alertWithError:error];
			[alert performSelectorOnMainThread:@selector(runModal) withObject:nil waitUntilDone:YES];
			imagesFolderPath = nil;
		}
	}
	
	return imagesFolderPath;
}



/*
 Returns full path to PNG image in Application Support with the name passed to it.
 (collaterally ensures that the folder hierarchy on the way there exists)
*/
- (NSString *) fullPNGImagePathForName: (NSString *) name {
	NSString * fullImagePath = nil;
	NSString * imagesFolderPath = [self imagesFolderPath];
	if (imagesFolderPath != nil) {
		fullImagePath = [imagesFolderPath stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
	}
	return fullImagePath;
}



/*
 Writes the given image to Application Support and creates the corresponding style XML.
 Returns nil iff any of that fails.
*/
- (NSXMLElement *) createStyleForImageData: (NSData *) imageData withID:(NSString *) ID {
	NSXMLElement * styleElement = nil;
	
	// only execute if we haven’t been cancelled (mainly to avoid duplicate error messages)
	if (![[NSThread currentThread] isCancelled]) {
		// ensure folders to our image exist
		NSString * fullImagePath = [self fullPNGImagePathForName: ID];
		if (fullImagePath != nil && imageData != nil) {
			// ensure we actually have an image to write
			NSBitmapImageRep * imageRep = [NSBitmapImageRep imageRepWithData:imageData];
			if (imageRep != nil) {
				// create PNG data and write it
				NSData * PNGData = [imageRep representationUsingType:NSPNGFileType properties:nil];
				BOOL PNGWriteSuccess = [PNGData writeToFile:fullImagePath atomically:YES];
				if (PNGWriteSuccess) {
					// now that we have written the image, create the style for it
					styleElement = [NSXMLElement elementWithName:@"Style"];
					[styleElement addAttribute:[NSXMLNode attributeWithName:@"id" stringValue:ID]];
					
					NSXMLElement * iconStyleElement = [NSXMLElement elementWithName:@"IconStyle"];	
					NSXMLElement * iconElement = [NSXMLElement elementWithName:@"Icon"];
					NSXMLElement * hrefElement = [NSXMLNode elementWithName:@"href" stringValue:fullImagePath];
					[iconElement addChild: hrefElement];
					[iconStyleElement addChild:iconElement];
					
					NSXMLElement * sizeElement = [NSXMLNode elementWithName:@"scale" stringValue: [[UDC valueForKeyPath:@"values.imageSize"] stringValue]];
					[iconStyleElement addChild:sizeElement];
					NSXMLElement * hotSpotElement = [NSXMLNode elementWithName:@"hotSpot"];
					[hotSpotElement addAttribute:[NSXMLNode attributeWithName:@"x" stringValue:@"0.5"]];
					[hotSpotElement addAttribute:[NSXMLNode attributeWithName:@"y" stringValue:@"0"]];
					[hotSpotElement addAttribute:[NSXMLNode attributeWithName:@"xunits" stringValue:@"fraction"]];
					[hotSpotElement addAttribute:[NSXMLNode attributeWithName:@"yunits" stringValue:@"fraction"]];
					[iconStyleElement addChild:hotSpotElement];
					[styleElement addChild:iconStyleElement];
				} // endif image written successfully
			} // endif imageRep != nil
		} // endif fullImagePath != nil
	} // endif ![currentThread isCancelled]
	
	return styleElement;
}



/*
 Creates generic style element for the given name
	Requires: PNG image for the name in Resources
	Returns: XML Element for the style (and writes image to Application support)
*/
- (NSXMLElement *) genericStyleNamed:(NSString *) name {
	NSXMLElement * style =  nil;
	
	NSString * pathToImage = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
	NSData * imageData = [NSData dataWithContentsOfFile:pathToImage];
	if (imageData) {
		style = [self createStyleForImageData:imageData withID:[EAGENERICSTYLEPREFIX stringByAppendingString:name]];
	}
	
	return style;
}




#pragma mark Write KML
/*
 action for writing KML file
*/
- (IBAction) do: (id) sender {
	if (!self.KMLRunning) {
		[self beginBusy];
		self.KMLProgress = 0;
		self.KMLRunning = YES;
		[NSThread detachNewThreadSelector:@selector(do2:) toTarget:self withObject:sender];
	}
	else if (self.KMLRunning) {
		[KMLThread cancel];
	}
}



/*
 method writing the KML file
 to be run in separate thread
*/
- (void) do2:(id) sender {
	@autoreleasepool {
		KMLThread = [NSThread currentThread];
		double currentPosition = .000001;

		NSArray * people = [self relevantPeople];

		if (people) {
			self.KMLMaximum = [people count];

			NSEnumerator * myEnum = [people objectEnumerator];
			ABPerson * person;
			
			// Basic XML setup for KML file
			NSXMLElement * myXML = [NSXMLElement elementWithName:@"Document"];
			NSXMLNode * documentID = [NSXMLNode attributeWithName:@"id" stringValue:[[NSUUID UUID] UUIDString]];
			[myXML addAttribute:documentID];
			[myXML addChild:[NSXMLNode elementWithName:@"name" stringValue:NSLocalizedString(@"Addresses", @"Addresses")]];
			
			// Add generic home and work place styles
			NSXMLElement * genericStyle = [self genericStyleNamed:@"home"];
			if (genericStyle) {	[myXML addChild:genericStyle]; }
			genericStyle = [self genericStyleNamed:@"work"];
			if (genericStyle) {	[myXML addChild:genericStyle]; }
			
			NSMutableDictionary * addressLabelGroups = [NSMutableDictionary dictionary];
#pragma mark -do2: People loop
			//
			// Run through all people in the list
			//
			
			while ((person = [myEnum nextObject]) && ![[NSThread currentThread] isCancelled]) {
				@autoreleasepool {
					self.KMLProgress = currentPosition;
					currentPosition += 1.;
														
					NSString * uniqueID = [person uniqueId];
					NSString * ID = [@"EA" stringByAppendingString:[[person uniqueId] substringToIndex:[uniqueID length] - 9]];
					int flags = [[person valueForProperty:kABPersonFlags] intValue];

					// get the name	or anonymous replacement
					NSString * name;
					BOOL useName = [[UDC valueForKeyPath:@"values.placemarkWithName"] boolValue];
					if (!useName) {
						// don't use names in the KML file
						name = [UDC valueForKeyPath:@"values.placemarkNameReplacement"];
					}
					else {
						// put names into KML file
						NSString * vorname;
						NSString * nachname;
						if (!(flags & kABShowAsCompany)) {
							vorname = [person valueForProperty:kABFirstNameProperty];
							if (!vorname) { vorname = @"";}
							nachname = [person valueForProperty:kABLastNameProperty];
							if (!nachname) {nachname = @"";}
							name = [vorname stringByAppendingFormat:@" %@", nachname];
						}
						else {
							name = [person valueForProperty:kABOrganizationProperty];
							if (!name) {name = @"???";}
						}
					}
					

					//
					// insert style with appropriate image for this person
					NSString * fullImagePath = nil; // need this later to put image into contact description
					NSData * imageData = nil; // need this later to put image into contact description
					if ([[UDC valueForKeyPath:@"values.placemarkWithImage"] boolValue]) {
						imageData = [person imageData];
						NSXMLElement * styleXML = [self createStyleForImageData:imageData withID:ID];
						if (styleXML) {
							[myXML addChild:styleXML];
							fullImagePath = [self fullPNGImagePathForName:ID];
						}
					}
					

					//
					// now cycle through the various addresses and create placemarks
					ABMultiValue * addresses = [person valueForProperty:kABAddressProperty];
					NSUInteger addressCount = [addresses count];
					NSUInteger index = 0;

					while (addressCount > index) {

#pragma mark -do2: Address Label			
						NSDictionary * theAddress = [addresses valueAtIndex:index];
						NSString * addressLocationKey = [self dictionaryKeyForAddressDictionary:theAddress];
						NSDictionary * addressCoordinates = locations[addressLocationKey];

						if ([addressCoordinates isKindOfClass:[NSDictionary class]]) {
							// only include addresses we resolved before
							NSString * addressName = [addresses labelAtIndex:index];
							NSString * addressLabel = [self localisedLabelName: addressName];
							NSString * normalisedLabel = [addressLabel capitalizedString];

							NSString * nameAndLabel;
							if (addressLabel) {
								nameAndLabel = [name stringByAppendingFormat:@" (%@)", normalisedLabel];
							}
							else {
								nameAndLabel = name;
							}
							
							
#pragma mark -do2: Address String
							NSXMLElement * placemarkElement = [NSXMLElement elementWithName:@"Placemark"];
							// [placemarkElement addAttribute: [NSXMLNode attributeWithName:@"id" stringValue:ID]];
							NSXMLElement * nameElement;
							if ([[UDC valueForKeyPath:@"values.placemarkWithLabel"] boolValue]) {
								nameElement = [NSXMLNode elementWithName:@"name" stringValue: nameAndLabel];						
							}
							else {
								nameElement = [NSXMLNode elementWithName:@"name" stringValue: name];
							}
							[placemarkElement addChild: nameElement];
							
							NSString * visibilityString = ([self isOldLabel:normalisedLabel] ? @"0" : @"1");
							NSXMLElement * visibilityElement = [NSXMLNode elementWithName:@"visibility" stringValue: visibilityString];
							[placemarkElement addChild: visibilityElement];
													
							NSXMLElement * pointElement = [NSXMLElement elementWithName:@"Point"];
							NSXMLElement * coordinatesElement = [NSXMLNode elementWithName:@"coordinates" stringValue:[NSString stringWithFormat:@"%@,%@", addressCoordinates[@"lon"], addressCoordinates[@"lat"]]];
							[pointElement addChild:coordinatesElement];
							[placemarkElement addChild:pointElement];
							
						
							NSMutableString * descriptionHTMLString = [NSMutableString string];
							
							if (fullImagePath) {
								[descriptionHTMLString appendFormat: @"<img src=\"file:%@\" alt=\"%@\" style=\"float:right;height:128px;margin-top:-1em;margin-left:1em;\">\n",
								 [fullImagePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
								 NSLocalizedString (@"Photo", @"Photo (alt tag for image)")];		
							}
							
							if ([[UDC valueForKeyPath:@"values.placemarkWithAddress"] boolValue]) {
								NSArray * addressComponents = [self componentsFromAddressDictionary:theAddress];
								NSString * addressString = [addressComponents componentsJoinedByString:@"<br />"];
								[descriptionHTMLString appendFormat:@"%@", addressString];
							}
							
							if ([[UDC valueForKeyPath:@"values.placemarkWithAddressBookLink"] boolValue]) {
								[descriptionHTMLString appendFormat: @"<br /><a href=\"addressbook://%@\">%@</a>",
								 uniqueID,
								 NSLocalizedString(@"open in AddressBook", @"open in AddressBook")];
							}
						
							[descriptionHTMLString appendString:@"<hr style='width:20em;clear:all;visibility:hidden;' />"];
								
							
#pragma mark -do2: Related People
							if ([[UDC valueForKeyPath:@"values.placemarkWithContacts"] boolValue]) {
								ABMultiValue * people = [person valueForProperty:kABRelatedNamesProperty];
								NSUInteger peopleCount = [people count];
								if (peopleCount != 0) {
									[descriptionHTMLString appendString:@"<br />"];
									NSInteger personIndex = 0;
									while (personIndex < peopleCount ) {
										NSString * personName = [people valueAtIndex: personIndex];
										NSString * personLabel = [self localisedLabelName:[people labelAtIndex: personIndex]];
										if (personName != nil && personLabel != nil) {
											[descriptionHTMLString appendFormat:@"<br /><strong>%@:</strong> %@", personLabel, personName];
										}
										personIndex++;
									}
								}
							}
							
							
#pragma mark -do2: EMail, Phone, Web extras			
							if ([[UDC valueForKeyPath:@"values.placemarkWithEMail"] boolValue]) {
								// include non-old e-mail addresses in placemark
								ABMultiValue * eMails = [person valueForProperty:kABEmailProperty];
								NSUInteger eMailCount = [eMails count];
								if (eMailCount != 0) {
									NSInteger index = 0;
									[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> ", NSLocalizedString(@"E-Mail", @"E-Mail (appears in Google Earth Info Balloon)")];
									NSMutableArray * eMailArray = [NSMutableArray arrayWithCapacity:eMailCount];
									NSString * allEMails = nil;
									while (index < eMailCount) {
										if (![self isOldLabel:[eMails labelAtIndex:index]]) {
											NSString * eMailAddress = [eMails valueAtIndex:index];
											if (eMailAddress) {
												NSString * localisedLabel = [self localisedLabelName:[eMails labelAtIndex:index]];
												if (localisedLabel) {
													localisedLabel = [NSString stringWithFormat:@" (%@)", localisedLabel];
												}
												else {
													localisedLabel = @"";
												}
												[eMailArray addObject:[NSString stringWithFormat:@"<a href='mailto:%@'>%@</a>%@", eMailAddress, eMailAddress, localisedLabel]];
												allEMails = [eMailArray componentsJoinedByString:@", "];
											}
										}
										index++;
									}
									if (allEMails) {
										[descriptionHTMLString appendFormat:@"%@.", allEMails];
									}
								}
							}
							
							
							if ([[UDC valueForKeyPath:@"values.placemarkWithWeblinks"] boolValue]) {
								// include non-old web-addresses in placemark
								ABMultiValue * weblinks = [person valueForProperty:kABURLsProperty];
								NSUInteger weblinkCount = [weblinks count];
								if (weblinkCount != 0) {
									int index = 0;
									[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> ", NSLocalizedString(@"Web", @"Web (appears in Google Earth Info Balloon)")];
									NSMutableArray * weblinkArray = [NSMutableArray arrayWithCapacity:weblinkCount];
									NSString * allWeblinks = nil;
									while (index < weblinkCount) {
										if (![self isOldLabel:[weblinks labelAtIndex:index]]) {
											NSString * weblink = [weblinks valueAtIndex:index];
											if (weblink) {
												NSString * localisedLabel = [self localisedLabelName:[weblinks labelAtIndex:index]];
												if (localisedLabel) {
													localisedLabel = [NSString stringWithFormat:@" (%@)", localisedLabel];
												}
												else {
													localisedLabel = @"";
												}
												[weblinkArray addObject:[NSString stringWithFormat:@"<a href='%@'>%@</a>%@", weblink, weblink, localisedLabel]];
												allWeblinks = [weblinkArray componentsJoinedByString:@", "];
											}
										}
										index++;
									}
									if (allWeblinks) {
										[descriptionHTMLString appendFormat:@"%@.", allWeblinks];
									}
								}
							}
							
							
							if ([[UDC valueForKeyPath:@"values.placemarkWithPhone"] boolValue]) {
								// include non-old phone numbers in placemark
								ABMultiValue * phones = [person valueForProperty:kABPhoneProperty];
								NSUInteger phoneCount = [phones count];
								if (phoneCount != 0) {
									int index = 0;
									[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> ", NSLocalizedString(@"Phone", @"Phone (appears in Google Earth Info Balloon)")];
									NSMutableArray * phoneArray = [NSMutableArray arrayWithCapacity:phoneCount];
									NSString * allPhoneNumbers = nil;
									while (index < phoneCount) {
										if (![self isOldLabel:[phones labelAtIndex:index]]) {
											NSString * phoneNumber = [phones valueAtIndex:index];
											if (phoneNumber) {
												NSString * localisedLabel = [self localisedLabelName:[phones labelAtIndex:index]];
												if (localisedLabel) {
													localisedLabel = [NSString stringWithFormat:@" (%@)", localisedLabel];
												}
												else {
													localisedLabel = @"";
												}
												[phoneArray addObject:[NSString stringWithFormat:@"%@%@", phoneNumber,  localisedLabel]];
												allPhoneNumbers = [phoneArray componentsJoinedByString:@", "];
											}
										}
										index++;
									}
									if (allPhoneNumbers) {
										[descriptionHTMLString appendFormat:@"%@.", allPhoneNumbers];
									}
								}
							}
							
							if ([[UDC valueForKeyPath:@"values.placemarkWithNotes"] boolValue]) {
								NSString * noteString = [person valueForProperty: kABNoteProperty];
								if ( [noteString length] > 0 ) {
									NSMutableString * noteStringWithNewlines = [noteString mutableCopy];
									[noteStringWithNewlines replaceOccurrencesOfString:@"\n" withString:@"<br />" options:NSLiteralSearch range:NSMakeRange(0, [noteStringWithNewlines length])];
									[noteStringWithNewlines replaceOccurrencesOfString:@"\r" withString:@"<br />" options:NSLiteralSearch range:NSMakeRange(0, [noteStringWithNewlines length])];
									[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> %@", NSLocalizedString(@"Note", @"Note (appears in Google Earth Info Balloon)"), noteStringWithNewlines];
								}
							}
							
							[descriptionHTMLString appendString:@"<br />"];
							
							NSXMLElement * descriptionElement = [NSXMLElement elementWithName:@"description" stringValue:descriptionHTMLString];
							[placemarkElement addChild: descriptionElement];
							NSXMLElement * snippetElement = [NSXMLElement elementWithName:@"Snippet"];
							[placemarkElement addChild:snippetElement];
							NSXMLElement * styleURLElement = nil;
							if (imageData) {
								// use custom pin style if we have an image for the person
								styleURLElement = [NSXMLElement elementWithName:@"styleUrl" stringValue:[@"#" stringByAppendingString:ID]];
							}
							else {
								// if we don't have and image for the person, use own generic home and work images unless the hidden noHomeWorkIcons preference is set to YES
								BOOL wantImages = ![[UDC valueForKeyPath:@"values.noHomeWorkIcons"] boolValue];
								if (wantImages) {
									if ([addressName isEqualToString:kABAddressHomeLabel]) {
										styleURLElement = [NSXMLElement elementWithName:@"styleUrl" stringValue:[NSString stringWithFormat:@"#%@%@", EAGENERICSTYLEPREFIX, GENERICHOMEICONNAME]];
									}
									else if ([addressName isEqualToString:kABAddressWorkLabel]) {
										styleURLElement = [NSXMLElement elementWithName:@"styleUrl" stringValue:[NSString stringWithFormat:@"#%@%@", EAGENERICSTYLEPREFIX, GENERICWORKICONNAME]];
									}
								}
								// don't specify a style if there is neither an image nor a home or work address
							}
							if (styleURLElement) {
								[placemarkElement addChild:styleURLElement];
							}
							if ([[UDC valueForKeyPath:@"values.groupByAddressLabel"] boolValue]) {
								// create a group for each address label and add the addresses accordingly
								NSXMLElement * addressGroup = addressLabelGroups[normalisedLabel];
							
								if (addressGroup == nil) {
									// group doesn't exist yet => create it
									addressGroup = [NSXMLElement elementWithName:@"Folder"];

									[addressGroup addChild:[NSXMLNode elementWithName:@"name" stringValue:normalisedLabel]];
									addressLabelGroups[normalisedLabel] = addressGroup;
									
									if ([self isOldLabel:normalisedLabel]) {
										// this is the group for old addresses
										[addressGroup addChild:[NSXMLNode elementWithName:@"visibility" stringValue: @"0"]];
									}
								}
								// add element to this group
								[addressGroup addChild:placemarkElement];
								// groups will be sorted and added to the main XML tree after the loop has finished
							}
							else {
								// add element to the main group immediately
								[myXML addChild: placemarkElement];
							}
						}
						
						index++;
					} // end of address loop

				} // @autoreleasepool (inner)
			} // end of people loop

			
			
			if ([[UDC valueForKeyPath:@"values.groupByAddressLabel"] boolValue]) {
				// sort and add folders of contacts for each group to main XML tree
				NSArray * sortedLabels = [[addressLabelGroups allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
				NSEnumerator * labelEnumerator = [sortedLabels objectEnumerator];
				id label;
				
				while (label = [labelEnumerator nextObject]) {
					[myXML addChild: addressLabelGroups[label]];
				}
			}

			self.KMLProgress = [people count];
			
			if (![[NSThread currentThread] isCancelled]) {
#pragma mark -do2: Write KML
				NSXMLElement * kmlElement = [NSXMLElement elementWithName:@"kml"];
				[kmlElement addAttribute: [NSXMLNode attributeWithName: @"xmlns" stringValue:@"http://earth.google.com/kml/2.1"]];
				[kmlElement addChild: myXML];
				NSXMLDocument * myXMLDocument = [[NSXMLDocument alloc] initWithRootElement:kmlElement];
				[myXMLDocument setCharacterEncoding:@"utf-8"];
					
				NSData * xmlData = [myXMLDocument XMLData];
					
				//
				// now compress the result
				NSString * KMLFileName = [NSLocalizedString(@"Filename", @"KML Dateiname") stringByAppendingPathExtension:@"kml"];
				NSString * XMLpath = [NSString stringWithFormat:[@"~/Desktop/%@" stringByExpandingTildeInPath], KMLFileName];
				int i = 2;
					
				while ([[NSFileManager defaultManager] fileExistsAtPath:XMLpath]) {
					KMLFileName = [[NSString stringWithFormat:@"%@ %i", NSLocalizedString(@"Filename", @"KML Dateiname"), i] stringByAppendingPathExtension:@"kml"];
					XMLpath = [NSString stringWithFormat:[@"~/Desktop/%@" stringByExpandingTildeInPath], KMLFileName];
					i++;
				}

				[xmlData writeToFile:XMLpath atomically:YES];
				[self setValue:[NSString stringWithFormat:NSLocalizedString(@"File '%@' on your Desktop", @"Status message after successful creation of the KML file."), KMLFileName] forKey:@"doneMessage"];
			}
			else {
				[self setValue:NSLocalizedString(@"Placemark generation was cancelled.", @"Status message after cancelled KML file creation.") forKey:@"doneMessage"];
			}
					
#pragma mark -do2: Clean Up 	
			
			self.KMLRunning = NO;
			self.KMLProgress = 0;
		}
		
		[self endBusy];
	} // @autoreleasepool (thread)
}








#pragma mark Actions

/*
	Displays warning sheet about privacy issues
*/
- (IBAction) showWarningInfo: (id) sender {
	[NSApp beginSheet:warningMessage modalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

/*
	for OK button of warning sheet about privacy issues
*/
- (IBAction) dismissSheet:(id) sender {
	[NSApp endSheet: warningMessage];
	[warningMessage orderOut:self];
}

/*
	toggles groupByAddressLabel user default
*/
- (IBAction) toggleGroupByLabel: (id) sender {
	
}

/*
 toggles hideOldByDefault user default
 */
- (IBAction) toggleHideOldByDefault: (id) sender {
	
}




/*
	1. clears all FAIL marks for locations
	2. initiates a look-up for addresses
*/
- (IBAction) lookupNonLocatableAddresses: (id) sender {
	[failLocations removeAllObjects];
	[self updateRelevantPeopleInfo:[[ABAddressBook sharedAddressBook] people]];

	[self convertAddresses:self];
}





#pragma mark Non-Locatable Addresses

- (IBAction) createListOfNonLocatableAddresses:(id) sender {
	NSMutableString * s = [NSMutableString string];
	NSArray * people;
	if ([sender isKindOfClass:[NSButton class]]) {
		// the button in the window was user => only use non-found addresses in the current selection
		people = [self relevantPeople];
	}
	else {
		// the menu item was used => use _all_ non-found addresses
		people = [[ABAddressBook sharedAddressBook] people];		
	}
	
	
	NSEnumerator * myEnum = [people objectEnumerator];
	ABPerson * myPerson;
	
	while (myPerson = [myEnum nextObject]) {
		ABMultiValue * addresses = [myPerson valueForProperty:kABAddressProperty];
		NSUInteger totalAddresses = [addresses count];
		
		NSUInteger index = 0;
		while (totalAddresses > index) {
			NSDictionary * addressDict = [addresses valueAtIndex:index];
			NSString * addressKey = [self dictionaryKeyForAddressDictionary:addressDict];
			NSObject * addressObject = failLocations[addressKey];
			if (addressObject != nil) {
				[s appendFormat:@"%@\n***\n", addressKey];
			}
			index++;
		}
	}
	
	
	NSString * savePath = [NSString stringWithFormat:@"/tmp/Earth Addresser Non Locatable Addresses %@.text", [[NSUUID UUID] UUIDString]];
	NSURL * saveURL = [NSURL fileURLWithPath:savePath];
	NSError * myError = nil;
	if ([s writeToURL:saveURL atomically:NO encoding:NSUTF8StringEncoding error:&myError]) {
		[[NSWorkspace sharedWorkspace] openURL:saveURL];
	}
	else {
		NSAlert * alert = [NSAlert alertWithError:myError];
		[alert performSelectorOnMainThread:@selector(runModal) withObject:nil waitUntilDone:YES];
	}
	
}




#pragma mark KVC

- (void) observeValueForKeyPath:(NSString *)keyPath
					   ofObject:(id)object
						 change:(NSDictionary *)change
					    context:(void *)context {
	if ((object == self.addressTermsToRemoveController || object == self.oldLabelsController) &&
		[keyPath isEqualToString:@"arrangedObjects"]) {
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


- (NSImage*) AddressBookIcon {
	NSImage * image = nil;
	NSString * appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.addressbook"];
	if (appPath) {
		image = [[NSWorkspace sharedWorkspace] iconForFile:appPath];
	}
	return image;
}


- (NSImage*) MapsIcon {
	NSImage * image = nil;
	NSString * appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.Maps"];
	if (appPath) {
		image = [[NSWorkspace sharedWorkspace] iconForFile:appPath];
	}
	return image;
}


- (NSImage*) KMLIcon {
	return [[NSWorkspace sharedWorkspace] iconForFileType:@"kml"];
}






#pragma mark Utility Methods


/*
 Localises Address Boook labels, could return nil
*/
- (NSString *) localisedLabelName:(NSString *)labelName {
	NSString * localisedLabelName = (NSString *) CFBridgingRelease(ABCopyLocalizedPropertyOrLabel((__bridge CFStringRef)labelName));
	return localisedLabelName;
}



/*
 Removes lines from string containing terms marked for removal.
*/
- (NSString *) cleanAddress:(NSString *)address {
	NSArray * addressLines = [address componentsSeparatedByString:@"\n"];
	NSMutableArray * cleanAddressLines = [NSMutableArray arrayWithCapacity:addressLines.count];
	
	for (NSString * addressLine in addressLines) {
		BOOL keepLine = YES;
		for (ESTerm * term in self.addressTermsToRemove) {
			if (term.active) {
				NSRange termRange = [addressLine rangeOfString:term.string options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch];
				if (termRange.location != NSNotFound) {
					keepLine = NO;
					break;
				}
			}
		}
		if (keepLine) {
			[cleanAddressLines addObject:addressLine];
		}
	}
	
	return [cleanAddressLines componentsJoinedByString:@"\n"];
}



/*
 Returns whether the passed label is marked as indicating old information.
*/
- (BOOL) isOldLabel:(NSString *)label {
	BOOL isOldLabel = FALSE;
	NSString * uppercaseLabel = [label uppercaseString];
	for (ESTerm * oldLabel in self.oldLabels) {
		if (oldLabel.active == YES && [[oldLabel.string uppercaseString] isEqualToString:uppercaseLabel]) {
			isOldLabel = YES;
			break;
		}
	}
	return isOldLabel;
}



/*
 for the various actions in the help menu
*/
- (IBAction) readme:(id) sender {
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
			[WORKSPACE openURL: [NSURL URLWithString:[@"https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=earthlingsoft%40earthlingsoft.net&item_name=Earth%20Addresser&no_shipping=1&cn=Comments&tax=0&currency_code=EUR&lc=" stringByAppendingString: NSLocalizedString(@"PayPal Region Code", @"PayPal Region Code - used in PayPal URL")]]];
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
	[[mainWindow standardWindowButton: NSWindowCloseButton] setEnabled: NO];
}


/*
 we are finished being busy: re-enable sudden termination, quit if so desired
*/
- (void) endBusy {
	[NSApp replyToApplicationShouldTerminate: YES];
	[[mainWindow standardWindowButton: NSWindowCloseButton] setEnabled: YES];
	[[NSProcessInfo processInfo] enableSuddenTermination];
}





#pragma mark Updating

- (IBAction) toggleAutoCheckForUpdates: (id) sender {
}

@end




@implementation ABGroup (ESSortExtension)

- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup {
	NSString * myName = [self valueForProperty:kABGroupNameProperty];
	NSString * theirName = [aGroup valueForProperty:kABGroupNameProperty];
	return [myName caseInsensitiveCompare:theirName];
}

@end




/*
 Helper function for sorting the people array by name.
 */
NSInteger nameSort(id person1, id person2, void *context) {
	NSString * lastName1 = [person1 valueForProperty:kABLastNamePhoneticProperty];
	if (!lastName1) {
		lastName1 = [person1 valueForProperty:kABLastNameProperty];
	}
	NSString * lastName2 = [person2 valueForProperty:kABLastNamePhoneticProperty];
	if (!lastName2) {
		lastName2 = [person2 valueForProperty:kABLastNameProperty];
	}
	
	NSComparisonResult result = [lastName1 localizedCaseInsensitiveCompare:lastName2];
	
	if (result == NSOrderedSame) {
		NSString * firstName1 = [person1 valueForProperty:kABFirstNamePhoneticProperty];
		if (!firstName1) {
			firstName1 = [person1 valueForProperty:kABFirstNameProperty];
		}
		NSString * firstName2 = [person2 valueForProperty:kABFirstNamePhoneticProperty];
		if (!firstName2) {
			firstName2 = [person2 valueForProperty:kABFirstNameProperty];
		}
		
		result = [firstName1 localizedCaseInsensitiveCompare:firstName2];
		
		if (result == NSOrderedSame) {
			NSString * middleName1 = [person1 valueForProperty:kABMiddleNamePhoneticProperty];
			if (!middleName1) {
				middleName1 = [person1 valueForProperty:kABMiddleNameProperty];
			}
			NSString * middleName2 = [person2 valueForProperty:kABMiddleNamePhoneticProperty];
			if (!middleName2) {
				middleName2 = [person2 valueForProperty:kABMiddleNameProperty];
			}
			
			result = [middleName1 localizedCaseInsensitiveCompare:middleName2];
		}
	}
	
	return result;
}
