//
//  CYLRequestTimeMonitor.m
//  httpdns_ios_demo
//
//  Created by chenyilong on 2017/7/17.
//  Copyright © 2017年 ElonChan. All rights reserved.
//

#import "CYLRequestTimeMonitor.h"

@implementation CYLRequestTimeMonitor

static NSString *const CYLRequestFrontNumber = @"CYLRequestFrontNumber";
static NSString *const CYLRequestBeginTime = @"CYLRequestBeginTime";
static NSString *const CYLRequestEndTime = @"CYLRequestEndTime";
static NSString *const CYLRequestSpentTime = @"CYLRequestSpentTime";

+ (NSString *)requestBeginTimeKeyWithID:(NSUInteger)ID {
    return [self getKey:CYLRequestBeginTime ID:ID];
}

+ (NSString *)requestEndTimeKeyWithID:(NSUInteger)ID {
    return [self getKey:CYLRequestEndTime ID:ID];
}

+ (NSString *)requestSpentTimeKeyWithID:(NSUInteger)ID {
    return [self getKey:CYLRequestSpentTime ID:ID];
}

+ (NSString *)getKey:(NSString *)key ID:(NSUInteger)ID {
    NSString *timeKeyWithID = [NSString stringWithFormat:@"%@-%@", @(ID), key];
    return timeKeyWithID;
}

+ (NSUInteger)timeFromKey:(NSString *)key {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUInteger time = [defaults integerForKey:key];
    return time ?: 0;
}

+ (NSUInteger)frontRequetNumber {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUInteger frontNumber = [defaults integerForKey:CYLRequestFrontNumber];
    return frontNumber ?: 0;
}

+ (NSUInteger)changeToNextRequetNumber {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUInteger nextNumber = ([self frontRequetNumber]+ 1);
    [defaults setInteger:nextNumber forKey:CYLRequestFrontNumber];
    [defaults synchronize];
    return nextNumber;
}

+ (void)setCurrentTimeForKey:(NSString *)key taskID:(NSUInteger)taskID time:(NSTimeInterval *)time {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970]*1000;
    *time = currentTime;
    [self setTime:currentTime key:key taskID:taskID];
}

+ (void)setTime:(NSUInteger)time key:(NSString *)key taskID:(NSUInteger)taskID {
    NSString *keyWithID = [self getKey:key ID:taskID];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:time forKey:keyWithID];
    [defaults synchronize];
}

+ (void)setBeginTimeForTaskID:(NSUInteger)taskID {
    NSTimeInterval begin;
    [self setCurrentTimeForKey:CYLRequestBeginTime taskID:taskID time:&begin];
}

+ (void)setEndTimeForTaskID:(NSUInteger)taskID {
    NSTimeInterval endTime = 0;
    [self setCurrentTimeForKey:CYLRequestEndTime taskID:taskID time:&endTime];
    [self setSpentTimeForKey:CYLRequestSpentTime endTime:endTime taskID:taskID];
}

+ (void)setSpentTimeForKey:(NSString *)key endTime:(NSUInteger)endTime taskID:(NSUInteger)taskID {
    NSString *beginTimeString = [self requestBeginTimeKeyWithID:taskID];
    NSUInteger beginTime = [self timeFromKey:beginTimeString];
    NSUInteger spentTime = endTime - beginTime;
    [self setTime:spentTime key:CYLRequestSpentTime taskID:taskID];
}

@end
