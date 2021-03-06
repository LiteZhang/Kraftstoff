// SwitchTableCell.m
//
// Kraftstoff


#import "SwitchTableCell.h"

static CGFloat const margin = 8.0;


@implementation SwitchTableCell

@synthesize valueSwitch;
@synthesize valueLabel;
@synthesize valueIdentifier;
@synthesize delegate;


- (void)finishConstruction
{
	[super finishConstruction];

    // No highlight on touch
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // Create switch
    self.valueSwitch = [[UISwitch alloc] initWithFrame: CGRectZero];
    [valueSwitch addTarget: self action: @selector (switchToggledAction:) forControlEvents: UIControlEventValueChanged];

	[self.contentView addSubview: valueSwitch];


    // Configure the alternate textlabel
    self.valueLabel = [[UILabel alloc] initWithFrame: CGRectZero];

    valueLabel.font             = [UIFont systemFontOfSize: [UIFont labelFontSize] - 2];
	valueLabel.textAlignment    = UITextAlignmentRight;
	valueLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	valueLabel.backgroundColor  = [UIColor clearColor];
	valueLabel.textColor        = [UIColor blackColor];
	valueLabel.shadowColor      = [UIColor whiteColor];
	valueLabel.shadowOffset     = CGSizeMake (0, 1);

    valueLabel.hidden                 = YES;
	valueLabel.userInteractionEnabled = NO;

    [self.contentView addSubview: valueLabel];

    // Configure the default textlabel
    UILabel *label = self.textLabel;

	label.textAlignment        = UITextAlignmentLeft;
	label.font                 = [UIFont boldSystemFontOfSize: [UIFont labelFontSize]];
	label.highlightedTextColor = [UIColor blackColor];
	label.textColor            = [UIColor blackColor];
	label.shadowColor          = [UIColor whiteColor];
	label.shadowOffset         = CGSizeMake (0, 1);
}


- (void)configureForData: (id)dataObject
          viewController: (id)viewController
               tableView: (UITableView*)tableView
               indexPath: (NSIndexPath*)indexPath
{
	[super configureForData: dataObject viewController: viewController tableView: tableView indexPath: indexPath];

	self.textLabel.text   = [(NSDictionary*)dataObject objectForKey: @"label"];
    self.delegate         = viewController;
    self.valueIdentifier  = [(NSDictionary*)dataObject objectForKey: @"valueIdentifier"];

    BOOL isON = [[self.delegate valueForIdentifier: self.valueIdentifier] boolValue];

    [self.valueSwitch setOn: isON];
    [self.valueLabel setText: _I18N (isON ? @"Yes" : @"No")];

    BOOL showAlternate = [[self.delegate valueForIdentifier: @"showValueLabel"] boolValue];

    self.valueSwitch.hidden =  showAlternate;
    self.valueLabel.hidden  = !showAlternate;
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    // Text label on the left
    CGFloat labelWidth = [self.textLabel.text sizeWithFont: self.textLabel.font].width;
    CGFloat height     = self.contentView.bounds.size.height;
	CGFloat width      = self.contentView.bounds.size.width;

    self.textLabel.frame = CGRectMake (margin, 0.0, labelWidth, height - 1);

    // UISwitch
    CGRect valueFrame = self.valueSwitch.frame;
    self.valueSwitch.frame = CGRectMake (width - margin - valueFrame.size.width,
                                         floor ((height - valueFrame.size.height)/2),
                                         valueFrame.size.width,
                                         valueFrame.size.height);

    // Alternate for UISwitch
    CGFloat alternateHeight = [self.valueLabel.text sizeWithFont: self.valueLabel.font].height;
    self.valueLabel.frame = CGRectMake (width - margin - 100.0, floor ((height - alternateHeight)/2), 100.0, alternateHeight);
}


- (void)switchToggledAction: (UISwitch*)sender
{
    BOOL isON = [sender isOn];

    [self.delegate valueChanged: @(isON) identifier: self.valueIdentifier];
    [self.valueLabel setText: _I18N (isON ? @"Yes" : @"No")];
}

@end
