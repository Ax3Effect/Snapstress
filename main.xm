#import <UIKit/UIKit.h>
#import	<CommonCrypto/CommonDigest.h>
#import "MBProgressHUD.h"
#import "CHPhoto.h"

NSString* currentID;
NSString* currentAccess_key;
int currentOwnerID;
int currentPhotoID;

int saveButtonIndex;
int addButtonIndex;
MBProgressHUD* HUD;
BOOL RUSSLANG;
NSString* access_token;
NSString* api_secret;

%ctor
{
    RUSSLANG = [[[NSLocale preferredLanguages] objectAtIndex:0] isEqualToString:@"ru"];
    currentID = nil;
}

%hook UIActionSheet

- (id)initWithTitle:(id)arg1 delegate:(id)arg2 cancelButtonTitle:(id)arg3 destructiveButtonTitle:(id)arg4 otherButtonTitles:(id)arg5
{
    UIActionSheet* r = %orig;
    if(currentID)
    {
        saveButtonIndex = (RUSSLANG) ? [r addButtonWithTitle:@"Сохранить фото"] : [r addButtonWithTitle:@"Save to Camera Roll"];
        addButtonIndex = (RUSSLANG) ? [r addButtonWithTitle:@"Сохранить в альбом"] : [r addButtonWithTitle:@"Save to album"];
    }
    return r;
}

- (void) actionSheet:(UIActionSheet*) actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    %orig;
    if(buttonIndex == saveButtonIndex && currentID != nil)
    {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        HUD = [%c(MBProgressHUD) showHUDAddedTo:keyWindow animated:YES];
        HUD.animationType = MBProgressHUDAnimationZoom;
        HUD.labelText = (RUSSLANG) ? @"Соединение.." : @"Connecting..";
        [self performSelectorInBackground:@selector(processSave) withObject:nil];
    }
    else if(buttonIndex == addButtonIndex && currentID != nil)
    {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        HUD = [%c(MBProgressHUD) showHUDAddedTo:keyWindow animated:YES];
        HUD.animationType = MBProgressHUDAnimationZoom;
        HUD.labelText = (RUSSLANG) ? @"Добавление.." : @"Adding to album..";
        [self performSelectorInBackground:@selector(processAdd) withObject:nil];
    }
    else
    {
        currentID = nil;
    }
}

%new
-(void) processSave
{
    UIImage* image = [self performSelector:@selector(currentImageWithMaxResolution) withObject:nil];
    if(image)
    {
        dispatch_async(dispatch_get_main_queue(),
                       ^{
                           HUD.labelText = (RUSSLANG) ? @"Сохранение.." : @"Saving..";
                       });
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(),
                       ^{
                           HUD.labelText = (RUSSLANG) ? @"Ошибка получения фото" : @"Photo load failed";
                           [HUD hide:YES afterDelay:1.0];
                       });
        currentID = nil;
    }
}

%new
-(void) processAdd
{
    NSString* forSig = [NSString stringWithFormat:@"/method/photos.copy?owner_id=%i&version=5.34&photo_id=%i&access_key=%@&access_token=%@%@", currentOwnerID, currentPhotoID, currentAccess_key, access_token, api_secret];
    NSString* sig = [self performSelector:@selector(md5:) withObject:forSig];
    NSString* url = [NSString stringWithFormat:@"http://api.vk.com/method/photos.copy?owner_id=%i&version=5.34&photo_id=%i&access_key=%@&access_token=%@&sig=%@", currentOwnerID, currentPhotoID, currentAccess_key, access_token, sig];
    NSData* jsonData = [self performSelector:@selector(getDataFrom:) withObject:url];
    
    if(!jsonData)
    {
        [self performSelector:@selector(showAddFailedHUD)];
        return;
    }
    
    NSError *error = nil;
    NSDictionary* jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if(error)
    {
        [self performSelector:@selector(showAddFailedHUD)];
        return;
    }
    
    id apiError = [jsonObject objectForKey:@"error"];
    
    if(apiError)
    {
        [self performSelector:@selector(showAddFailedHUD)];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       HUD.labelText = (RUSSLANG) ? @"Готово" : @"Ready";
                       [HUD hide:YES afterDelay:1.0];
                   });
    
    currentID = nil;
}

%new
-(void) showAddFailedHUD
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       HUD.labelText = (RUSSLANG) ? @"Ошибка добавления" : @"Error while adding";
                       [HUD hide:YES afterDelay:1.0];
                   });
    currentID = nil;
}

%new
- (NSString*) md5:(NSString*) input
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
-(UIImage*) currentImageWithMaxResolution
{
    NSString* forSig = [NSString stringWithFormat:@"/method/photos.getById?photos=%@&version=5.34&photo_sizes=1&access_token=%@%@", currentID, access_token, api_secret];
    NSString* sig = [self performSelector:@selector(md5:) withObject:forSig];
    NSString* url = [NSString stringWithFormat:@"http://api.vk.com/method/photos.getById?photos=%@&version=5.34&photo_sizes=1&access_token=%@&sig=%@", currentID, access_token, sig];
    NSData* jsonData = [self performSelector:@selector(getDataFrom:) withObject:url];
    
    if(!jsonData) return nil;
    
    NSError *error = nil;
    NSDictionary* jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if(error) return nil;
    if([jsonObject objectForKey:@"error"]) return nil;
    
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
                       HUD.labelText = (RUSSLANG) ? @"Загрузка.." : @"Downloading..";
                   });
    
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:link]]];
    return image;
}

%new
- (NSData*) getDataFrom:(NSString *)url
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
                           HUD.labelText = (RUSSLANG) ? @"Готово!" : @"Success!";
                           [HUD hide:YES afterDelay:1.0];
                       });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(),
                       ^{
                           HUD.labelText = (RUSSLANG) ? @"Ошибка сохранения" : @"Saving error";
                           [HUD hide:YES afterDelay:1.0];
                       });
    }
    currentID = nil;
}
%end

%hook CHPhotosViewerScrollCellView
- (void)postHeaderTableViewCell:(id)cell actionsButtonPressed:(id)arg2
{
    id model = [[cell performSelector:@selector(model)] retain];
    CHPhoto* currentPhoto = [model performSelector:@selector(photo)];
    currentOwnerID = currentPhoto.owner_id;
    currentPhotoID = currentPhoto.pid;
    currentID = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%i_%i", currentOwnerID, currentPhotoID]];
    %orig;
}
%end

%hook CHBasePhotosTableViewController
- (void)postHeaderTableViewCell:(id)cell actionsButtonPressed:(id)arg2
{
    id model = [[cell performSelector:@selector(model)] retain];
    CHPhoto* currentPhoto = [model performSelector:@selector(photo)];
    currentAccess_key = [[NSString alloc] initWithString:currentPhoto.access_key];
    currentOwnerID = currentPhoto.owner_id;
    currentPhotoID = currentPhoto.pid;
    currentID = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%i_%i", currentOwnerID, currentPhotoID]];
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
