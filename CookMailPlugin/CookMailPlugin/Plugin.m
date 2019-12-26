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

@interface Plugin ()
@property (nonatomic, readonly) NSISO8601DateFormatter *dateFormatter;
@end

@implementation Plugin

+ (instancetype)sharedInstance {
    static Plugin *_service = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _service = [[self alloc] init];
    });
    
    return _service;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dateFormatter = [[NSISO8601DateFormatter alloc] init];
    }
    return self;
}

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

-(void)start {
    NSLog(@"[CookMailPlugin] started...");

    dlopen("/System/Library/PrivateFrameworks/AuthKit.framework/AuthKit", RTLD_NOW);
    
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

    Class AKAppleIDSession = NSClassFromString(@"AKAppleIDSession");
    NSDictionary* headers = [[[AKAppleIDSession alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"] appleIDHeadersForRequest: nil];
    
    NSString* machineId = headers[@"X-Apple-I-MD-M"];
    NSString* oneTimePassword = headers[@"X-Apple-I-MD"];
    NSString* localUserId = headers[@"X-Apple-I-MD-LU"];
    long long routingInfo = [headers[@"X-Apple-I-MD-RINFO"] longLongValue];
    
    AKDevice* device = [NSClassFromString(@"AKDevice") currentDevice];
    
    NSString* deviceUniqueIdentifier = device.uniqueDeviceIdentifier;
    NSString* deviceSerialNumber = device.serialNumber;
    NSString* deviceDescription = device.serverFriendlyDescription;
    NSDate* date = [self.dateFormatter dateFromString: headers[@"X-Apple-I-Client-Time"]];
    
    return [[ALTAnisetteData alloc] initWithMachineID:machineId oneTimePassword:oneTimePassword localUserID:localUserId routingInfo:routingInfo deviceUniqueIdentifier:deviceUniqueIdentifier deviceSerialNumber:deviceSerialNumber deviceDescription:deviceDescription date:date locale:NSLocale.currentLocale timeZone:NSTimeZone.localTimeZone];
}
@end
