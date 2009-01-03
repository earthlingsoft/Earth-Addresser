//
//  Magic.m
//  Mailboxer / Earth Addresser
//
//  Created by  Sven on 21.03.07.
//  Copyright 2007 earthlingsoft. All rights reserved.
//
//

#import "Magic.h"
#define UDC [NSUserDefaultsController sharedUserDefaultsController]
#define UPDATEURL @"http://www.earthlingsoft.net/Earth%20Addresser/Earth%20Addresser.xml"



@implementation Magic

- (id) init {
	[super init];
	[self buildGroupList];
	NSDictionary * standardDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO], @"dontShowWarning", 
		[NSNumber numberWithFloat:1.5], @"imageSize", 
		[NSNumber numberWithInt:0], @"addressBookScope",
		[NSNumber numberWithBool:YES], @"placemarkWithName",
		@"\342\235\200", @"placemarkNameReplacement",
		[NSNumber numberWithBool:YES], @"placemarkWithImage",
		[NSNumber numberWithBool:NO], @"placemarkWithEMail",
		[NSNumber numberWithBool:NO], @"placemarkWithPhone",
	   [NSNumber numberWithBool:NO], @"hasReadInfo",
	nil];
	[UDC setInitialValues:standardDefaults];	

	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(addressBookChanged:)
                                                 name:kABDatabaseChangedExternallyNotification
                                               object:nil];	

	[self setValue:[NSDate date] forKey:@"lastProgressBarUpdate"];
	[self setValue:[NSDate date] forKey:@"lastGeocodingProgressBarUpdate"];

	// look whether there are updates if necessary
	if ( [[UDC valueForKeyPath:@"values.lookForUpdate"] boolValue] ) {
		[VersionChecker checkVersionForURLString:UPDATEURL silent:YES];
	}
	
	NSDictionary * myLocations = [UDC valueForKeyPath:@"values.locations"];
	if (myLocations) {
		locations = [myLocations mutableCopy];
	}
	else {
		locations = [[NSMutableDictionary alloc] init];
	}

	[self updateRelevantPeopleInfo];
	
	return self;
}




- (void) dealloc {
	[self saveLocations];
	[locations release];
	[lastProgressBarUpdate release];
	[lastGeocodingProgressBarUpdate release];
	[sheetMessage release];
	[groups release];
	
	[super dealloc];
}


- (void) saveLocations {
	[UDC setValue:locations forKeyPath:@"values.locations"];
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
	
//	[a addObject:ALLDICTIONARY];
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



/*
	Tells us that the radio button changed
*/
- (IBAction) addressBookScopeChanged: (id) sender {
	[self updateRelevantPeopleInfo];	
}



/*
	Switch to group instead of whole address book when a group is selected.
*/
- (IBAction) groupListSelectionChanged: (id) sender {
	[UDC setValue:[NSNumber numberWithInt:1] forKeyPath:@"values.addressBookScope"];
	[self updateRelevantPeopleInfo];
}




/*
 returns array with the people selected in the UI
*/ 
- (NSArray*) relevantPeople {
	ABAddressBook * ab = [ABAddressBook sharedAddressBook];
	BOOL error = NO;
	
	NSArray * people = nil ;
	NSString * selectedGroup = (NSString*) [[UDC valueForKeyPath:@"values.selectedGroup"] objectForKey:MENUOBJECT];
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
			[self error: @"group doesn't exist anymore - this shouldn't happen"];
			error = YES;
		}
	}
	else {
		// eeek!
		[self error:NSLocalizedString(@"Selected group wasn't recognisable.",@"Selected group couldn't be recognised.")];
		error = YES;
	}

	return people;
}





- (void) updateRelevantPeopleInfo {
	NSArray * people = [self relevantPeople];
	int addressCount = 0;
	int locatedAddressCount = 0;
	int nonLocatedAddressCount = 0;
	int notYetLocatedAddressCount = 0;
	
	NSEnumerator * myEnum = [people objectEnumerator];
	ABPerson * myPerson;
	while (myPerson = [myEnum nextObject]) {
		ABMultiValue * addresses = [myPerson valueForProperty:kABAddressProperty];
		int totalAddresses = [addresses count];
		int index = 0;
		
		while (totalAddresses > index) {
			NSDictionary * addressDict = [addresses valueAtIndex:index];
			NSString * addressKey = [self dictionaryKeyForAddressDictionary:addressDict];
			NSObject * addressObject = [locations objectForKey: addressKey];
			if (addressObject != nil) {
				if ([addressObject isKindOfClass:[NSArray class]]) {
					// it's an array of coordinates => successfully located
					locatedAddressCount++;
				}
				else {
					// looked up but not located
					nonLocatedAddressCount++;
				}
			}
			else {
				// not looked up yet
				notYetLocatedAddressCount++;
			}
			addressCount++;
			index++;
		}
	}
	
	NSString * firstPart = [NSString stringWithFormat:NSLocalizedString(@"%i contacts with %i addresses.\n", @"%i contacts with %i addresses.\n"), [people count], addressCount];

	NSString * secondPart = @"";
	if (addressCount != 0) {
		if (notYetLocatedAddressCount != 0) {
			secondPart = [NSString stringWithFormat:NSLocalizedString(@"%i of these have been successfully located, %i of these could not be located and %i have not been looked up yet.", @"%i of these have been successfully located, %i of these could not be located and %i have not been looked up yet."), locatedAddressCount, nonLocatedAddressCount, notYetLocatedAddressCount];
		}
		else {
			secondPart = [NSString stringWithFormat:NSLocalizedString(@"%i of these have been successfully located previously while the remaining %i could not be located.", @"%i of these have been successfully located previously while the remaining %i could not be located."), locatedAddressCount, nonLocatedAddressCount];
		}
	}
			
	NSString * infoString = [firstPart stringByAppendingString:secondPart];
	[self setValue:infoString forKey:@"relevantPeopleInfo"]; 
	[self setValue:[NSNumber numberWithInt:notYetLocatedAddressCount] forKey:@"notSearchedCount"];
}





- (NSString*) googleStringForAddressDictionary : (NSDictionary*) address {
	NSMutableString * addressString = [self dictionaryKeyForAddressDictionary: address];
	
	[addressString replaceOccurrencesOfString:@"\n" withString:@", " options:NSLiteralSearch range:NSMakeRange(0, [addressString length])];
	[addressString replaceOccurrencesOfString:@" " withString:@"+" options:NSLiteralSearch range:NSMakeRange(0, [addressString length])];
	
	return addressString;
}




- (NSMutableString*) dictionaryKeyForAddressDictionary : (NSDictionary*) address {
	NSMutableString * addressString = [NSMutableString string];
	NSString * addressPiece;
	if (addressPiece = [address valueForKey:kABAddressStreetKey]) {
		NSArray * evilWords = [NSArray arrayWithObjects: @"Zimmer ", @"Room ", @"Flat ", @"App ", @"Apt ", @"#", @"P.O. Box", @"P.O.Box",  @"Postfach", nil];
		NSEnumerator * evilWordEnumerator = [evilWords objectEnumerator];
		NSString * evilWord;
		while (evilWord = [evilWordEnumerator nextObject]) {
			addressPiece = [self cleanString:addressPiece from: evilWord];
		}
		[addressString appendFormat:@"%@\n", addressPiece];
	}
	if (addressPiece = [address valueForKey:kABAddressCityKey]) {
		[addressString appendFormat:@"%@\n", addressPiece];
	}
	if (addressPiece = [address valueForKey:kABAddressZIPKey]) {
		[addressString appendFormat:@"%@\n", addressPiece];
	}
	if (addressPiece = [address valueForKey:kABAddressStateKey]) {
		[addressString appendFormat:@"%@\n", addressPiece];
	}
	if (addressPiece = [address valueForKey:kABAddressCountryCodeKey]) {
		[addressString appendFormat:@"%@", addressPiece];
	}
	
	return addressString;
}






- (IBAction) convertAddresses: (id) sender {
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"geocodingRunning"];
	[NSThread detachNewThreadSelector:@selector(convertAddresses2) toTarget:self withObject:nil];
}


- (void) convertAddresses2 {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSArray * people = [self relevantPeople];
	NSEnumerator * myEnum = [people objectEnumerator];
	ABPerson * myPerson;
	NSString * baseURL = [NSString stringWithFormat:@"http://maps.google.com/maps/geo?output=csv&sensor=false&key=%@", APIKEY];
		
	NSDate * previousLookup = nil;
	
	[self setValue:[NSNumber numberWithInt:[people count]] forKey:@"geocodingRecordCount"];
	[self setValue:[NSNumber numberWithInt:0] forKey:@"geocodingCurrentPosition"];
	while (myPerson = [myEnum nextObject]) {
		ABMultiValue * addresses = [myPerson valueForProperty:kABAddressProperty];
		int addressCount = [addresses count];
		int index = 0;

		while (addressCount > index) {
			NSDictionary * addressDict = [addresses valueAtIndex:index];
			NSString * addressString = [self dictionaryKeyForAddressDictionary:addressDict];
			
			if (! [locations objectForKey:addressString]) {
				// Look up address if we don't know its coordinates already
				NSString * theAddress = [self googleStringForAddressDictionary:addressDict];
				NSString * URLString = [NSString stringWithFormat:@"%@&q=%@", baseURL, addressString];
				NSURL * geocodeURL = [NSURL URLWithString:[URLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
				];
			
				NSURLRequest * geocodeRequest = [NSURLRequest requestWithURL:geocodeURL];
				NSURLResponse * geocodeResponse = nil;
				NSError * geocodeError = nil;

				// throttle Google queries
				if (previousLookup) {
					[NSThread sleepUntilDate:[previousLookup addTimeInterval:SECONDSBETWEENCOORDINATELOOKUPS]];
				}
				previousLookup = [NSDate date];
				
				NSData * requestAnswer = [NSURLConnection sendSynchronousRequest:geocodeRequest returningResponse:&geocodeResponse error:&geocodeError];
				
				
				NSString * resultString = [[[NSString alloc] initWithData:requestAnswer encoding:NSUTF8StringEncoding] autorelease];
				NSArray * resultArray = [resultString componentsSeparatedByString:@","];
				if ([[resultArray objectAtIndex:0] intValue] == 200) {
					NSNumber * accuracy = [NSNumber numberWithInt:[[resultArray objectAtIndex:1] intValue]];
					NSNumber * latitude = [NSNumber numberWithDouble:[[resultArray objectAtIndex:2] doubleValue]];
					NSNumber * longitude = [NSNumber numberWithDouble:[[resultArray objectAtIndex:3] doubleValue]];
				
					[locations setObject:[NSArray arrayWithObjects:accuracy, latitude, longitude, nil]  forKey:addressString];
					[self updateRelevantPeopleInfo];
				}
				else {
					[locations setObject:@"FAIL" forKey: addressString];
					NSLog(@"Geocoding query for '%@' failed with result %@", theAddress, [resultArray objectAtIndex:0]);
				}
			}
			index++;
		}
		[self setValue:[NSNumber numberWithInt:geocodingCurrentPosition + 1] forKey:@"geocodingCurrentPosition"];
		if (-[lastGeocodingProgressBarUpdate timeIntervalSinceNow] > 0.06) { // limit fps
			[geocodingProgressBar display];
			[self setValue:[NSDate date] forKey:@"lastGeocodingProgressBarUpdate"];
		}
		
	}
	
	[self saveLocations];
	[self setValue:[NSNumber numberWithInt:0] forKey:@"geocodingCurrentPosition"];
	[self setValue:[NSNumber numberWithBool:NO] forKey:@"geocodingRunning"];
	[geocodingProgressBar setHidden:YES];	
	[pool release];
}



/*
 Localises a number of strings, can return nil
*/
- (NSString *) localisedLabelName: (NSString*) label {
	NSString * localisedLabel;
	if ([label isEqualToString:kABHomeLabel]) {
		localisedLabel =  NSLocalizedString(@"Home", @"Home (Address Label)");
	}
	else if ([label isEqualToString: kABWorkLabel]) {
		localisedLabel = NSLocalizedString(@"Work", @"(Work (Address Label)");
	}
	else if ([label isEqualToString: kABOtherLabel]) {
		localisedLabel = nil; // NSLocalizedString(@"Other", @"Other (Address Label)");
	}
	else if ([label isEqualToString: kABPhoneMobileLabel]) {
		localisedLabel = NSLocalizedString(@"Mobile", @"Mobile (Phone Label)");
	}
/*	else if ([label isEqualToString:kABHomeLabel]) {
		localisedLabel =  NSLocalizedString(@"Home", @"Home (Phone Label)");
	}
	else if ([label isEqualToString: kABWorkLabel]) {
		localisedLabel = NSLocalizedString(@"Work", @"Work (Phone Label)");
	}
	else if ([label isEqualToString: kABOtherLabel]) {
		localisedLabel = NSLocalizedString(@"Other", @"Other (Phone Label)");
	}
	else if ([label isEqualToString:kABHomeLabel]) {
		localisedLabel =  NSLocalizedString(@"Home", @"Home (E-Mail Label)");
	}
	else if ([label isEqualToString: kABWorkLabel]) {
		localisedLabel = NSLocalizedString(@"Work", @"Work (E-Mail Label)");
	}
	else if ([label isEqualToString: kABOtherLabel]) {
		localisedLabel = NSLocalizedString(@"Other", @"Other (E-Mail Label)");
	}
*/
	else {
		localisedLabel = label;
	}
 
	return localisedLabel;
}





- (IBAction) do: (id) sender {
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"running"];
	[NSThread detachNewThreadSelector:@selector(do2:) toTarget:self withObject:sender];
}
	
	
- (void) do2:(id) sender {
	NSAutoreleasePool * myPool = [[NSAutoreleasePool alloc] init];
	BOOL error = NO;
	
	[self setValue:[NSNumber numberWithInt:0] forKey:@"currentPosition"];
	
#pragma mark -do2: Folder Setup
	
	NSFileManager * myFM = [NSFileManager defaultManager];
	NSString * appSupportPath = [NSSearchPathForDirectoriesInDomains( NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString * EAAppSupportPath = [appSupportPath stringByAppendingPathComponent:@"EarthAddresser"];
	if (! [myFM fileExistsAtPath: EAAppSupportPath]) {
		if (![myFM createDirectoryAtPath:EAAppSupportPath attributes:nil]) {
			[self error: NSLocalizedString(@"Couldn't create Application Support/EarthAddresser folder", @"Couldn't create Application Support/EarthAddresser folder")];
			error = YES;
		}
	}
	NSString * imagesPath = [EAAppSupportPath stringByAppendingPathComponent:@"Images"];
	if (!error &&  ![myFM fileExistsAtPath: imagesPath]) {
		if (![myFM createDirectoryAtPath:imagesPath attributes:nil]) {
			[self error: NSLocalizedString(@"Couldn't create Application Support/EarthAddresser/Images folder", @"Couldn't create Application Support/EarthAddresser/Images folder")];
			error = YES;
		}
	}
	

	if (!error) {
		NSArray * people = [self relevantPeople];

#pragma mark -do2: get people	
		if (people) {
			[self setValue:[NSNumber numberWithInt:[people count]] forKey:@"recordCount"];
			
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
			


#pragma mark -do2: Image Handling
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

				while (addressCount > index) {

#pragma mark -do2: Address Label			
					NSDictionary * theAddress = [addresses valueAtIndex:index];
					NSString * addressLocationKey = [self dictionaryKeyForAddressDictionary:theAddress];
					NSArray * addressCoordinates = [locations objectForKey:addressLocationKey];

					if ([addressCoordinates isKindOfClass:[NSArray class]]) {
						// only include addresses we resolved before
						NSString * addressName = [addresses labelAtIndex:index];
						NSString * addressLabel = [self localisedLabelName: addressName];

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
												
						NSXMLElement * pointElement = [NSXMLElement elementWithName:@"Point"];
						NSXMLElement * coordinatesElement = [NSXMLNode elementWithName:@"coordinates" stringValue:[NSString stringWithFormat:@"%@,%@", [addressCoordinates objectAtIndex:2], [addressCoordinates objectAtIndex:1]]];
						[pointElement addChild:coordinatesElement];
						[placemarkElement addChild:pointElement];
						
						
						
						NSMutableString * descriptionHTMLString = [NSMutableString string];
						NSMutableString * addressString = [self dictionaryKeyForAddressDictionary:theAddress];
						[addressString replaceOccurrencesOfString:@"\n" withString:@"<br />" options:NSLiteralSearch range:NSMakeRange(0, [addressString length])];
						
						if (fullImagePath) {
							[descriptionHTMLString appendFormat: @"<img src=\"file:%@\" alt=\"%@\" style=\"float:right;height:128px;margin-top:-2em;margin-left:1em;\">\n", 
							 [fullImagePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], 
							 NSLocalizedString (@"Photo", @"Photo (alt tag for image)")];		
						}
												
						[descriptionHTMLString appendFormat: @"%@<br /><a href=\"addressbook://%@\">%@</a>",
						 addressString,
						 uniqueID, 
						 NSLocalizedString(@"open in AddressBook", @"open in AddressBook")];			
					
#pragma mark -do2: EMail and Phone extras			
						if ([UDC valueForKeyPath:@"values.placemarkWithEMail"]) {
							// include e-mail addresses in placemark
							ABMultiValue * eMails = [person valueForProperty:kABEmailProperty];
							int eMailCount = [eMails count];
							if (eMailCount != 0) {
								int index = 0;
								[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> ", NSLocalizedString(@"E-Mail", @"E-Mail (appears in Google Earth Info Balloon)")];
								NSMutableArray * eMailArray = [NSMutableArray arrayWithCapacity:eMailCount];
								NSString * allEMails;
								while (index < eMailCount) {
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
									index++;
								}
								[descriptionHTMLString appendFormat:@"%@.", allEMails];
							}
						}
						

						if ([UDC valueForKeyPath:@"values.placemarkWithPhone"]) {
							// include e-mail addresses in placemark
							ABMultiValue * phones = [person valueForProperty:kABPhoneProperty];
							int phoneCount = [phones count];
							if (phoneCount != 0) {
								int index = 0;
								[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> ", NSLocalizedString(@"Phone", @"Phone (appears in Google Earth Info Balloon)")];
								NSMutableArray * phoneArray = [NSMutableArray arrayWithCapacity:phoneCount];
								NSString * allPhoneNumbers;
								while (index < phoneCount) {
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
									index++;
								}
								[descriptionHTMLString appendFormat:@"%@.", allPhoneNumbers];
							}
						}
	
						[descriptionHTMLString appendString:@"<br />"];
						
						NSXMLElement * descriptionElement = [NSXMLElement elementWithName:@"description" stringValue:descriptionHTMLString];
						[placemarkElement addChild: descriptionElement];
						NSXMLElement * snippetElement = [NSXMLElement elementWithName:@"Snippet"];
						[placemarkElement addChild:snippetElement];
						NSXMLElement * styleURLElement = [NSXMLElement elementWithName:@"styleUrl" stringValue:[@"#" stringByAppendingString:ID]];
						[placemarkElement addChild:styleURLElement];
						
						[myXML addChild: placemarkElement];
					}
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
			
				
#pragma mark -do2: Clean Up 	
		
			[self setValue:[NSNumber numberWithInt:0] forKey:@"currentPosition"];
			[self setValue:[NSNumber numberWithBool:NO] forKey:@"running"];
			[progressBar setHidden:YES];
		}
	}
	[myPool release];
}



#pragma mark AUXILIARIES

- (IBAction) showWarningInfo: (id) sender {
	[NSApp beginSheet:warningMessage modalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

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
	[self updateRelevantPeopleInfo];
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



/*
 update Checking
*/
- (IBAction) autoCheckForUpdates: (id) sender {
	
}

- (IBAction) menuCheckVersion: (id) sender {
	[VersionChecker checkVersionForURLString:UPDATEURL silent:NO];
}



@end

@implementation ABGroup (ESSortExtension) 

- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup {
	NSString * myName = [self valueForProperty:kABGroupNameProperty];
	NSString * theirName = [aGroup valueForProperty:kABGroupNameProperty];
	return [myName caseInsensitiveCompare:theirName];
}

@end
