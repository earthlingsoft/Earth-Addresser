//
//  ESCreateKMLOperation.m
//  Earth Addresser
//
//  Created by Sven on 26.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESCreateKMLOperation.h"
#import "Magic.h"
#import "ESAddressHelper.h"
#import "ESTerm.h"
#import <AddressBook/AddressBook.h>
#import <AddressBook/ABAddressBookC.h>


@implementation ESCreateKMLOperation

NSString * const ESKMLgenericStylePrefix = @"EarthAddresser-generic-";
NSString * const ESKMLGenericHomeIcon = @"home";
NSString * const ESKMLGenericWorkIcon = @"work";



- (void) main {
	self.progress = .000001;
	
	if (self.people && self.people.count > 0) {
		self.addressLabelGroups = [NSMutableDictionary dictionary];
		self.KML = [self createKML];
		self.KMLDocumentElement = [self createKMLDocument];
		[[self.KML rootElement] addChild:self.KMLDocumentElement];

		for (ABPerson * person in self.people) {
			if (self.isCancelled) {
				break;
			}
			[self processPerson:person];
		}
		
		if ([[UDC valueForKeyPath:@"values.groupByAddressLabel"] boolValue]) {
			// sort and add folders of contacts for each group to main XML tree
			NSArray * sortedLabels = [[self.addressLabelGroups allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
			
			for (id label in sortedLabels) {
				[self.KMLDocumentElement addChild:self.addressLabelGroups[label]];
			}
		}
		
		self.progress = [self.people count];
		
		if (!self.isCancelled) {
			[self writeKML:self.KML];
		}
		else {
			self.owner.doneMessage = NSLocalizedString(@"Placemark generation was cancelled.", @"Status message after cancelled KML file creation.");
		}
	}
}



- (void (^)(void)) completionBlock {
	[self.owner endBusy];
	self.owner.KMLOperation = nil;
}



#pragma mark KML

/*
 Writes passed KML XML Document to file on Desktop.
*/
- (void) writeKML:(NSXMLDocument *)KML {
	NSString * const KMLPathFormat = [@"~/Desktop/%@" stringByExpandingTildeInPath];
	
	NSString * KMLFileName = [NSLocalizedString(@"Filename", @"KML Dateiname") stringByAppendingPathExtension:@"kml"];
	NSString * KMLFilePath = [NSString stringWithFormat:KMLPathFormat, KMLFileName];
	int i = 2;
	
	while ([[NSFileManager defaultManager] fileExistsAtPath:KMLFilePath]) {
		KMLFileName = [[NSString stringWithFormat:@"%@ %i", NSLocalizedString(@"Filename", @"KML Dateiname"), i] stringByAppendingPathExtension:@"kml"];
		KMLFilePath = [NSString stringWithFormat:KMLPathFormat, KMLFileName];
		i++;
	}
	
	[[KML XMLData] writeToFile:KMLFilePath atomically:YES];
	self.owner.doneMessage = [NSString stringWithFormat:NSLocalizedString(@"File '%@' on your Desktop", @"Status message after successful creation of the KML file."), KMLFileName];
}



/*
 Creates placemarks for all addresses and additional information of person.
 Adds them to the file or prepares them for addition to address groups depending on user defaults.
*/
- (void) processPerson:(ABPerson *)person {
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
			[self.KMLDocumentElement addChild:styleXML];
			fullImagePath = [self fullPNGImagePathForName:ID];
		}
	}


	//
	// now cycle through the various addresses and create placemarks
	ABMultiValue * addresses = [person valueForProperty:kABAddressProperty];
	NSUInteger addressCount = [addresses count];

#pragma mark loop over addresses
	for (NSUInteger addressIndex = 0; addressIndex < addressCount; addressIndex++) {
		NSDictionary * theAddress = [addresses valueAtIndex:addressIndex];
		NSString * label = [addresses labelAtIndex:addressIndex];
		NSString * addressLocationKey = [self.owner.addressHelper keyForAddress:theAddress];
		NSDictionary * addressCoordinates = self.owner.locations[addressLocationKey];
		
		if ([addressCoordinates isKindOfClass:[NSDictionary class]]) {
			// only include addresses we resolved before
#pragma mark Address Label
			NSString * addressLabel = [self localisedLabelName:label];
			NSString * normalisedLabel = [addressLabel capitalizedString];
			
			NSString * nameAndLabel;
			if (addressLabel) {
				nameAndLabel = [name stringByAppendingFormat:@" (%@)", normalisedLabel];
			}
			else {
				nameAndLabel = name;
			}
			
			
#pragma mark Address String
			NSXMLElement * placemarkElement = [NSXMLElement elementWithName:@"Placemark"];
			NSXMLElement * nameElement;
			if ([[UDC valueForKeyPath:@"values.placemarkWithLabel"] boolValue]) {
				nameElement = [NSXMLNode elementWithName:@"name" stringValue:nameAndLabel];
			}
			else {
				nameElement = [NSXMLNode elementWithName:@"name" stringValue:name];
			}
			[placemarkElement addChild:nameElement];
			
			NSString * visibilityString = ([self isOldLabel:normalisedLabel] ? @"0" : @"1");
			NSXMLElement * visibilityElement = [NSXMLNode elementWithName:@"visibility" stringValue:visibilityString];
			[placemarkElement addChild:visibilityElement];
			
			NSXMLElement * pointElement = [NSXMLElement elementWithName:@"Point"];
			NSXMLElement * coordinatesElement = [NSXMLNode elementWithName:@"coordinates" stringValue:[NSString stringWithFormat:@"%@,%@", addressCoordinates[@"lon"], addressCoordinates[@"lat"]]];
			[pointElement addChild:coordinatesElement];
			[placemarkElement addChild:pointElement];
			
			
			NSMutableString * descriptionHTMLString = [NSMutableString string];
			
			if (fullImagePath) {
				[descriptionHTMLString appendFormat:@"<img src=\"file:%@\" alt=\"%@\" style=\"float:right;height:128px;margin-top:-1em;margin-left:1em;\">\n",
				 [fullImagePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
				 NSLocalizedString (@"Photo", @"Photo (alt tag for image)")];
			}
			
			if ([[UDC valueForKeyPath:@"values.placemarkWithAddress"] boolValue]) {
				NSArray * addressComponents = [self.owner.addressHelper componentsForAddress:theAddress];
				NSString * addressString = [addressComponents componentsJoinedByString:@"<br />"];
				[descriptionHTMLString appendFormat:@"%@", addressString];
			}
			
			if ([[UDC valueForKeyPath:@"values.placemarkWithAddressBookLink"] boolValue]) {
				[descriptionHTMLString appendFormat:@"<br /><a href=\"addressbook://%@\">%@</a>",
				 uniqueID,
				 NSLocalizedString(@"open in AddressBook", @"open in AddressBook")];
			}
			
			[descriptionHTMLString appendString:@"<hr style='width:20em;clear:all;visibility:hidden;' />"];
			
			
#pragma mark Related People
			if ([[UDC valueForKeyPath:@"values.placemarkWithContacts"] boolValue]) {
				ABMultiValue * people = [person valueForProperty:kABRelatedNamesProperty];
				NSUInteger peopleCount = [people count];
				if (peopleCount != 0) {
					[descriptionHTMLString appendString:@"<br />"];
					for (NSUInteger personIndex = 0; personIndex < peopleCount; personIndex++) {
						NSString * personName = [people valueAtIndex:personIndex];
						NSString * personLabel = [self localisedLabelName:[people labelAtIndex:personIndex]];
						if (personName != nil && personLabel != nil) {
							[descriptionHTMLString appendFormat:@"<br /><strong>%@:</strong> %@", personLabel, personName];
						}
					}
				}
			}
			
			
#pragma mark EMail
			if ([[UDC valueForKeyPath:@"values.placemarkWithEMail"] boolValue]) {
				// include non-old e-mail addresses in placemark
				ABMultiValue * eMails = [person valueForProperty:kABEmailProperty];
				NSUInteger eMailCount = [eMails count];
				if (eMailCount != 0) {
					[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> ", NSLocalizedString(@"E-Mail", @"E-Mail (appears in Google Earth Info Balloon)")];
					NSMutableArray * eMailArray = [NSMutableArray arrayWithCapacity:eMailCount];
					NSString * allEMails = nil;
					for (NSUInteger eMailIndex = 0; eMailIndex < eMailCount; eMailIndex++) {
						NSString * eMailLabel = [eMails labelAtIndex:eMailIndex];
						if (![self isOldLabel:eMailLabel]) {
							NSString * eMailAddress = [eMails valueAtIndex:eMailIndex];
							if (eMailAddress) {
								NSString * localisedLabel = [self localisedLabelName:eMailLabel];
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
					}
					if (allEMails) {
						[descriptionHTMLString appendFormat:@"%@.", allEMails];
					}
				}
			}

			
#pragma mark Website
			if ([[UDC valueForKeyPath:@"values.placemarkWithWeblinks"] boolValue]) {
				// include non-old web-addresses in placemark
				ABMultiValue * weblinks = [person valueForProperty:kABURLsProperty];
				NSUInteger weblinkCount = [weblinks count];
				if (weblinkCount != 0) {
					[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> ", NSLocalizedString(@"Web", @"Web (appears in Google Earth Info Balloon)")];
					NSMutableArray * weblinkArray = [NSMutableArray arrayWithCapacity:weblinkCount];
					NSString * allWeblinks = nil;
					for (NSUInteger weblinkIndex = 0; weblinkIndex < weblinkCount; weblinkIndex++) {
						NSString * weblinkLabel = [weblinks labelAtIndex:weblinkIndex];
						if (![self isOldLabel:weblinkLabel]) {
							NSString * weblink = [weblinks valueAtIndex:weblinkIndex];
							if (weblink) {
								NSString * localisedLabel = [self localisedLabelName:weblinkLabel];
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
					}
					if (allWeblinks) {
						[descriptionHTMLString appendFormat:@"%@.", allWeblinks];
					}
				}
			}
			
			
#pragma mark Phone
			if ([[UDC valueForKeyPath:@"values.placemarkWithPhone"] boolValue]) {
				// include non-old phone numbers in placemark
				ABMultiValue * phones = [person valueForProperty:kABPhoneProperty];
				NSUInteger phoneCount = [phones count];
				if (phoneCount != 0) {
					[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> ", NSLocalizedString(@"Phone", @"Phone (appears in Google Earth Info Balloon)")];
					NSMutableArray * phoneArray = [NSMutableArray arrayWithCapacity:phoneCount];
					NSString * allPhoneNumbers = nil;
					for (NSUInteger phoneIndex = 0; phoneIndex < phoneCount; phoneIndex++) {
						NSString * phoneLabel = [phones labelAtIndex:phoneIndex];
						if (![self isOldLabel:phoneLabel]) {
							NSString * phoneNumber = [phones valueAtIndex:phoneIndex];
							if (phoneNumber) {
								NSString * localisedLabel = [self localisedLabelName:phoneLabel];
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
					}
					if (allPhoneNumbers) {
						[descriptionHTMLString appendFormat:@"%@.", allPhoneNumbers];
					}
				}
			}
			
			
#pragma mark Notes
			if ([[UDC valueForKeyPath:@"values.placemarkWithNotes"] boolValue]) {
				NSString * noteString = [person valueForProperty:kABNoteProperty];
				if ( [noteString length] > 0 ) {
					NSMutableString * noteStringWithNewlines = [noteString mutableCopy];
					[noteStringWithNewlines replaceOccurrencesOfString:@"\n" withString:@"<br />" options:NSLiteralSearch range:NSMakeRange(0, [noteStringWithNewlines length])];
					[noteStringWithNewlines replaceOccurrencesOfString:@"\r" withString:@"<br />" options:NSLiteralSearch range:NSMakeRange(0, [noteStringWithNewlines length])];
					[descriptionHTMLString appendFormat:@"<br /><br /><strong>%@:</strong> %@", NSLocalizedString(@"Note", @"Note (appears in Google Earth Info Balloon)"), noteStringWithNewlines];
				}
			}
			
			[descriptionHTMLString appendString:@"<br />"];
			
			NSXMLElement * descriptionElement = [NSXMLElement elementWithName:@"description" stringValue:descriptionHTMLString];
			[placemarkElement addChild:descriptionElement];
			NSXMLElement * snippetElement = [NSXMLElement elementWithName:@"Snippet"];
			[placemarkElement addChild:snippetElement];
			
			
#pragma mark Style, Image
			NSXMLElement * styleURLElement = nil;
			if (imageData) {
				// use custom pin style if we have an image for the person
				styleURLElement = [NSXMLElement elementWithName:@"styleUrl" stringValue:[@"#" stringByAppendingString:ID]];
			}
			else {
				// if we don't have and image for the person, use own generic home and work images unless the hidden noHomeWorkIcons preference is set to YES
				BOOL wantImages = ![[UDC valueForKeyPath:@"values.noHomeWorkIcons"] boolValue];
				if (wantImages) {
					if ([addressLabel isEqualToString:kABAddressHomeLabel]) {
						styleURLElement = [NSXMLElement elementWithName:@"styleUrl" stringValue:[NSString stringWithFormat:@"#%@%@", ESKMLgenericStylePrefix, ESKMLGenericHomeIcon]];
					}
					else if ([addressLabel isEqualToString:kABAddressWorkLabel]) {
						styleURLElement = [NSXMLElement elementWithName:@"styleUrl" stringValue:[NSString stringWithFormat:@"#%@%@", ESKMLgenericStylePrefix, ESKMLGenericWorkIcon]];
					}
				}
				// don't specify a style if there is neither an image nor a home or work address
			}
			if (styleURLElement) {
				[placemarkElement addChild:styleURLElement];
			}
			
			
#pragma mark Grouping
			if ([[UDC valueForKeyPath:@"values.groupByAddressLabel"] boolValue]) {
				// create a group for each address label and add the addresses accordingly
				NSXMLElement * addressGroup = self.addressLabelGroups[normalisedLabel];
				
				if (addressGroup == nil) {
					// group doesn't exist yet => create it
					addressGroup = [NSXMLElement elementWithName:@"Folder"];
					
					[addressGroup addChild:[NSXMLNode elementWithName:@"name" stringValue:normalisedLabel]];
					self.addressLabelGroups[normalisedLabel] = addressGroup;
					
					if ([self isOldLabel:normalisedLabel]) {
						// this is the group for old addresses
						[addressGroup addChild:[NSXMLNode elementWithName:@"visibility" stringValue:@"0"]];
					}
				}
				// add element to this group
				[addressGroup addChild:placemarkElement];
				// groups will be sorted and added to the main XML tree after the loop has finished
			}
			else {
				// add element to the main group immediately
				[self.KMLDocumentElement addChild:placemarkElement];
			}
		}
	}
	
	self.progress += 1;
}



/*
 Returns blank KML XML Document.
*/
- (NSXMLDocument *) createKML {
	NSXMLElement * KMLElement = [NSXMLElement elementWithName:@"kml"];
	[KMLElement addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"http://earth.google.com/kml/2.1"]];
	
	NSXMLDocument * KML = [[NSXMLDocument alloc] initWithRootElement:KMLElement];
	[KML setCharacterEncoding:@"utf-8"];
	
	return KML;
}



/*
 Returns KML Document element with title and generic styles.
*/
- (NSXMLElement *) createKMLDocument {
	NSXMLElement * KMLDocument = [NSXMLElement elementWithName:@"Document"];
	
	NSXMLNode * documentID = [NSXMLNode attributeWithName:@"id" stringValue:[[NSUUID UUID] UUIDString]];
	[KMLDocument addAttribute:documentID];
	
	[KMLDocument addChild:[NSXMLNode elementWithName:@"name" stringValue:NSLocalizedString(@"Addresses", @"Addresses")]];
	
	// Add generic home and work place styles
	NSXMLElement * genericStyle = [self genericStyleNamed:@"home"];
	if (genericStyle) {
		[KMLDocument addChild:genericStyle];
	}
	
	genericStyle = [self genericStyleNamed:@"work"];
	if (genericStyle) {
		[KMLDocument addChild:genericStyle];
	}
	
	return KMLDocument;
}





#pragma mark KML Styles

/*
 Creates generic style element for the given name
	Requires: PNG image for the name in Resources
	Returns: XML Element for the style (and writes image to Application support)
*/
- (NSXMLElement *) genericStyleNamed:(NSString *)name {
	NSXMLElement * style = nil;
	
	NSString * pathToImage = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
	NSData * imageData = [NSData dataWithContentsOfFile:pathToImage];
	if (imageData) {
		style = [self createStyleForImageData:imageData withID:[ESKMLgenericStylePrefix stringByAppendingString:name]];
	}
	
	return style;
}



/*
 Writes the given image to Application Support and creates the corresponding style XML.
 Returns nil iff any of that fails.
*/
- (NSXMLElement *) createStyleForImageData:(NSData *)imageData withID:(NSString *)ID {
	NSXMLElement * styleElement = nil;
	
	// only execute if we haven’t been cancelled (mainly to avoid duplicate error messages)
	if (!self.isCancelled) {
		// ensure folders to our image exist
		NSString * fullImagePath = [self fullPNGImagePathForName:ID];
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
					[iconElement addChild:hrefElement];
					[iconStyleElement addChild:iconElement];
					
					NSXMLElement * sizeElement = [NSXMLNode elementWithName:@"scale" stringValue:[[UDC valueForKeyPath:@"values.imageSize"] stringValue]];
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
	} // endif !self.isCancelled
	
	return styleElement;
}





#pragma mark Images

/*
 Returns absolute path to PNG image in Application Support with the name passed to it.
 Ensures that the folder hierarchy on the way there exists.
*/
- (NSString *) fullPNGImagePathForName:(NSString *)name {
	NSString * fullImagePath = nil;
	NSString * imagesFolderPath = [self imagesFolderPath];
	if (imagesFolderPath != nil) {
		fullImagePath = [imagesFolderPath stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
	}
	return fullImagePath;
}



/*
 Returns absolute path to our Images folder in Application Support.
*/
- (NSString *) imagesFolderPath {
	NSFileManager * myFM = [NSFileManager defaultManager];
	NSString * imagesFolderPath = [self.owner.EAApplicationSupportURL URLByAppendingPathComponent:@"Images"].path;
	
	if (![myFM fileExistsAtPath:imagesFolderPath]) { // create folders if needed
		NSError * error;
		if (![myFM createDirectoryAtPath:imagesFolderPath withIntermediateDirectories:YES attributes:nil error:&error]) {
			[self cancel];
			NSAlert * alert = [NSAlert alertWithError:error];
			[alert performSelectorOnMainThread:@selector(runModal) withObject:nil waitUntilDone:YES];
			imagesFolderPath = nil;
		}
	}
	
	return imagesFolderPath;
}





#pragma mark Labels

/*
 Localises Address Boook labels, could return nil.
*/
- (NSString *) localisedLabelName:(NSString *)labelName {
	return (NSString *)CFBridgingRelease(ABCopyLocalizedPropertyOrLabel((__bridge CFStringRef)labelName));
}



/*
 Returns whether the passed label is marked as indicating old information.
*/
- (BOOL) isOldLabel:(NSString *)label {
	BOOL isOldLabel = FALSE;
	NSString * uppercaseLabel = [label uppercaseString];
	for (ESTerm * oldLabel in self.owner.oldLabels) {
		if (oldLabel.active == YES && [[oldLabel.string uppercaseString] isEqualToString:uppercaseLabel]) {
			isOldLabel = YES;
			break;
		}
	}
	return isOldLabel;
}

@end
