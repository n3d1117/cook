//
//  Plugin.h
//  CookMailPlugin
//
//  Created by ned on 3/12/19
//  Copyright © 2019 ned. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Plugin : NSObject
@end

@interface Plugin (NoImplementation)
+ (id)sharedInstance;
@end

@interface MVMailBundle : NSObject { }
+ (void)registerBundle;
@end

@interface AKAppleIDSession : NSObject
- (AKAppleIDSession *)initWithIdentifier:(NSString *)identifier;
- (NSDictionary *)appleIDHeadersForRequest:(NSURLRequest *)request;
@end

@interface AKDevice : NSObject
+ (id)currentDevice;
- (NSString *)uniqueDeviceIdentifier;
- (NSString *)serialNumber;
- (NSString *)serverFriendlyDescription;
@end
 
