// CarTableCell.m
//
// Kraftstoff


#import "CarTableCell.h"
#import "FuelCalculatorController.h"
#import "PickerImageView.h"
#import "AppDelegate.h"


// Standard cell geometry
static CGFloat const PickerViewCellWidth        = 290.0;
static CGFloat const PickerViewCellHeight       =  44.0;
static CGFloat const PickerViewCellMargin       =  10.0;
static CGFloat const PickerViewCellTextPosition =  13.0;

static NSInteger maximumDescriptionLength = 24;


// Attributes for custom PickerViews
static NSDictionary *prefixAttributesDict       = nil;
static NSDictionary *shadowPrefixAttributesDict = nil;

static NSDictionary *suffixAttributesDict       = nil;
static NSDictionary *shadowSuffixAttributesDict = nil;


@implementation CarTableCell

@synthesize carPicker;
@synthesize fetchedObjects;


+ (void)initialize
{
    if (prefixAttributesDict == nil)
    {
        CTFontRef helvetica24 = CTFontCreateWithName (CFSTR ("Helvetica-Bold"), 24, NULL);

        prefixAttributesDict = @{(NSString*)kCTFontAttributeName: (__bridge id)helvetica24,
                                 (NSString*)kCTForegroundColorAttributeName: (id)[[UIColor blackColor] CGColor]};

        shadowPrefixAttributesDict = @{(NSString*)kCTFontAttributeName: (__bridge id)helvetica24,
                                       (NSString*)kCTForegroundColorAttributeName: (id)[[UIColor whiteColor] CGColor]};

        CFRelease (helvetica24);
    }

    if (suffixAttributesDict == nil)
    {
        CTFontRef helvetica18 = CTFontCreateWithName (CFSTR ("Helvetica-Bold"), 18, NULL);

        suffixAttributesDict = @{(NSString*)kCTFontAttributeName: (__bridge id)helvetica18,
                                 (NSString*)kCTForegroundColorAttributeName: (id)[[UIColor darkGrayColor] CGColor]};

        shadowSuffixAttributesDict = @{(NSString*)kCTFontAttributeName: (__bridge id)helvetica18,
                                       (NSString*)kCTForegroundColorAttributeName: (id)[[UIColor whiteColor] CGColor]};

        CFRelease (helvetica18);
    }
}


- (void)finishConstruction
{
	[super finishConstruction];

    self.carPicker = [[UIPickerView alloc] init];

    carPicker.showsSelectionIndicator = YES;
    carPicker.dataSource              = self;
    carPicker.delegate                = self;

    self.textField.inputView = carPicker;
}


- (void)prepareForReuse
{
    [super prepareForReuse];

	self.fetchedObjects = nil;
    [carPicker reloadAllComponents];
}


- (void)configureForData: (id)dataObject viewController: (id)viewController tableView: (UITableView*)tableView indexPath: (NSIndexPath*)indexPath
{
	[super configureForData: dataObject viewController: viewController tableView: tableView indexPath: indexPath];

    // Array of possible cars
    self.fetchedObjects = [(NSDictionary*)dataObject objectForKey: @"fetchedObjects"];

    // Look for index of selected car
    NSManagedObject *managedObject = [self.delegate valueForIdentifier: self.valueIdentifier];
    NSUInteger initialIndex = [self.fetchedObjects indexOfObject: managedObject];

    if (initialIndex == NSNotFound)
        initialIndex = 0;

    // (Re-)configure car picker and select the initial item
    [carPicker reloadAllComponents];
    [carPicker selectRow: initialIndex inComponent: 0 animated: NO];

    [self selectCar: [fetchedObjects objectAtIndex: initialIndex]];
}


- (void)selectCar: (NSManagedObject*)managedObject
{
    // Update textfield in cell
    NSString *description = [NSString stringWithFormat: @"%@ %@",
                                [managedObject valueForKey: @"name"],
                                [managedObject valueForKey: @"numberPlate"]];

    if ([description length] > maximumDescriptionLength)
        description = [NSString stringWithFormat: @"%@%C",
                        [description substringToIndex: maximumDescriptionLength],
                        (unsigned short)0x2026];

    self.textFieldProxy.text = description;

    // Store selected car in delegate
    [self.delegate valueChanged: managedObject identifier: self.valueIdentifier];
}



#pragma mark -
#pragma mark UIPickerViewDataSource



- (NSInteger)numberOfComponentsInPickerView: (UIPickerView*)pickerView
{
    return 1;
}


- (NSInteger)pickerView: (UIPickerView*)pickerView numberOfRowsInComponent: (NSInteger)component
{
    return [self.fetchedObjects count];
}


- (void)pickerView: (UIPickerView*)pickerView didSelectRow: (NSInteger)row inComponent: (NSInteger)component
{
    [self selectCar: [fetchedObjects objectAtIndex: row]];
}



#pragma mark -
#pragma mark UIPickerViewDelegate



- (CGFloat)pickerView: (UIPickerView*)pickerView rowHeightForComponent: (NSInteger)component
{
    return PickerViewCellHeight;
}


- (CGFloat)pickerView: (UIPickerView*)pickerView widthForComponent: (NSInteger)component
{
    return PickerViewCellWidth;
}


- (CTLineRef)truncatedLineForName: (NSString*)name info: (NSString*)info shadow: (BOOL)shadow
{
    NSAttributedString *truncationString = [[NSAttributedString alloc]
                                                initWithString: [NSString stringWithFormat: @"%C", (unsigned short)0x2026]
                                                    attributes: (shadow) ? shadowSuffixAttributesDict : suffixAttributesDict];

    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]
                                                        initWithString: [NSString stringWithFormat: @"%@  %@", name, info]
                                                            attributes: (shadow) ? shadowSuffixAttributesDict : suffixAttributesDict];

    [attributedString setAttributes: (shadow) ? shadowPrefixAttributesDict : prefixAttributesDict
                              range: NSMakeRange (0, [name length])];

    CTLineRef line            = CTLineCreateWithAttributedString ((__bridge CFAttributedStringRef) attributedString);
    CTLineRef truncationToken = CTLineCreateWithAttributedString ((__bridge CFAttributedStringRef) truncationString);
    CTLineRef truncatedLine   = CTLineCreateTruncatedLine (line, PickerViewCellWidth - 2*PickerViewCellMargin, kCTLineTruncationEnd, truncationToken);

    CFRelease (line);
    CFRelease (truncationToken);


    return truncatedLine;
}


- (UIView*)pickerView: (UIPickerView*)pickerView viewForRow: (NSInteger)row forComponent: (NSInteger)component reusingView: (UIView*)view
{
    // Strings to be displayed
    NSManagedObject *managedObject = [fetchedObjects objectAtIndex: row];
    NSString *name = [managedObject valueForKey: @"name"];
    NSString *info = [managedObject valueForKey: @"numberPlate"];


    // Draw strings with attributes into image
    UIImage *image;

    UIGraphicsBeginImageContextWithOptions (CGSizeMake (PickerViewCellWidth, PickerViewCellHeight), NO, 0.0);
    {
        CGContextRef context = UIGraphicsGetCurrentContext ();

        CGContextTranslateCTM (context, 1, PickerViewCellHeight);
        CGContextScaleCTM (context, 1, -1);

        CTLineRef truncatedLine = [self truncatedLineForName: name info: info shadow: YES];
        CGContextSetTextPosition (context, PickerViewCellMargin, PickerViewCellTextPosition - 1);
        CTLineDraw (truncatedLine, context);
        CFRelease (truncatedLine);

        truncatedLine = [self truncatedLineForName: name info: info shadow: NO];
        CGContextSetTextPosition (context, PickerViewCellMargin, PickerViewCellTextPosition);
        CTLineDraw (truncatedLine, context);
        CFRelease (truncatedLine);

        image = UIGraphicsGetImageFromCurrentImageContext ();
    }
    UIGraphicsEndImageContext ();


    // Wrap with imageview
    PickerImageView *imageView;

    if (view != nil && [view isKindOfClass: [PickerImageView class]])
    {
        imageView       = (PickerImageView*)view;
        imageView.image = image;
    }
    else
    {
        imageView = [[PickerImageView alloc] initWithImage: image];
    }

    imageView.userInteractionEnabled = YES;
    imageView.pickerView = pickerView;
    imageView.rowIndex   = row;


    // Description for accessibility
    imageView.textualDescription = [NSString stringWithFormat: @"%@ %@", name, info];

    return imageView;
}

@end
