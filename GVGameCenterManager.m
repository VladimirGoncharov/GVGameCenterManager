#import "GVGameCenterManager.h"

CGFloat const maxPercentComplete         = 100.0f;

@interface GVGameCenterManager ()

@property (nonatomic, retain) NSMutableDictionary *mAchievementCache;

//----show leader board
@property (nonatomic, copy) void(^completionHandlerShowLeaderboard)();

//----show achievements
@property (nonatomic, copy) void(^completionHandlerShowAchievements)();

@end

@implementation GVGameCenterManager

static GVGameCenterManager *gameManager = nil;

+ (instancetype)manager
{
    if (!gameManager)
    {
        gameManager = [self new];
    }
    return gameManager;
}

- (id)init
{
    static dispatch_once_t onceTokenManagerTemplates;
    dispatch_once(&onceTokenManagerTemplates, ^{
        if (!gameManager)
        {
            gameManager = [super init];
        }
    });
    
    return gameManager;
}

#pragma mark - accessory

- (NSDictionary *)achievementCache
{
    if (self.mAchievementCache)
    {
        return [self.mAchievementCache copy];
    }
    
    return nil;
}

#pragma mark - available

+ (BOOL)isGameCenterAvailable
{
	// check for presence of GKLocalPlayer API
	Class gcClass                       = (NSClassFromString(@"GKLocalPlayer"));
	
	// check if the device is running iOS 4.1 or later
	NSString *reqSysVer                 = @"4.1";
	NSString *currSysVer                = [[UIDevice currentDevice] systemVersion];
	BOOL osVersionSupported             = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
	
	return (gcClass && osVersionSupported);
}

#pragma mark - authenticated

- (BOOL)authenticated
{
    if ([[self class] isGameCenterAvailable])
    {
        return [GKLocalPlayer localPlayer].authenticated;
    }
    
    return NO;
}

- (void)authenticateLocalUserWithCompletionHandler:(void(^)(NSError *error))completionHandler
{
	if (!self.authenticated)
	{
		[[GKLocalPlayer localPlayer] authenticateWithCompletionHandler:^(NSError *error) {
            if (completionHandler)
            {
                completionHandler(error);
            }
        }];
	}
    else
    {
        if (completionHandler)
        {
            completionHandler(nil);
        }
    }
}

#pragma mark - Leader Board

- (void)reportScore:(int64_t)score
        forCategory:(NSString *)category
  completionHandler:(void(^)(GKScore *scope, NSError *error))completionHandler
{
	GKScore *scoreReporter = [[GKScore alloc] initWithCategory:category];
	scoreReporter.value = score;
	[scoreReporter reportScoreWithCompletionHandler:^(NSError *error)
     {
         if (completionHandler)
         {
             completionHandler(scoreReporter, error);
         }
     }];
}

- (void)reloadHighScoresForCategory:(NSString *)category
                  completionHandler:(void(^)(GKLeaderboard *leaderBoard, NSError *error))completionHandler
{
	GKLeaderboard *leaderBoard          = [GKLeaderboard new];
	leaderBoard.category                = category;
	leaderBoard.timeScope               = GKLeaderboardTimeScopeAllTime;
	leaderBoard.range                   = NSMakeRange(1, 1);
	
	[leaderBoard loadScoresWithCompletionHandler:^(NSArray *scores, NSError *error)
     {
         if (completionHandler)
         {
             completionHandler(leaderBoard, error);
         }
     }];
}

- (void)showLeaderboardWithCatagory:(NSString *)category
                          timeScope:(GKLeaderboardTimeScope)timeScope
                   InViewController:(UIViewController *)viewController
                  completionHandler:(void(^)())completionHandler
{
    NSAssert(viewController, @"Need viewController for present");
    
    if (self.completionHandlerShowLeaderboard)
    {
#if DEBUG
        NSLog(@"[WARNING]Leaderboard is show");
#endif
        if (completionHandler)
        {
            completionHandler();
        }
        return;
    }
    
    self.completionHandlerShowLeaderboard               = completionHandler;
    
    GKLeaderboardViewController *leaderboardController  = [GKLeaderboardViewController new];
    leaderboardController.category                      = category;
    leaderboardController.timeScope                     = timeScope;
    leaderboardController.leaderboardDelegate           = self;
    [viewController presentModalViewController:leaderboardController
                                      animated:YES];
}

- (void)leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController
{
	[viewController.presentingViewController dismissModalViewControllerAnimated:YES];
    if (self.completionHandlerShowLeaderboard)
    {
        self.completionHandlerShowLeaderboard();
        self.completionHandlerShowLeaderboard           = nil;
    }
}

#pragma mark - achievement

- (void)showAchievementsInViewController:(UIViewController *)viewController
                  completionHandler:(void(^)())completionHandler
{
    NSAssert(viewController, @"Need viewController for present");
    
    if (self.completionHandlerShowAchievements)
    {
#if DEBUG
        NSLog(@"[WARNING]Achievements is show");
#endif
        if (completionHandler)
        {
            completionHandler();
        }
        return;
    }
    
    self.completionHandlerShowAchievements                      = completionHandler;
    
	GKAchievementViewController *achievementsController         = [GKAchievementViewController new];
    achievementsController.achievementDelegate                  = self;
    [viewController presentModalViewController:achievementsController
                                      animated:YES];
}

- (void)achievementViewControllerDidFinish:(GKAchievementViewController *)viewController;
{
	[viewController.presentingViewController dismissModalViewControllerAnimated:YES];
    if (self.completionHandlerShowAchievements)
    {
        self.completionHandlerShowAchievements();
        self.completionHandlerShowAchievements                  = nil;
    }
}

- (void)submitAchievement:(NSString *)identifier
          percentComplete:(double)percentComplete
        completionHandler:(void(^)(GKAchievement *achievement, NSError *error))completionHandler
{
	//GameCenter check for duplicate achievements when the achievement is submitted, but if you only want to report
	// new achievements to the user, then you need to check if it's been earned
	// before you submit.  Otherwise you'll end up with a race condition between loadAchievementsWithCompletionHandler
	// and reportAchievementWithCompletionHandler.  To avoid this, we fetch the current achievement list once,
	// then cache it and keep it updated with any new achievements.
    __weak typeof(self) wself                       = self;
	if (!self.mAchievementCache)
	{
		[GKAchievement loadAchievementsWithCompletionHandler:^(NSArray *scores, NSError *error)
         {
             if (!error)
             {
                 NSMutableDictionary *tempCache             = [NSMutableDictionary dictionaryWithCapacity:[scores count]];
                 for (GKAchievement *score in scores)
                 {
                     [tempCache setObject:score
                                   forKey:score.identifier];
                 }
                 wself.mAchievementCache                    = tempCache;
                 [wself submitAchievement:identifier
                          percentComplete:percentComplete
                        completionHandler:completionHandler];
             }
             else
             {
                 //Something broke loading the achievement list.  Error out, and we'll try again the next time achievements submit.
                 if (completionHandler)
                 {
                     completionHandler(nil, error);
                 }
             }
         }];
	}
	else
	{
        //make range beetwen 0 and 100 for percentComplete
        percentComplete                 = MIN(maxPercentComplete, percentComplete);
        percentComplete                 = MAX(0.0f, percentComplete);
        
        //Search the list for the ID we're using...
		GKAchievement *achievement      = [self.mAchievementCache objectForKey:identifier];
        if (!achievement)
        {
            //Add achievement to achievements cache...
            achievement                             = [[GKAchievement alloc] initWithIdentifier:identifier];
			[self.mAchievementCache setObject:achievement
                                       forKey:achievement.identifier];
        }
        
        //setting achievement
        achievement.percentComplete                     = percentComplete;
        if (percentComplete >= maxPercentComplete)
        {
            achievement.showsCompletionBanner           = YES;
        }
        
        [achievement reportAchievementWithCompletionHandler:^(NSError *error)
         {
             if (completionHandler)
             {
                 completionHandler(achievement, error);
             }
         }];
	}
}

- (void)resetAchievementsWithCompletionHandler:(void(^)(NSError *error))completionHandler
{
	__weak typeof(self) wself               = self;
	[GKAchievement resetAchievementsWithCompletionHandler:^(NSError *error)
     {
         if (!error)
         {
             wself.mAchievementCache        = nil;
         }
         
         if (completionHandler)
         {
             completionHandler(error);
         }
     }];
}

- (void)mapPlayerIDtoPlayer:(NSString *)playerID
          completionHandler:(void(^)(GKPlayer *player, NSError *error))completionHandler
{
	[GKPlayer loadPlayersForIdentifiers:[NSArray arrayWithObject: playerID]
                  withCompletionHandler:^(NSArray *playerArray, NSError *error)
     {
         GKPlayer *player                = nil;
         if (!error)
         {
             for (GKPlayer* tempPlayer in playerArray)
             {
                 if([tempPlayer.playerID isEqualToString: playerID])
                 {
                     player              = tempPlayer;
                     break;
                 }
             }
         }
         
         if (completionHandler)
         {
             completionHandler(player, error);
         }
     }];
}

@end
