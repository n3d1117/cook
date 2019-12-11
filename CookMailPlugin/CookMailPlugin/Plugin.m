//
//  Plugin.m
//  CookMailPlugin
//
//  Created by ned on 3/12/19
//  Copyright © 2019 ned. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <objc/objc-runtime.h>
#include <dlfcn.h>
#import "Plugin.h"
#import "ALTAnisetteData.h"

@implementation Plugin

+(void)initialize {

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
    class_setSuperclass([self class], NSClassFromString(@"MVMailBundle"));
#pragma GCC diagnostic pop

    NSLog(@"Loaded CookMailPlugin!");
    [[Plugin sharedInstance] start];
}

-(NSString*)fetchAnisetteDataNotification { return @"it.ned.FetchAnisetteData"; }
-(NSString*)receivedAnisetteDataNotification { return @"it.ned.ReceivedAnisetteData"; }

NSDateFormatter *formatter;

-(void)start {
    NSLog(@"[CookMailPlugin] started...");
    
    formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(received:) name:[self fetchAnisetteDataNotification] object:nil];
    NSLog(@"[CookMailPlugin] listening for %@ notifications...", [self fetchAnisetteDataNotification]);
}

-(void)received:(NSNotification *) notification {
    if ([[notification name] isEqualToString:[self fetchAnisetteDataNotification]]) {

        NSString* uuid = (NSString*)notification.userInfo[@"uuid"];
        
        NSLog(@"[CookMailPlugin] Received %@ notification with uuid %@! Generating AuthKit headers...", [self fetchAnisetteDataNotification], uuid);
        
        ALTAnisetteData* anisetteData = [self getAnisetteData];
        
        NSLog(@"[CookMailPlugin] Generated anisette data: %@...", [anisetteData description]);
        
        NSData* data;
        
        if (@available(macOS 10.13, *)) {
            data = [NSKeyedArchiver archivedDataWithRootObject:anisetteData requiringSecureCoding:TRUE error:nil];
        } else {
            data = [NSKeyedArchiver archivedDataWithRootObject:anisetteData];
        }
        
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        [dict setObject:uuid forKey:@"uuid"];
        [dict setObject:data forKey:@"anisetteData"];
        
        NSLog(@"[CookMailPlugin] Sending back %@ notification...", [self receivedAnisetteDataNotification]);
        
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:[self receivedAnisetteDataNotification] object:nil userInfo:dict deliverImmediately:TRUE];
    }
}

-(ALTAnisetteData*)getAnisetteData {
    dlopen("/System/Library/PrivateFrameworks/AuthKit.framework/AuthKit", RTLD_NOW);

    Class AKAppleIDSession = NSClassFromString(@"AKAppleIDSession");
    
    //NSString* requestUrl = @"https://developerservices2.apple.com/services/QH65B2/listTeams.action?clientId=XXXXXXXXXX";
    //NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[[NSURL alloc]initWithString: requestUrl]];
    NSDictionary* headers = [[[AKAppleIDSession alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"] appleIDHeadersForRequest: nil];
    
    NSString* machineId = headers[@"X-Apple-I-MD-M"];
    NSString* oneTimePassword = headers[@"X-Apple-I-MD"];
    NSString* localUserId = headers[@"X-Apple-I-MD-LU"];
    long long routingInfo = [headers[@"X-Apple-I-MD-RINFO"] longLongValue];
    
    AKDevice* device = [NSClassFromString(@"AKDevice") currentDevice];
    
    NSString* deviceUniqueIdentifier = device.uniqueDeviceIdentifier;
    NSString* deviceSerialNumber = device.serialNumber;
    //NSString* deviceDescription = device.serverFriendlyDescription;
    NSString* deviceDescription = @"<MacBookPro11,5> <Mac OS X;10.14.6;18G103> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";
    NSDate* date = [formatter dateFromString: headers[@"X-Apple-I-Client-Time"]];
    
    return [[ALTAnisetteData alloc] initWithMachineID:machineId oneTimePassword:oneTimePassword localUserID:localUserId routingInfo:routingInfo deviceUniqueIdentifier:deviceUniqueIdentifier deviceSerialNumber:deviceSerialNumber deviceDescription:deviceDescription date:date locale:NSLocale.currentLocale timeZone:NSTimeZone.localTimeZone];
}
@end
