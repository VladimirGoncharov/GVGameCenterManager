#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

extern CGFloat const maxPercentComplete;

@interface GVGameCenterManager : NSObject <GKLeaderboardViewControllerDelegate, GKAchievementViewControllerDelegate>

@property (nonatomic, retain, readonly) NSDictionary *achievementCache;

+ (instancetype)manager;

+ (BOOL)isGameCenterAvailable;

@property (nonatomic, assign, readonly) BOOL authenticated;
- (void)authenticateLocalUserWithCompletionHandler:(void(^)(NSError *error))completionHandler;

#pragma mark - Leader Board

- (void)reportScore:(int64_t)score
        forCategory:(NSString *)category
  completionHandler:(void(^)(GKScore *scope, NSError *error))completionHandler;
- (void)reloadHighScoresForCategory:(NSString *)category
                  completionHandler:(void(^)(GKLeaderboard *leaderBoard, NSError *error))completionHandler;

- (void)showLeaderboardWithCatagory:(NSString *)category
                          timeScope:(GKLeaderboardTimeScope)timeScope
                   InViewController:(UIViewController *)viewController
                  completionHandler:(void(^)())completionHandler;

#pragma mark - achievement

- (void)submitAchievement:(NSString *)identifier
          percentComplete:(double)percentComplete
        completionHandler:(void(^)(GKAchievement *achievement, NSError *error))completionHandler;
- (void)resetAchievementsWithCompletionHandler:(void(^)(NSError *error))completionHandler;

- (void)showAchievementsInViewController:(UIViewController *)viewController
                       completionHandler:(void(^)())completionHandler;

#pragma mark - other

- (void)mapPlayerIDtoPlayer:(NSString *)playerID
          completionHandler:(void(^)(GKPlayer *player, NSError *error))completionHandler;

@end
