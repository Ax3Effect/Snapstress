#import <UIKit/UIKit.h>
#import	<CommonCrypto/CommonDigest.h>
#import "MBProgressHUD/MBProgressHUD.h"

NSInteger saveButtonIndex;
NSString* currentID;
MBProgressHUD *HUD;
NSString* systemLanguage;
NSString* access_token;
NSString* api_secret;

#define RUSSLANG [systemLanguage isEqualToString:@"ru"]

%ctor
{
    systemLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
    currentID = nil;
}

%hook UIActionSheet

- (id)initWithTitle:(id)arg1 delegate:(id)arg2 cancelButtonTitle:(id)arg3 destructiveButtonTitle:(id)arg4 otherButtonTitles:(id)arg5
{
	UIActionSheet* r = %orig;
	if(currentID != nil)
	{
        if(RUSSLANG) saveButtonIndex = [r addButtonWithTitle:@"Сохранить фото"];
        else saveButtonIndex = [r addButtonWithTitle:@"Save to Camera Roll"];
	}
	return r;
}

- (void)actionSheet:(UIActionSheet*) actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	%orig;
	if(buttonIndex == saveButtonIndex && currentID != nil)
    {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        HUD = [MBProgressHUD showHUDAddedTo:keyWindow animated:YES];
        HUD.animationType = MBProgressHUDAnimationZoom;
        if(RUSSLANG) HUD.labelText = @"Соединение..";
        else HUD.labelText = @"Connecting..";
        [self performSelectorInBackground:@selector(processSave) withObject:nil];
    }
	else
	{
		currentID = nil;
	}
}

%new
-(void) processSave
{
    UIImage* image = [self performSelector:@selector(imageWithMaxResolutionById:) withObject:currentID];
	if(image)
	{
		dispatch_async(dispatch_get_main_queue(),
        ^{
            if(RUSSLANG) HUD.labelText = @"Сохранение..";
            else HUD.labelText = @"Saving..";
        });
		UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
	}
    else
    {
        dispatch_async(dispatch_get_main_queue(),
        ^{
            if(RUSSLANG) HUD.labelText = @"Ошибка получения фото";
            else HUD.labelText = @"Photo load failed";
            [HUD hide:YES afterDelay:1.0];
        });
        currentID = nil;
    }
}

%new
- (NSString *) md5:(NSString *) input
{
    const char *cStr = [input UTF8String];
    unsigned char digest[16];
    CC_MD5( cStr, strlen(cStr), digest );
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return output;
}

%new
-(UIImage*)imageWithMaxResolutionById: (NSString*)pid
{
    NSLog(@"ID: %@", currentID);
    NSString* forSig = [NSString stringWithFormat:@"/method/photos.getById?photos=%@&version=5.34&photo_sizes=1&access_token=%@%@", pid, access_token, api_secret];
    NSString* sig = [self performSelector:@selector(md5:) withObject:forSig];
	NSString* url = [NSString stringWithFormat:@"https://api.vk.com/method/photos.getById?photos=%@&version=5.34&photo_sizes=1&access_token=%@&sig=%@", pid, access_token, sig];
    NSData* jsonData = [self performSelector:@selector(getDataFrom:) withObject:url];
    
    if(!jsonData) return nil;
    
	NSError *error = nil;
	NSDictionary* jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if(error) return nil;
	
    jsonObject = [[jsonObject objectForKey:@"response"] objectAtIndex:0];
    NSArray* sizes = [jsonObject objectForKey:@"sizes"];
    int maxsize = 0;
    NSString* link = [[NSString alloc] init];
    for (NSDictionary *size in sizes)
    {
        if([[size objectForKey:@"width"] intValue] >= maxsize)
		{
			link = [size objectForKey:@"src"];
			maxsize = [[size objectForKey:@"width"] intValue];
		}
    }
		
    dispatch_async(dispatch_get_main_queue(),
	^{
		if(RUSSLANG) HUD.labelText = @"Загрузка..";
        else HUD.labelText = @"Downloading..";
    });
    
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:link]]];
	return image;
}

%new
- (NSData *) getDataFrom:(NSString *)url
{
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:url]];
    NSError *error = [[NSError alloc] init];
    NSHTTPURLResponse *responseCode = nil;
    NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];
    if([responseCode statusCode] != 200)
        return nil;
    return oResponseData; 
}

%new
- (void) image: (UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo
{
    if(!error)
	{
        dispatch_async(dispatch_get_main_queue(),
        ^{
            if(RUSSLANG) HUD.labelText = @"Готово!";
            else HUD.labelText = @"Success!";
            [HUD hide:YES afterDelay:1.0];
        });
	}
	else
	{
        dispatch_async(dispatch_get_main_queue(),
        ^{
            if(RUSSLANG) HUD.labelText = @"Ошибка сохранения";
            else HUD.labelText = @"Saving error";
            [HUD hide:YES afterDelay:1.0];
        });
	}
	currentID = nil;
}
%end

void loadCurrentID(id cell)
{
    id model = [cell performSelector:@selector(model)];
    id modelRetain = [model performSelector:@selector(retain)];
    id currPhoto = [modelRetain performSelector:@selector(photo)];
    currentID = [[NSString alloc] initWithString:[currPhoto performSelector:@selector(keyForCacheList)]];
}

%hook CHPhotosViewerScrollCellView
- (void)postHeaderTableViewCell:(id)cell actionsButtonPressed:(id)arg2
{
    loadCurrentID(cell);
    %orig;
}
%end

%hook CHBasePhotosTableViewController
- (void)postHeaderTableViewCell:(id)cell actionsButtonPressed:(id)arg2
{
    loadCurrentID(cell);
    %orig;
}
%end

%hook VKAccessToken
-(NSString*) accessToken
{
    NSString* r = %orig;
    access_token = r;
    return r;
}

-(NSString*) secret
{
    NSString* r = %orig;
    api_secret = r;
    return r;
}
%end

