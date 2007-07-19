//
//  Magic.m
//  Mailboxer
//
//  Created by  Sven on 21.03.07.
//  Copyright 2007 earthlingsoft. All rights reserved.
//
//

#import "Magic.h"


@implementation Magic


- (id) init {
	[super init];
	[self buildGroupList];
	NSDictionary * standardDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO], @"dontShowWarning", 
		ALLDICTIONARY, @"selectedGroup", 
		[NSNumber numberWithFloat:1.5], @"imageSize", 
		nil];
	UDC = [NSUserDefaultsController sharedUserDefaultsController];
	[UDC setInitialValues:standardDefaults];	
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(addressBookChanged:)
                                                 name:kABDatabaseChangedExternallyNotification
                                               object:nil];	
	[self setValue:[NSDate date] forKey:@"lastProgressBarUpdate"];
	// look whether there are updates if necessary
	if ( [[UDC valueForKeyPath:@"values.lookForUpdate"] boolValue] ) {
		[self menuCheckVersion:self];
	}
	
	return self;
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
	
	[a addObject:ALLDICTIONARY];
	NSEnumerator * myEnum = [ABGroups objectEnumerator];
	ABGroup * group;
	while (group = [myEnum nextObject]) {
		[a addObject:[NSDictionary dictionaryWithObjectsAndKeys:[group uniqueId], MENUOBJECT, [group valueForProperty:kABGroupNameProperty], MENUNAME, nil]];
	}
	[self setValue:a forKey:@"groups"];
	
	// look whether the selected item still exists. If it doesn't reset to ALL group
	NSString * selectedGroup = (NSString*) [[UDC valueForKeyPath:@"values.selectedGroup"] objectForKey:MENUOBJECT];
	if ([selectedGroup hasSuffix:@":ABGroup"] || [selectedGroup hasSuffix:@":ABSmartGroup"]) {
		ABGroup * myGroup = (ABGroup*) [ab recordForUniqueId:selectedGroup];
		if (!myGroup) {
			// the group doesn't exist anymore => switch to all
			[UDC setValue:ALLDICTIONARY forKeyPath:@"values.selectedGroup"];
		}
	}
}



- (IBAction) do: (id) sender {
	// [NSThread detachNewThreadSelector:@selector(do2:) toTarget:self withObject:sender];
	[self do2:sender];
}
	
	
- (void) do2:(id) sender {
	NSAutoreleasePool * myPool = [[NSAutoreleasePool alloc] init];
	
	[self setValue:[NSNumber numberWithInt:0] forKey:@"currentPosition"];
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"running"];
	[sender setTitle:NSLocalizedString(@"Creating bookmark file",@"Creating bookmark file")];
	[sender setEnabled:NO];	
	[sender display];
	
	//
	// for KMZ file handling 
	/* NSString * pathName = [@"/tmp/" stringByAppendingPathComponent:[self uuid]];
	NSString * folderName = NSLocalizedString(@"Contacts", @"Contacts"); 
	NSString * folderNamePath = [pathName stringByAppendingPathComponent:folderName];
	NSString * imagesName = @"Images";
	if (!( [[NSFileManager defaultManager] createDirectoryAtPath:pathName attributes:nil] 
		   && [[NSFileManager defaultManager] createDirectoryAtPath:folderNamePath attributes:nil]
		   && [[NSFileManager defaultManager] changeCurrentDirectoryPath:folderNamePath]
		   && [[NSFileManager defaultManager] createDirectoryAtPath:imagesName attributes:nil])) {
		[self error:NSLocalizedString(@"Couldn't create temporary folder",@"Couldn't create temporary folder")];
		return;
	}
	*/
	
#pragma mark -do2: Folder Setup
	
	NSFileManager * myFM = [NSFileManager defaultManager];
	NSString * appSupportPath = [NSSearchPathForDirectoriesInDomains( NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString * EAAppSupportPath = [appSupportPath stringByAppendingPathComponent:@"EarthAddresser"];
	if (! [myFM fileExistsAtPath: EAAppSupportPath]) {
		if (![myFM createDirectoryAtPath:EAAppSupportPath attributes:nil]) {
			[self error: NSLocalizedString(@"Couldn't create Application Support/EarthAddresser folder", @"Couldn't create Application Support/EarthAddresser folder")];
			return;
		}
	}
	NSString * imagesPath = [EAAppSupportPath stringByAppendingPathComponent:@"Images"];
	if (! [myFM fileExistsAtPath: imagesPath]) {
		if (![myFM createDirectoryAtPath:imagesPath attributes:nil]) {
			[self error: NSLocalizedString(@"Couldn't create Application Support/EarthAddresser/Images folder", @"Couldn't create Application Support/EarthAddresser/Images folder")];
			return;
		}
	}
	

#pragma mark -do2: Get Contacts & Setup	
	ABAddressBook * ab = [ABAddressBook sharedAddressBook];

	NSArray * people = nil ;
	NSString * selectedGroup = (NSString*) [[UDC valueForKeyPath:@"values.selectedGroup"] objectForKey:MENUOBJECT];
	if ([selectedGroup isEqualToString:MENUITEMALL]) {
		people = [ab people];
	}
	else if ([selectedGroup hasSuffix:@":ABGroup"] || [selectedGroup hasSuffix:@":ABSmartGroup"]) {
		ABGroup * myGroup = (ABGroup*) [ab recordForUniqueId:selectedGroup];
		if (myGroup) {
			people = [myGroup members];
		}
		else {
			// the group doesn't exist anymore => switch to all
			[self error: @"group doesn't exist anymore - this shouldn't happen"];
			return;
		}
	}
	else {
		// eeek!
		[self error:NSLocalizedString(@"Selected group wasn't recognisable.",@"Selected group couldn't be recognised.")];
		return;
	}

	[self setValue:[NSNumber numberWithInt:[people count]] forKey:@"recordCount"];

	NSTimeInterval progressBarStepTimeInterval = 0.04;
	if ([people count] < 100) {
		progressBarStepTimeInterval = 0.02;
	}
	else if ([people count] < 50) {
		progressBarStepTimeInterval = 0.01;
	}
	else if ([people count] < 20) { 
		progressBarStepTimeInterval = 0.03;
	}
	
	NSEnumerator * myEnum = [people objectEnumerator];
	ABPerson * person;
	
	NSXMLElement * myXML = [NSXMLElement elementWithName:@"Document"];
	ABPerson * me = [[ABAddressBook sharedAddressBook] me];
	if (me) {
		NSXMLNode * documentID = [NSXMLNode attributeWithName:@"id" stringValue:[me uniqueId]];
		[myXML addAttribute:documentID];
	}
	[myXML addChild:[NSXMLNode elementWithName:@"name" stringValue:NSLocalizedString(@"Addresses", @"Addresses")]];
	

#pragma mark -do2: People loop
	//
	// Run through all people in the list
	//
	while (person = [myEnum nextObject]) {
		NSString * uniqueID = [person uniqueId];
		NSString * ID = [@"EA" stringByAppendingString:[[person uniqueId] substringToIndex:[uniqueID length] -9]];
		int flags = [[person valueForProperty:kABPersonFlags] intValue];

		//
		// get the name	
		NSString * name;
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

	
#pragma mark -do 2: Image Handling
		//
		// get image data & add styling if we have an image
		NSData * imageData = [person imageData];
		NSString * fullImagePath = nil;
		if (imageData) {
		NSBitmapImageRep * theImage = [NSBitmapImageRep imageRepWithData:imageData];
		NSString * imageFileName = [ID stringByAppendingPathExtension:@"png"];
		//	NSString * imageFileName = ID;
		if (theImage) {
			// got an image, so write it to a file and add the style information
			NSData * myPNG = [theImage representationUsingType:NSPNGFileType properties:nil];
			if (myPNG) {
				fullImagePath = [imagesPath stringByAppendingPathComponent:imageFileName];
				if ([myPNG writeToFile:fullImagePath atomically:YES]) {
					// now that we have the image, create the style for it
					NSXMLElement * styleElement = [NSXMLElement elementWithName:@"Style"];
					[styleElement addAttribute:[NSXMLNode attributeWithName:@"id" stringValue:ID]];
					NSXMLElement * iconStyleElement = [NSXMLElement elementWithName:@"IconStyle"];	
					NSXMLElement * iconElement = [NSXMLElement elementWithName:@"Icon"];
					//NSXMLElement * hrefElement = [NSXMLNode elementWithName:@"href" stringValue:[[@"." stringByAppendingPathComponent:imagesName] stringByAppendingPathComponent:imageFileName]];
					NSXMLElement * hrefElement = [NSXMLNode elementWithName:@"href" stringValue:fullImagePath];
					[iconElement addChild: hrefElement];
					[iconStyleElement addChild:iconElement];
					NSXMLElement * sizeElement = [NSXMLNode elementWithName:@"scale" stringValue:[UDC valueForKeyPath:@"values.imageSize"]];
					[iconStyleElement addChild:sizeElement];
					NSXMLElement * hotSpotElement = [NSXMLNode elementWithName:@"hotSpot"];
					[hotSpotElement addAttribute:[NSXMLNode attributeWithName:@"x" stringValue:@"0.5"]];
					[hotSpotElement addAttribute:[NSXMLNode attributeWithName:@"y" stringValue:@"0"]];
					[hotSpotElement addAttribute:[NSXMLNode attributeWithName:@"xunits" stringValue:@"fraction"]];
					[hotSpotElement addAttribute:[NSXMLNode attributeWithName:@"yunits" stringValue:@"fraction"]];
					[iconStyleElement addChild:hotSpotElement];
					[styleElement addChild:iconStyleElement];				
					[myXML addChild:styleElement];
					
				}
			}		
		}	
		}
		

		// 
		// now cycle through the various addresses and create placemarks
		ABMultiValue * addresses = [person valueForProperty:kABAddressProperty];
		int addressCount = [addresses count];
		int index = 0;

#pragma mark -do2: Address Loop
		while (addressCount > index) {

#pragma mark -do2: Address Label			
			NSDictionary * theAddress = [addresses valueAtIndex:index];
			NSString * addressName = [addresses labelAtIndex:index];
			NSString * addressLabel;
			if ([addressName isEqualToString:kABHomeLabel]) {
				addressLabel =  NSLocalizedString(@"Home", @"Home (Address Label)");
			}
			else if ([addressName isEqualToString: kABWorkLabel]) {
				addressLabel = NSLocalizedString(@"Work", @"(Work (Address Label)");
			}
			else if ([addressName isEqualToString: kABOtherLabel]) {
				addressLabel = nil; // NSLocalizedString(@"Other", @"Other (Address Label)");
			}
			else {
				addressLabel = addressName;
			}
			NSString * nameAndLabel;
			if (addressLabel) {
				nameAndLabel = [name stringByAppendingFormat:@" (%@)", addressLabel];
			}
			else {
				nameAndLabel = name;
			}
			
#pragma mark -do2: Address String
			NSXMLElement * placemarkElement = [NSXMLElement elementWithName:@"Placemark"];
			// [placemarkElement addAttribute: [NSXMLNode attributeWithName:@"id" stringValue:ID]];
			NSXMLElement * nameElement = [NSXMLNode elementWithName:@"name" stringValue: nameAndLabel];
			[placemarkElement addChild: nameElement];
			NSXMLElement * visibilityElement = [NSXMLNode elementWithName:@"visibility" stringValue: @"1"];
			[placemarkElement addChild: visibilityElement];
				
			NSMutableString * addressString = [NSMutableString string];
			NSString * addressPiece;
			if (addressPiece = [theAddress valueForKey:kABAddressStreetKey]) {
				NSArray * evilWords = [NSArray arrayWithObjects: @"Zimmer ", @"Room ", @"Flat ", @"App ", @"Apt ", @"#", @"P.O. Box", @"P.O.Box",  @"Postfach", nil];
				NSEnumerator * evilWordEnumerator = [evilWords objectEnumerator];
				NSString * evilWord;
				while (evilWord = [evilWordEnumerator nextObject]) {
					addressPiece = [self cleanString:addressPiece from: evilWord];
				}
				[addressString appendFormat:@"%@\n", addressPiece];
			}
			if (addressPiece = [theAddress valueForKey:kABAddressCityKey]) {
				[addressString appendFormat:@"%@\n", addressPiece];
			}
			if (addressPiece = [theAddress valueForKey:kABAddressZIPKey]) {
				[addressString appendFormat:@"%@\n", addressPiece];
			}
			if (addressPiece = [theAddress valueForKey:kABAddressStateKey]) {
				[addressString appendFormat:@"%@\n", addressPiece];
			}
			if (addressPiece = [theAddress valueForKey:kABAddressCountryCodeKey]) {
				[addressString appendFormat:@"%@\n", addressPiece];
			}
			

			NSXMLElement * addressElement = [NSXMLNode elementWithName:@"address" stringValue: addressString];
			[placemarkElement addChild: addressElement];
			

			NSMutableString * descriptionHTMLString = [NSMutableString string];
			/*
			 if (fullImagePath) {
				[descriptionHTMLString appendFormat: @"<img src=\"file:%@\" alt=\"%@\" style=\"float:right;height:128px;\">\n", 
					[fullImagePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], 
					NSLocalizedString (@"Photo", @"Photo (alt tag for image)")];					
			}
			 */
			[descriptionHTMLString appendFormat: @"<a href=\"addressbook:%@\">%@</a>", 
				uniqueID, 
				NSLocalizedString(@"open in AddressBook", @"open in AddressBook")];			
			
			NSXMLElement * descriptionElement = [NSXMLElement elementWithName:@"description" stringValue:descriptionHTMLString];
			[placemarkElement addChild: descriptionElement];
			NSXMLElement * snippetElement = [NSXMLElement elementWithName:@"Snippet"];
			[placemarkElement addChild:snippetElement];
			NSXMLElement * styleURLElement = [NSXMLElement elementWithName:@"styleUrl" stringValue:[@"#" stringByAppendingString:ID]];
			[placemarkElement addChild:styleURLElement];
				
			[myXML addChild: placemarkElement];

			index++;
		}
		
		[self setValue:[NSNumber numberWithInt:currentPosition + 1] forKey:@"currentPosition"];
		if (-[lastProgressBarUpdate timeIntervalSinceNow] > 0.06) { // limit fps
			[progressBar display];
			[self setValue:[NSDate date] forKey:@"lastProgressBarUpdate"];
		}
	}

	[self setValue:[NSNumber numberWithInt:[people count]] forKey:@"currentPosition"];
	[progressBar display];
	
#pragma mark -do2: Write KML
	NSXMLElement * kmlElement = [NSXMLElement elementWithName:@"kml"];
	[kmlElement addAttribute: [NSXMLNode attributeWithName: @"xmlns" stringValue:@"http://earth.google.com/kml/2.1"]];
	[kmlElement addChild: myXML];
	NSXMLDocument * myXMLDocument = [[[NSXMLDocument alloc] initWithRootElement:kmlElement] autorelease];
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
	
	/*
	NSString * zipCommand = @"/usr/bin/zip";
	NSArray * zipArguments = [NSArray arrayWithObjects:@"-r", path, folderNamePath, nil];
	NSTask * zipTask = [NSTask launchedTaskWithLaunchPath:zipCommand arguments:zipArguments];
	[zipTask waitUntilExit];
    if ([zipTask terminationStatus] != 0) {
		[self error: NSLocalizedString(@"Compression of the KMZ file failed", @"Compression of the KMZ file failed")];
		return;
	}
		 
	[[NSFileManager defaultManager] removeFileAtPath:pathName handler:nil];
	*/	
		
#pragma mark -do2: Clean Up 	
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"dontShowWarning"]) {
		NSString * myMessage =  [NSString stringWithFormat:NSLocalizedString(@"The file %@", @"Text telling that the conversion has finished along with the file name and warning about possibly privacy implications"), KMLFileName];
		[self setValue:myMessage forKey:@"sheetMessage"];
		[NSApp beginSheet:warningMessage modalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
	
	[sender setTitle:NSLocalizedString(@"Create Google Earth Bookmarks", @"Default Button label (Create Google Earth Bookmarks)")];
	[sender setEnabled:YES];
	[sender display];
	[self setValue:[NSNumber numberWithInt:0] forKey:@"currentPosition"];
	[self setValue:[NSNumber numberWithBool:NO] forKey:@"running"];
	[progressBar setHidden:YES];
	[myPool release];
}



#pragma mark AUXILIARIES

- (IBAction) dismissSheet:(id) sender {
	[NSApp endSheet: warningMessage];
	[warningMessage orderOut:self];
}


- (NSData*) AddressBookIcon {
	NSImage * im = [[NSWorkspace sharedWorkspace] iconForFile:[[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.addressbook"]];
	[im setSize:NSMakeSize(128.0,128.0)];
	return [im TIFFRepresentation];
}


- (NSData*) GoogleEarthIcon {
	NSImage * im = [[NSWorkspace sharedWorkspace] iconForFile:[[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.Google.GoogleEarthPlus"]];
	[im setSize:NSMakeSize(128.0,128.0)];
	return [im TIFFRepresentation];
}


- (NSData*) KMLIcon {
	NSImage * im = [[NSWorkspace sharedWorkspace] iconForFileType:@"kml"];
	[im setSize:NSMakeSize(128.0,128.0)];
	return [im TIFFRepresentation];
}


- (NSString*) uuid {
	unsigned char _uuid[16];
	char _out[40];
	uuid_generate(_uuid);
	uuid_unparse(_uuid, _out);
	return [NSString stringWithUTF8String:_out];
}

- (NSString*) cleanString:(NSString*) s from:(NSString*) evil {
	NSArray * lineArray = [s componentsSeparatedByString:@"\n"];
	NSEnumerator * myEnum = [lineArray objectEnumerator];
	NSMutableString * r = [NSMutableString stringWithCapacity:[s length]];
	NSString * line;
	while (line = [myEnum nextObject]) {
		NSString * cleanedLine = [[line componentsSeparatedByString:evil] objectAtIndex:0];
		[r appendFormat:@"%@\n", cleanedLine];
	}
	return [r stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}

- (void) error: (NSString*) error {
	NSLog(error);
	NSBeep();
	[self setValue:[NSNumber numberWithBool:NO] forKey:@"running"];
}


- (void)addressBookChanged:(NSNotification *)notification {
	[self buildGroupList];
}


// for the various actions in the help menu
- (void) readme:(id) sender {
	NSWorkspace * WORKSPACE = [NSWorkspace sharedWorkspace];
	int tag = [sender tag];
	switch (tag) {
		case 1: // earthlingsoft
			[WORKSPACE openURL:[NSURL URLWithString:@"http://earthlingsoft.net/"]];
			break;
		case 2: // Website
			[WORKSPACE openURL:[NSURL URLWithString:@"http://earthlingsoft.net/Earth%20Addresser"]];
			break;
		case 3: // Send Mail
			[WORKSPACE openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:earthlingsoft%%40earthlingsoft.net?subject=Earth%%20Addresser%%20%@", [self myVersionString]]]];
			break;
		case 4: // Paypal
			[WORKSPACE openURL: [NSURL URLWithString:@"https://www.paypal.com/xclick/business=earthlingsoft%40earthlingsoft.net&item_name=Earth%20Addresser&no_shipping=1&cn=Comments&tax=0&currency_code=EUR"]];
			break;
		case 5: // Readme
			[WORKSPACE openFile:[[NSBundle mainBundle] pathForResource:@"readme" ofType:@"html"]];
			break;
	}
}


// return version string
- (NSString*) myVersionString {
	return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}


- (IBAction)menuCheckVersion:(id)sender {
    if([[NSApp currentEvent] modifierFlags] == (NSAlphaShiftKeyMask|NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) {
		//        [VersionChecker writeVersionFileWithDownloadURLString:@"http://www.earthlingsoft.net/GeburtstagsChecker/GeburtstagsChecker.sit"];
    } else {
		[VersionChecker checkVersionForURLString:@"http://www.earthlingsoft.net/Earth%20Addresser/Earth%20Addresser.xml" silent:NO];
    }
}



@end

@implementation ABGroup (ESSortExtension) 

- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup {
	NSString * myName = [self valueForProperty:kABGroupNameProperty];
	NSString * theirName = [aGroup valueForProperty:kABGroupNameProperty];
	return [myName caseInsensitiveCompare:theirName];
}

@end
