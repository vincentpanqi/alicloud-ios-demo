//
//  CYLRequestTimeMonitor.h
//  httpdns_ios_demo
//
//  Created by chenyilong on 2017/7/17.
//  Copyright © 2017年 ElonChan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CYLRequestTimeMonitor : NSObject

+ (NSString *)requestBeginTimeKeyWithID:(NSUInteger)ID;
+ (NSString *)requestEndTimeKeyWithID:(NSUInteger)ID;
+ (NSString *)requestSpentTimeKeyWithID:(NSUInteger)ID;
+ (NSString *)getKey:(NSString *)key ID:(NSUInteger)ID;
+ (NSUInteger)timeFromKey:(NSString *)key;
+ (NSUInteger)frontRequetNumber;
+ (NSUInteger)changeToNextRequetNumber;
+ (void)setCurrentTimeForKey:(NSString *)key taskID:(NSUInteger)taskID time:(NSTimeInterval *)time;
+ (void)setTime:(NSUInteger)time key:(NSString *)key taskID:(NSUInteger)taskID;

+ (void)setBeginTimeForTaskID:(NSUInteger)taskID;
+ (void)setEndTimeForTaskID:(NSUInteger)taskID;
+ (void)setSpentTimeForKey:(NSString *)key endTime:(NSUInteger)endTime taskID:(NSUInteger)taskID;
    
@end
