// FuelCalculatorController.h
//
// Kraftstoff


#import "AppDelegate.h"
#import "AppWindow.h"
#import "FuelCalculatorController.h"
#import "FuelEventController.h"
#import "CarTableCell.h"
#import "ConsumptionTableCell.h"
#import "DateEditTableCell.h"
#import "NumberEditTableCell.h"
#import "SwitchTableCell.h"

#import "NSDate+Kraftstoff.h"
#import "UIViewController+Kraftstoff.h"


typedef enum
{
    FCDistanceRow = 1,
    FCPriceRow    = 2,
    FCAmountRow   = 4,
    FCAllDataRows = 7,
} FuelCalculatorDataRow;


@implementation FuelCalculatorController

@synthesize managedObjectContext;
@synthesize fetchedResultsController;

@synthesize restoredSelectionIndex;
@synthesize car;
@synthesize lastChangeDate;
@synthesize date;
@synthesize distance;
@synthesize price;
@synthesize fuelVolume;
@synthesize filledUp;

@synthesize doneButton;
@synthesize saveButton;



#pragma mark -
#pragma mark View Lifecycle



- (void)viewDidLoad
{
    [super viewDidLoad];


    // Title bar
    self.doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                                                                    target: self
                                                                    action: @selector (endEditingMode:)];
    
    self.saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemSave
                                                                    target: self
                                                                    action: @selector (saveAction:)];

    self.title = _I18N (@"Fill-Up");

    
    // Pre-iOS6: add shadow layer onto the background image view
    if ([AppDelegate isRunningOS6] == NO)
    {
        [self.view.layer
         insertSublayer: [AppDelegate shadowWithFrame: CGRectMake (0.0, 0.0, self.view.frame.size.width, NavBarShadowHeight)
                                           darkFactor: 0.5
                                          lightFactor: 150.0 / 255.0
                                        fadeDownwards: YES]
         atIndex: 0];
    }

    self.tableView.backgroundView = nil;

    
    // Fetch the cars
    self.managedObjectContext     = [[AppDelegate sharedDelegate] managedObjectContext];
    self.fetchedResultsController = [AppDelegate fetchedResultsControllerForCarsInContext: self.managedObjectContext];
    self.fetchedResultsController.delegate = self;

    
    // Table contents
    self.constantRowHeight = NO;

    [self createTableContentsWithAnimation: UITableViewRowAnimationNone];
    [self.tableView reloadData];

    [self updateSaveButtonState];


    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (localeChanged:)
               name: NSCurrentLocaleDidChangeNotification
             object: nil];

    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (willEnterForeground:)
               name: UIApplicationWillEnterForegroundNotification
             object: nil];

    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector (handleShake:)
               name: kraftstoffDeviceShakeNotification
             object: nil];
}


- (void)viewDidAppear: (BOOL)animated
{
    [super viewDidAppear: animated];

    NSString *imageName = [AppDelegate isIPhone5] ? @"TablePattern-568h" : @"TablePattern";
    
    [[AppDelegate sharedDelegate]
        setWindowBackground: [[UIImage imageNamed: imageName] resizableImageWithCapInsets: UIEdgeInsetsZero]
                   animated: animated];
}


- (void)viewWillDisappear: (BOOL)animated
{
    [super viewWillDisappear: animated];

    NSString *imageName = [AppDelegate isIPhone5] ? @"TableBackground-568h" : @"TableBackground";
    
    [[AppDelegate sharedDelegate]
         setWindowBackground: [UIImage imageNamed: imageName]
                    animated: animated];
}



#pragma mark -
#pragma mark iOS 6 State Restoration



#define kSRCalculatorSelectedIndex    @"FuelCalculatorSelectedIndex"
#define kSRCalculatorConvertSheet     @"FuelCalculatorConvertSheet"
#define kSRCalculatorEditing          @"FuelCalculatorEditing"


- (void)encodeRestorableStateWithCoder: (NSCoder*)coder
{
    NSIndexPath *indexPath = restoredSelectionIndex;

    if (indexPath == nil)
        indexPath = [self.tableView indexPathForSelectedRow];

    if (indexPath)
        [coder encodeObject: indexPath forKey: kSRCalculatorSelectedIndex];

    [coder encodeBool: isShowingConvertSheet forKey: kSRCalculatorConvertSheet];
    [coder encodeBool: self.editing forKey: kSRCalculatorEditing];
    
    [super encodeRestorableStateWithCoder: coder];
}


- (void)decodeRestorableStateWithCoder: (NSCoder*)coder
{
    restoredSelectionIndex = [coder decodeObjectForKey: kSRCalculatorSelectedIndex];
    isShowingConvertSheet  = [coder decodeBoolForKey: kSRCalculatorConvertSheet];
    
    if ([coder decodeBoolForKey: kSRCalculatorEditing])
    {
        [self setEditing: YES animated: NO];

        if (isShowingConvertSheet)
        {
            [self showOdometerConversionAlert];
        }
        else
        {
            [self selectRowAtIndexPath: restoredSelectionIndex];
            restoredSelectionIndex = nil;
        }
    }

    [super decodeRestorableStateWithCoder: coder];
}



#pragma mark -
#pragma mark Modeswitching for Table Rows



- (void)setEditing: (BOOL)enabled animated: (BOOL)animated
{
    if (self.editing != enabled)
    {
        UITableViewRowAnimation animation = (animated) ? UITableViewRowAnimationFade : UITableViewRowAnimationNone;
        
        [super setEditing: enabled animated: animated];
        
        if (enabled)
        {
            self.navigationItem.leftBarButtonItem  = doneButton;
            self.navigationItem.rightBarButtonItem = nil;

            [self removeSectionAtIndex: 1 withAnimation: animation];
        }
        else
        {
            self.navigationItem.leftBarButtonItem  = nil;
            
            if ([self consumptionRowNeeded])
                [self createConsumptionRowWithAnimation: animation];

            [self updateSaveButtonState];
        }
        
        if (!animated)
            [self.tableView reloadData];
    }
}



#pragma mark -
#pragma mark Shake Events



- (void)handleShake: (id)object
{
    if ([self isCurrentVisible] == NO)
        return;

    if (self.editing)
        return;

    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if ([distance compare: zero] == NSOrderedSame && [fuelVolume compare: zero] == NSOrderedSame && [price compare: zero] == NSOrderedSame)
        return;

    [UIView animateWithDuration: 0.3
                     animations: ^{

                         [self removeSectionAtIndex: 1 withAnimation: UITableViewRowAnimationFade];
                     }
                     completion: ^(BOOL finished){

                         NSDate *now = [NSDate date];

                         [self valueChanged: [NSDate dateWithoutSeconds: now] identifier: @"date"];
                         [self valueChanged: now  identifier: @"lastChangeDate"];
                         [self valueChanged: zero identifier: @"distance"];
                         [self valueChanged: zero identifier: @"price"];
                         [self valueChanged: zero identifier: @"fuelVolume"];
                         [self valueChanged: @YES identifier: @"filledUp"];

                         [self recreateTableContentsWithAnimation: UITableViewRowAnimationLeft];
                         [self updateSaveButtonState];
                     }];
}



#pragma mark -
#pragma mark Creating the Table Rows



- (BOOL)consumptionRowNeeded
{
    NSDecimalNumber *zero = [NSDecimalNumber zero];

    if (self.editing)
        return NO;
    
    if (! ([distance compare: zero] == NSOrderedDescending && [fuelVolume compare: zero] == NSOrderedDescending))
        return NO;
    
    return YES;
}


- (void)createConsumptionRowWithAnimation: (UITableViewRowAnimation)animation;
{
    // Conversion units
    KSDistance        odometerUnit;
    KSVolume          fuelUnit;
    KSFuelConsumption consumptionUnit;

    if (self.car)
    {
        odometerUnit    = [[self.car valueForKey: @"odometerUnit"]        integerValue];
        fuelUnit        = [[self.car valueForKey: @"fuelUnit"]            integerValue];
        consumptionUnit = [[self.car valueForKey: @"fuelConsumptionUnit"] integerValue];
    }
    else
    {
        odometerUnit    = [AppDelegate distanceUnitFromLocale];
        fuelUnit        = [AppDelegate volumeUnitFromLocale];
        consumptionUnit = [AppDelegate fuelConsumptionUnitFromLocale];
    }


    // Compute the average consumption
    NSDecimalNumber *cost = [fuelVolume decimalNumberByMultiplyingBy: price];

    NSDecimalNumber *liters      = [AppDelegate litersForVolume: fuelVolume withUnit: fuelUnit];
    NSDecimalNumber *kilometers  = [AppDelegate kilometersForDistance: distance withUnit: odometerUnit];
    NSDecimalNumber *consumption = [AppDelegate consumptionForKilometers: kilometers Liters: liters inUnit: consumptionUnit];

    NSString *consumptionString = [NSString stringWithFormat: @"%@ %@ %@ %@",
                                        [[AppDelegate sharedCurrencyFormatter]   stringFromNumber: cost],
                                        _I18N (@"/"),
                                        [[AppDelegate sharedFuelVolumeFormatter] stringFromNumber: consumption],
                                        [AppDelegate consumptionUnitString: consumptionUnit]];


    // Substrings for highlighting
    NSArray *highlightStrings = @[[[AppDelegate sharedCurrencyFormatter] currencySymbol],
                                  [AppDelegate consumptionUnitString: consumptionUnit]];

    [self addSectionAtIndex: 1 withAnimation: animation];

    [self addRowAtIndex: 0
              inSection: 1
              cellClass: [ConsumptionTableCell class]
               cellData: @{@"label": consumptionString,
                           @"highlightStrings": highlightStrings}
          withAnimation: animation];
}


- (void)createDataRows: (FuelCalculatorDataRow)rowMask withAnimation: (UITableViewRowAnimation)animation
{
    KSDistance odometerUnit;
    KSVolume fuelUnit;

    if (self.car)
    {
        odometerUnit = [[self.car valueForKey: @"odometerUnit"] integerValue];
        fuelUnit     = [[self.car valueForKey: @"fuelUnit"]     integerValue];
    }
    else
    {
        odometerUnit = [AppDelegate distanceUnitFromLocale];
        fuelUnit     = [AppDelegate volumeUnitFromLocale];
    }


    int rowOffset = ([self.fetchedResultsController.fetchedObjects count] < 2) ? 1 : 2;

    if (rowMask & FCDistanceRow)
    {
        if (distance == nil)
            self.distance = [NSDecimalNumber decimalNumberWithDecimal:
                                [[[NSUserDefaults standardUserDefaults] objectForKey: @"recentDistance"]
                                    decimalValue]];

        [self addRowAtIndex: 0 + rowOffset
                  inSection: 0
                  cellClass: [NumberEditTableCell class]
                   cellData: @{@"label":           _I18N (@"Distance"),
                               @"suffix":          [@" " stringByAppendingString: [AppDelegate odometerUnitString: odometerUnit]],
                               @"formatter":       [AppDelegate sharedDistanceFormatter],
                               @"valueIdentifier": @"distance"}
              withAnimation: animation];
    }

    if (rowMask & FCPriceRow)
    {
        if (price == nil)
            self.price = [NSDecimalNumber decimalNumberWithDecimal:
                            [[[NSUserDefaults standardUserDefaults] objectForKey: @"recentPrice"]
                                decimalValue]];

        [self addRowAtIndex: 1 + rowOffset
                  inSection: 0
                  cellClass: [NumberEditTableCell class]
                   cellData: @{@"label":              [AppDelegate fuelPriceUnitDescription: fuelUnit],
                               @"formatter":          [AppDelegate sharedEditPreciseCurrencyFormatter],
                               @"alternateFormatter": [AppDelegate sharedPreciseCurrencyFormatter],
                               @"valueIdentifier":    @"price"}
              withAnimation: animation];
    }

    if (rowMask & FCAmountRow)
    {
        if (fuelVolume == nil)
            self.fuelVolume = [NSDecimalNumber decimalNumberWithDecimal:
                                [[[NSUserDefaults standardUserDefaults] objectForKey: @"recentFuelVolume"]
                                    decimalValue]];

        [self addRowAtIndex: 2 + rowOffset
                  inSection: 0
                  cellClass: [NumberEditTableCell class]
                   cellData: @{@"label":           [AppDelegate fuelUnitDescription: fuelUnit discernGallons: NO pluralization: YES],
                               @"suffix":          [@" " stringByAppendingString: [AppDelegate fuelUnitString: fuelUnit]],
                               @"formatter":       KSVolumeIsMetric (fuelUnit)
                                                        ? [AppDelegate sharedFuelVolumeFormatter]
                                                        : [AppDelegate sharedPreciseFuelVolumeFormatter],
                               @"valueIdentifier": @"fuelVolume"}
              withAnimation: animation];
    }
}


- (void)createTableContentsWithAnimation: (UITableViewRowAnimation)animation
{
    [self addSectionAtIndex: 0 withAnimation: animation];


    // Car selector (optional)
    self.car = nil;
    
    if ([self.fetchedResultsController.fetchedObjects count] > 0)
    {
        self.car = [[AppDelegate sharedDelegate] managedObjectForModelIdentifier: [[NSUserDefaults standardUserDefaults] objectForKey: @"preferredCarID"]];

        if (self.car == nil)
            self.car = [self.fetchedResultsController.fetchedObjects objectAtIndex: 0];

        if ([self.fetchedResultsController.fetchedObjects count] > 1)
            [self addRowAtIndex: 0
                      inSection: 0
                      cellClass: [CarTableCell class]
                       cellData: @{@"label":           _I18N (@"Car"),
                                   @"valueIdentifier": @"car",
                                   @"fetchedObjects":  self.fetchedResultsController.fetchedObjects}
                  withAnimation: animation];
    }


    // Date selector
    if (date == nil)
        self.date = [NSDate dateWithoutSeconds: [NSDate date]];

    if (lastChangeDate == nil)
        self.lastChangeDate = [NSDate date];

    [self addRowAtIndex: (self.car) ? 1 : 0
              inSection: 0
              cellClass: [DateEditTableCell class]
               cellData: @{@"label":           _I18N (@"Date"),
                           @"formatter":       [AppDelegate sharedDateTimeFormatter],
                           @"valueIdentifier": @"date",
                           @"valueTimestamp":  @"lastChangeDate",
                           @"autorefresh":     @YES}
          withAnimation: animation];


    // Data rows for distance, price, fuel amount
    [self createDataRows: FCAllDataRows withAnimation: animation];

    
    // Full-fillup selector
    self.filledUp = [[[NSUserDefaults standardUserDefaults] objectForKey: @"recentFilledUp"] boolValue];

    if (self.car != nil)
        [self addRowAtIndex: (self.car) ? 5 : 4
                  inSection: 0
                  cellClass: [SwitchTableCell class]
                   cellData: @{@"label":           _I18N (@"Full Fill-Up"),
                               @"valueIdentifier": @"filledUp"}
              withAnimation: animation];


    // Consumption info (optional)
    if ([self consumptionRowNeeded])
        [self createConsumptionRowWithAnimation: animation];
}



#pragma mark -
#pragma mark Updating the Table Rows



- (void)recreateTableContentsWithAnimation: (UITableViewRowAnimation)animation
{
    // Update model contents
    if ([tableSections count])
        [self removeAllSectionsWithAnimation:   UITableViewRowAnimationNone];
    else
        animation = UITableViewRowAnimationNone;

    [self createTableContentsWithAnimation: UITableViewRowAnimationNone];

    // Update the tableview
    if (animation == UITableViewRowAnimationNone)
        [self.tableView reloadData];
    else
        [self.tableView reloadSections: [NSIndexSet indexSetWithIndexesInRange: NSMakeRange (0, [self.tableView numberOfSections])]
                      withRowAnimation: animation];
}


- (void)recreateDataRowsWithPreviousCar: (NSManagedObject*)oldCar
{
    // Replace data rows in the internal data model
    for (int row = 4; row >= 2; row--)
        [self removeRowAtIndex: row inSection: 0 withAnimation: UITableViewRowAnimationNone];

    [self createDataRows: FCAllDataRows withAnimation: UITableViewRowAnimationNone];

    // Update the tableview
    BOOL odoChanged  = [[oldCar   valueForKey: @"odometerUnit"] integerValue]
                    != [[self.car valueForKey: @"odometerUnit"] integerValue];

    BOOL fuelChanged = KSVolumeIsMetric ([[oldCar   valueForKey: @"fuelUnit"] integerValue])
                    != KSVolumeIsMetric ([[self.car valueForKey: @"fuelUnit"] integerValue]);

    UITableViewRowAnimation animation = UITableViewRowAnimationRight;
    int count = 0;

    for (int row = 2; row <= 4; row++)
    {
        if ((row == 2 && odoChanged) || (row != 2 && fuelChanged))
        {
            animation = UITableViewRowAnimationRight + (count % 2);
            count ++;
        }
        else
            animation = UITableViewRowAnimationNone;

        [self.tableView reloadRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: row inSection: 0]]
                              withRowAnimation: animation];
    }

    // Reload date row too to get colors updates
    [self.tableView reloadRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: 1 inSection: 0]]
                          withRowAnimation: UITableViewRowAnimationNone];
}


- (void)recreateDistanceRowWithAnimation: (UITableViewRowAnimation)animation
{
    int rowOffset = ([self.fetchedResultsController.fetchedObjects count] < 2) ? 1 : 2;

    // Replace distance row in the internal data model
    [self removeRowAtIndex: rowOffset inSection: 0 withAnimation: UITableViewRowAnimationNone];
    [self createDataRows: FCDistanceRow withAnimation: UITableViewRowAnimationNone];

    // Update the tableview
    if (animation != UITableViewRowAnimationNone)
        [self.tableView reloadRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: rowOffset
                                                                     inSection: 0]]
                              withRowAnimation: animation];
    else
        [self.tableView reloadData];
}



#pragma mark -
#pragma mark Locale Handling



- (void)localeChanged: (id)object
{
    NSIndexPath *previousSelection = [self.tableView indexPathForSelectedRow];
    
    [self dismissKeyboardWithCompletion: ^{
        
        [self recreateTableContentsWithAnimation: UITableViewRowAnimationNone];
        [self selectRowAtIndexPath: previousSelection];
    }];
}



#pragma mark -
#pragma mark System Events



- (void)willEnterForeground: (NSNotification*)notification
{
    if ([tableSections count] == 0 || keyboardIsVisible == YES)
        return;

    // Last update must be longer than 5 minutes ago
    NSTimeInterval noChangeInterval;

    if (self.lastChangeDate)
        noChangeInterval = [[NSDate date] timeIntervalSinceDate: self.lastChangeDate];
    else
        noChangeInterval = -1;

    if (lastChangeDate == nil || noChangeInterval >= 300 || noChangeInterval < 0)
    {
        // Reset date to current time
        NSDate *now         = [NSDate date];
        self.date           = [NSDate dateWithoutSeconds: now];
        self.lastChangeDate = now;

        // Update table
        int rowOffset = ([self.fetchedResultsController.fetchedObjects count] < 2) ? 0 : 1;

        [self.tableView reloadRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: rowOffset inSection: 0]]
                              withRowAnimation: UITableViewRowAnimationNone];
    }
}



#pragma mark -
#pragma mark Programatically Selecting Table Rows



- (void)activateTextFieldAtIndexPath: (NSIndexPath*)indexPath
{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath: indexPath];
    UITextField *field = nil;

    if ([cell isKindOfClass: [CarTableCell class]])
        field = [(CarTableCell*)cell textField];

    else if ([cell isKindOfClass: [DateEditTableCell class]])
        field = [(DateEditTableCell*)cell textField];

    else if ([cell isKindOfClass: [NumberEditTableCell class]])
        field = [(NumberEditTableCell*)cell textField];

    field.userInteractionEnabled = YES;
    [field becomeFirstResponder];
}


- (void)selectRowAtIndexPath: (NSIndexPath*)path
{
    if (path)
    {
        [self.tableView selectRowAtIndexPath: path animated: NO scrollPosition: UITableViewScrollPositionNone];
        [self tableView: self.tableView didSelectRowAtIndexPath: path];
    }
}



#pragma mark -
#pragma mark Storing Information in the Database



- (void)saveAction: (id)sender
{
    self.navigationItem.rightBarButtonItem = nil;
        
    [UIView animateWithDuration: 0.3
                     animations: ^{
                         
                         // Remove consumption row
                         [self removeSectionAtIndex: 1 withAnimation: UITableViewRowAnimationFade];
                     }

                     completion: ^(BOOL finished){

                         // Add new event object
                         changeIsUserDriven = YES;

                         [AppDelegate addToArchiveWithCar: car
                                                     date: date
                                                 distance: distance
                                                    price: price
                                               fuelVolume: fuelVolume
                                                 filledUp: filledUp
                                   inManagedObjectContext: self.managedObjectContext
                                      forceOdometerUpdate: NO];

                         // Reset calculator table
                         NSDecimalNumber *zero = [NSDecimalNumber zero];

                         [self valueChanged: zero identifier: @"distance"];
                         [self valueChanged: zero identifier: @"price"];
                         [self valueChanged: zero identifier: @"fuelVolume"];
                         [self valueChanged: @YES identifier: @"filledUp"];

                         [[AppDelegate sharedDelegate] saveContext: self.managedObjectContext];
                     }];
}


- (void)updateSaveButtonState
{
    BOOL saveValid = YES;

    if (car == nil)
        saveValid = NO;
    
    else if ([distance compare: [NSDecimalNumber zero]] == NSOrderedSame || [fuelVolume compare: [NSDecimalNumber zero]] == NSOrderedSame)
        saveValid = NO;

    else if (date == nil || [AppDelegate managedObjectContext: self.managedObjectContext containsEventWithCar: car andDate: date])
        saveValid = NO;

    self.navigationItem.rightBarButtonItem = saveValid ? saveButton : nil;
}



#pragma mark -
#pragma mark Conversion for Odometer



- (BOOL)needsOdometerConversionSheet
{
    // A simple heuristics when to ask for distance cobversion
    if (!self.car)
        return NO;
    
    // 1.) entered "distance" must be larger than car odometer
    KSDistance odometerUnit = [[car valueForKey: @"odometerUnit"] integerValue];
    
    NSDecimalNumber *rawDistance  = [AppDelegate kilometersForDistance: distance withUnit: odometerUnit];
    NSDecimalNumber *convDistance = [rawDistance decimalNumberBySubtracting: [car valueForKey: @"odometer"]];
    
    if ([[NSDecimalNumber zero] compare: convDistance] != NSOrderedAscending)
        return NO;
    
    
    // 2.) consumption with converted distances is more 'logical'
    NSDecimalNumber *liters = [AppDelegate litersForVolume: fuelVolume withUnit: [[car valueForKey: @"fuelUnit"] integerValue]];
    
    if ([[NSDecimalNumber zero] compare: liters] != NSOrderedAscending)
        return NO;
    
    NSDecimalNumber *rawConsumption  = [AppDelegate consumptionForKilometers: rawDistance
                                                                      Liters: liters
                                                                      inUnit: KSFuelConsumptionLitersPer100km];
    
    if ([rawConsumption isEqual: [NSDecimalNumber notANumber]])
        return NO;
    
    NSDecimalNumber *convConsumption = [AppDelegate consumptionForKilometers: convDistance
                                                                      Liters: liters
                                                                      inUnit: KSFuelConsumptionLitersPer100km];
    
    if ([convConsumption isEqual: [NSDecimalNumber notANumber]])
        return NO;
    
    NSDecimalNumber *avgConsumption = [AppDelegate consumptionForKilometers: [car valueForKey: @"distanceTotalSum"]
                                                                     Liters: [car valueForKey: @"fuelVolumeTotalSum"]
                                                                     inUnit: KSFuelConsumptionLitersPer100km];
    
    NSDecimalNumber *loBound, *hiBound;
    
    if ([avgConsumption isEqual: [NSDecimalNumber notANumber]])
    {
        loBound = [NSDecimalNumber decimalNumberWithMantissa:  2 exponent: 0 isNegative: NO];
        hiBound = [NSDecimalNumber decimalNumberWithMantissa: 20 exponent: 0 isNegative: NO];
    }
    else
    {
        loBound = [avgConsumption decimalNumberByMultiplyingBy: [NSDecimalNumber decimalNumberWithMantissa: 5 exponent: -1 isNegative: NO]];
        hiBound = [avgConsumption decimalNumberByMultiplyingBy: [NSDecimalNumber decimalNumberWithMantissa: 5 exponent:  0 isNegative: NO]];
    }
    
    
    // conversion only when rawConsumtion <= lowerBound
    if ([rawConsumption compare: loBound] == NSOrderedDescending)
        return NO;
    
    // conversion only when lowerBound <= convConversion <= highBound
    if ([convConsumption compare: loBound] == NSOrderedAscending || [convConsumption compare: hiBound] == NSOrderedDescending)
        return NO;
    
    
    // 3.) the event must be the youngest one
    NSArray *youngerEvents = [AppDelegate objectsForFetchRequest: [AppDelegate fetchRequestForEventsForCar: car
                                                                                                 afterDate: date
                                                                                               dateMatches: NO
                                                                                    inManagedObjectContext: managedObjectContext]
                                          inManagedObjectContext: managedObjectContext];
    
    if ([youngerEvents count] > 0)
        return NO;
    
    
    // => ask for a conversion
    return YES;
}


- (void)showOdometerConversionAlert
{
    KSDistance odometerUnit = [[car valueForKey: @"odometerUnit"] integerValue];

    NSDecimalNumber *rawDistance  = [AppDelegate kilometersForDistance: distance withUnit: odometerUnit];
    NSDecimalNumber *convDistance = [rawDistance decimalNumberBySubtracting: [car valueForKey: @"odometer"]];

    NSNumberFormatter *distanceFormatter = [AppDelegate sharedDistanceFormatter];

    NSString *rawButton = [NSString stringWithFormat: @"%@ %@",
                                [distanceFormatter stringFromNumber: [AppDelegate distanceForKilometers: rawDistance  withUnit: odometerUnit]],
                                [AppDelegate odometerUnitString: odometerUnit]];

    NSString *convButton = [NSString stringWithFormat: @"%@ %@",
                                [distanceFormatter stringFromNumber: [AppDelegate distanceForKilometers: convDistance withUnit: odometerUnit]],
                                [AppDelegate odometerUnitString: odometerUnit]];

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle: _I18N (@"Convert from odometer reading into distance? Please choose the distance driven:")
                                                       delegate: self
                                              cancelButtonTitle: rawButton
                                         destructiveButtonTitle: convButton
                                              otherButtonTitles: nil];
    
    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;

    isShowingConvertSheet = YES;
    [sheet showFromTabBar: self.tabBarController.tabBar];
}


- (void)actionSheet: (UIActionSheet*)actionSheet clickedButtonAtIndex: (NSInteger)buttonIndex
{
    isShowingConvertSheet = NO;

    if (buttonIndex != actionSheet.cancelButtonIndex)
    {
        // Replace distance in table with difference to car odometer
        KSDistance odometerUnit = [[car valueForKey: @"odometerUnit"] integerValue];
        NSDecimalNumber *rawDistance  = [AppDelegate kilometersForDistance: distance withUnit: odometerUnit];
        NSDecimalNumber *convDistance = [rawDistance decimalNumberBySubtracting: [car valueForKey: @"odometer"]];
        
        self.distance = [AppDelegate distanceForKilometers: convDistance withUnit: odometerUnit];
        [self valueChanged: self.distance identifier: @"distance"];
        
        [self recreateDistanceRowWithAnimation: UITableViewRowAnimationRight];
    }
    
    [self setEditing: NO animated: YES];
}



#pragma mark -
#pragma mark Leaving Editing Mode



- (IBAction)endEditingMode: (id)sender
{
    [self dismissKeyboardWithCompletion: ^{

        if ([self needsOdometerConversionSheet])
            [self showOdometerConversionAlert];
        else
            [self setEditing: NO animated: YES];
    }];
}



#pragma mark -
#pragma mark EditablePageCellDelegate



- (id)valueForIdentifier: (NSString*)valueIdentifier
{
    if ([valueIdentifier isEqualToString: @"car"])
        return car;
    else if ([valueIdentifier isEqualToString: @"date"])
        return date;
    else if ([valueIdentifier isEqualToString: @"lastChangeDate"])
        return lastChangeDate;
    else if ([valueIdentifier isEqualToString: @"distance"])
        return distance;
    else if ([valueIdentifier isEqualToString: @"price"])
        return price;
    else if ([valueIdentifier isEqualToString: @"fuelVolume"])
        return fuelVolume;
    else if ([valueIdentifier isEqualToString: @"filledUp"])
        return @(filledUp);

    return nil;
}


- (void)valueChanged: (id)newValue identifier: (NSString*)valueIdentifier
{
    if ([newValue isKindOfClass: [NSDate class]])
    {
        if ([valueIdentifier isEqualToString: @"date"])
            self.date = [NSDate dateWithoutSeconds: (NSDate*)newValue];

        else if ([valueIdentifier isEqualToString: @"lastChangeDate"])
            self.lastChangeDate = (NSDate*)newValue;
    }

    else if ([newValue isKindOfClass: [NSDecimalNumber class]])
    {
        NSString *recentKey = nil;

        if ([valueIdentifier isEqualToString: @"distance"])
        {
            self.distance = (NSDecimalNumber*)newValue;
            recentKey     = @"recentDistance";
        }

        else if ([valueIdentifier isEqualToString: @"fuelVolume"])
        {
            self.fuelVolume = (NSDecimalNumber*)newValue;
            recentKey       = @"recentFuelVolume";
        }

        else if ([valueIdentifier isEqualToString: @"price"])
        {
            self.price = (NSDecimalNumber*)newValue;
            recentKey  = @"recentPrice";
        }

        if (recentKey)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            [defaults setObject: newValue forKey: recentKey];
            [defaults synchronize];
        }
    }

    else if ([valueIdentifier isEqualToString: @"filledUp"])
    {
        self.filledUp = [newValue boolValue];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        [defaults setObject: newValue forKey: @"recentFilledUp"];
        [defaults synchronize];
    }

    else if ([valueIdentifier isEqualToString: @"car"])
    {
        if (! [self.car isEqual: newValue])
        {
            NSManagedObject *oldCar = self.car;

            self.car = (NSManagedObject*)newValue;
            [self recreateDataRowsWithPreviousCar: oldCar];
        }

        if ([[self.car objectID] isTemporaryID] == NO)
        {
            AppDelegate *appDelegate = [AppDelegate sharedDelegate];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            [defaults setObject: [appDelegate modelIdentifierForManagedObject: self.car] forKey: @"preferredCarID"];
            [defaults synchronize];
        }
    }
}



- (BOOL)valueValid: (id)newValue identifier: (NSString*)valueIdentifier
{
    // Validate only when there is a car for saving
    if (self.car == nil)
        return YES;

    // Date must be collision free
    if ([newValue isKindOfClass: [NSDate class]])
        if ([valueIdentifier isEqualToString: @"date"])
            if ([AppDelegate managedObjectContext: self.managedObjectContext containsEventWithCar: self.car andDate: (NSDate*)newValue] == YES)
                return NO;

    // DecimalNumbers <= 0.0 are invalid
    if ([newValue isKindOfClass: [NSDecimalNumber class]])
        if (![valueIdentifier isEqualToString: @"price"])
            if ([(NSDecimalNumber*)newValue compare: [NSDecimalNumber zero]] != NSOrderedDescending)
                return NO;

    return YES;
}



#pragma mark -
#pragma mark NSFetchedResultsControllerDelegate



- (void)controllerDidChangeContent: (NSFetchedResultsController*)controller
{
    [self recreateTableContentsWithAnimation: changeIsUserDriven ? UITableViewRowAnimationRight : UITableViewRowAnimationNone];
    [self updateSaveButtonState];

    changeIsUserDriven = NO;
}



#pragma mark -
#pragma mark UITableViewDataSource



- (NSString*)tableView: (UITableView*)aTableView titleForHeaderInSection: (NSInteger)section
{
    return nil;
}



#pragma mark -
#pragma mark UITableViewDelegate



- (NSIndexPath*)tableView: (UITableView*)tableView willSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];

    if ([cell isKindOfClass: [SwitchTableCell class]] || [cell isKindOfClass: [ConsumptionTableCell class]])
        return nil;

    [self setEditing: YES animated: YES];
    return indexPath;
}



- (void)tableView: (UITableView*)tableView didSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
    [self activateTextFieldAtIndexPath: indexPath];

    [tableView scrollToRowAtIndexPath: indexPath
                     atScrollPosition: UITableViewScrollPositionMiddle
                             animated: YES];
}



#pragma mark -
#pragma mark Memory Management



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


@end
