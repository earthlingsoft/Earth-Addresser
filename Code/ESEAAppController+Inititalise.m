//
//  ESEAAppController+StandardDefaults.m
//  Earth Addresser
//
//  Created by Sven on 29.07.14.
//  Copyright (c) 2014 earthlingsoft. All rights reserved.
//

#import "ESEAAppController.h"
#import "ESTerm.h"

@implementation ESEAAppController (Initialise)

+ (void) initialize {
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
		@"placemarkWithAddressBookLink": @NO,
		@"placemarkWithContacts": @NO,
		@"placemarkWithNotes": @NO,
		@"noHomeWorkIcons": @NO,
		@"hasReadInfo": @NO,
		@"groupByAddressLabel": @NO,
		@"secondsBetweenCoordinateLookups": @1.2,
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
				@{ESTermStringKey:@"Locale ", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"University of", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"Universität ", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"Flat ", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"App ", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"App.", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"Apt ", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"Apt.", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"Pièce ", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"#", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"P.O. Box", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"P.O.Box", ESTermActiveKey:@YES},
				@{ESTermStringKey:@"C.P.", ESTermActiveKey:@YES},
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

@end
