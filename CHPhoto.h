@interface CHPhoto : NSObject
{
    int _pid;
    int _owner_id;
    NSString *_access_key;
}

@property(readonly, nonatomic) NSString *access_key;
@property(readonly, nonatomic) int owner_id;
@property(readonly, nonatomic) int pid;

@end