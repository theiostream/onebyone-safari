#import <WebKit/WebHistory.h>
#import <WebKit/WebHistoryItem.h>
#import <Foundation2/NSCalendarDate.h>

// I should rewrite the whole HistoryTableViewController.

/*
	TODO:
	FIXME: Improve recent searches code
	TO_DO_LATER: Add toolbar to Recent searches
	TO_DO_LATER: Search history
*/

// **************************
// ***** DECLARATIONS *****

// BrowserController (handle saved searches and a lot more)
@interface BrowserController : NSObject
+ (id)sharedBrowserController;
- (NSArray *)recentSearches;
- (void)saveRecentSearches:(id)searches;
- (UIToolbar *)buttonBar;
@end

// AddressView (the whole address view, including recent searches)
@interface AddressView : UIView
- (int)_sectionIndexForRecentSearches;
@end

// History (handler for history)
@interface History : NSObject
+ (id)sharedHistory;
+ (NSURL *)historyURL;
- (WebHistory *)webHistory;
- (id)itemAtIndex:(NSUInteger)index fromDate:(NSCalendarDate *)date; // seriously, this is an id-returning method.
@end

// HistoryTableViewController (display Safari history)
@interface HistoryTableViewController : UITableViewController
- (NSCalendarDate *)date;
- (void)startEditingWithItem;
@end

// BookmarksNavigationController (hold bookmarks/history)
@interface BookmarksNavigationController : UINavigationController
- (HistoryTableViewController *)topHistoryTableViewController;
@end

// Globals
static BOOL editing = NO;
static BOOL fuckyousafari = NO;
static UIBarButtonItem *item = nil;
static NSDictionary *historyPrefs = nil;


// ***** END DECLARATIONS *****
// **************************

// **************************
// ***** HELPERS *****

static void HEUpdatePrefs() {
	NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/am.theiostre.henhancer.plist"];
	if (!plist) return;

	historyPrefs = [plist retain];
}

static void HEReloadPrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	HEUpdatePrefs();
}

static BOOL HEGetBoolPref(NSString *key, BOOL def) {
	if (!historyPrefs) return def;

	NSNumber *v = [historyPrefs objectForKey:key];
	return v ? [v boolValue] : def;
}

static BOOL HEItemIsToday(id date, BOOL flag) {
	if ([date isKindOfClass:[NSCalendarDate class]]) {
		BOOL eq = [date dayOfCommonEra] == [[NSCalendarDate calendarDate] dayOfCommonEra];
		return flag ? !eq : eq;
	}
		
	return NO;
}

static id HEHistoryItemForIndex(NSUInteger index, NSCalendarDate *date) {
	return [[%c(History) sharedHistory] itemAtIndex:index fromDate:date];
}

// ***** END HELPERS *****
// **************************

// ***** HOOKS *****
// **************************

%hook History
- (NSArray *)_topLevelItems {
	NSArray *orig = %orig;
	
	if (fuckyousafari)
		return [[self webHistory] orderedLastVisitedDays];
	
	else if (!HEGetBoolPref(@"HEEarlierToday", NO)) {
		NSMutableArray *olderDates = [NSMutableArray array];
		for (id obj in orig)
			if (HEItemIsToday(obj, YES))
				[olderDates addObject:obj];
		
		NSArray *todayItems = [[self webHistory] orderedItemsLastVisitedOnDay:[NSCalendarDate calendarDate]];
		
		NSMutableArray *ret = [[NSMutableArray arrayWithArray:todayItems] retain];
		[ret addObjectsFromArray:olderDates];
		return ret;
	}
		
	return orig;
}
%end

%hook BookmarksNavigationController
// Add new "Edit" toolbar item
- (NSArray *)toolbarItems {
	NSMutableArray *items = [NSMutableArray arrayWithArray:%orig];
	HistoryTableViewController *ctrl = [self topHistoryTableViewController];
	UIToolbar *toolbar = [[%c(BrowserController) sharedBrowserController] buttonBar];
	
	if ([ctrl isEqual:[self topViewController]]) {
		BOOL clear = HEGetBoolPref(@"HEClearButton", YES);
		BOOL edit = HEGetBoolPref(@"HEEditButton", YES);
		
		if (!clear && !edit) {
			[toolbar setHidden:YES];
			return [NSArray array];
		}
		
		if (!clear)
			[items removeLastObject];
		
		if (edit) {
			UIBarButtonItem *space = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:Nil] autorelease];
			[items addObject:space];
			
			item = [[[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStyleBordered target:ctrl action:@selector(startEditingWithItem)] autorelease];
			[items addObject:item];
		}
	}
	
	else
		[toolbar setHidden:NO];
	
	return items;
}

// Called when "Clean" bar button is tapped
- (void)removeAllHistoryItems {
	if (editing) [[self topHistoryTableViewController] startEditingWithItem];
	%orig;
}
%end

%hook HistoryTableViewController
// Called when "Done" navigation bar button is pressed
- (void)_done {
	if (editing) [self startEditingWithItem];
	%orig;
	
	[[[%c(BrowserController) sharedBrowserController] buttonBar] setHidden:NO];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editing) [self startEditingWithItem];
	%orig;
}

%new
- (void)startEditingWithItem {
	[item setTitle:(editing ? @"Edit" : @"Stop")];
	[item setTintColor:(editing ? nil : [UIColor blueColor])];
	
	editing = !editing;
	[[self tableView] setEditing:editing animated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger orig = %orig;
	if (orig == 0) {
		fuckyousafari = YES;
		NSUInteger dayCount = [[[[%c(History) sharedHistory] webHistory] orderedLastVisitedDays] count];
		if (dayCount > 0)
			return dayCount;
	}
	
	fuckyousafari = NO;
	return orig;
}

// Stop "Earlier today" from being deleted, which makes absolutely no sense.
%new
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	id item = HEHistoryItemForIndex(indexPath.row, [self date]);
	if (HEItemIsToday(item, NO))
		return NO;
	
	return YES;
}

%new
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSLog(@"[HistoryEnhancer] At History table view section %i", indexPath.section);
		
		WebHistory *h = [[%c(History) sharedHistory] webHistory];
		id item = HEHistoryItemForIndex(indexPath.row, [self date]);
		
		NSArray *items;
		if ([item isKindOfClass:[NSCalendarDate class]])
			items = [[[h orderedItemsLastVisitedOnDay:item] copy] autorelease];
		else
			items = [NSArray arrayWithObject:item];
		
		[h removeItems:items];
		[h saveToURL:[%c(History) historyURL] error:nil];
		
		[tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
	}
}
%end

// FIXME: Improve this by interacting directly with the source for the tableView
static NSInteger s_cnt = -1;
%hook AddressView
- (void)_hideCompletions {
	%orig;
	s_cnt = -1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (s_cnt == -1) s_cnt = %orig;
	return s_cnt;
}

%new
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	// it somehow crashes if the searchfield's text != @"" and you try to delete items.
	return (
		indexPath.section == [self _sectionIndexForRecentSearches] &&
		[[MSHookIvar<UITextField *>(self, "_searchTextField") text] isEqualToString:@""]
	);
}

%new
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		id browserController = [%c(BrowserController) sharedBrowserController];
		
		NSMutableArray *re = [NSMutableArray arrayWithArray:[browserController recentSearches]];
		[re removeObject:[[[tableView cellForRowAtIndexPath:indexPath] textLabel] text]];
		[browserController saveRecentSearches:re];
		
		s_cnt--;
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
	}
}
%end

// ***** END HOOKS *****
// **************************

%ctor {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	HEUpdatePrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
									NULL,
									&HEReloadPrefs,
									CFSTR("am.theiostre.henhancer.reload"),
									NULL,
									0);
									
	[pool drain];
}