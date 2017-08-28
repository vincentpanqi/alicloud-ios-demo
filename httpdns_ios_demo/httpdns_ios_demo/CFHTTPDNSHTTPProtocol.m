//
//  CFHTTPDNSHTTPProtocol.m
//  CFHTTPDNSRequest
//
//  Created by junmo on 16/12/8.
//  Copyright © 2016年 junmo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <arpa/inet.h>
#import <AlicloudHttpDNS/AlicloudHttpDNS.h>
#import "CFHTTPDNSHTTPProtocol.h"
#import "CFHTTPDNSRequestTaskDelegate.h"
#import "CYLRequestTimeMonitor.h"
#import "NSURLRequest+CYLNSURLProtocolExtension.h"

/**
 *  本示例拦截HTTPS请求，使用HTTPDNS进行域名解析，基于CFNetwork发送HTTPS请求，并适配SNI配置；
 *  若有HTTP请求，或重定向时有HTTP请求，需要另注册其他NSURLProtocol来处理或者走系统原生处理逻辑。
 *
 *  NSURLProtocol API描述参考：https://developer.apple.com/reference/foundation/nsurlprotocol
 *  尽可能拦截少量网络请求，尽量避免直接基于CFNetwork发送HTTP/HTTPS请求。
 */

static NSString *recursiveRequestFlagProperty = @"com.aliyun.httpdns";

@interface CFHTTPDNSHTTPProtocol () <CFHTTPDNSRequestTaskDelegate>

// 基于CFNetwork发送HTTPS请求的Task
@property (atomic, strong) CFHTTPDNSRequestTask *task;
// 记录请求开始时间
@property (atomic, assign) NSTimeInterval startTime;

@end

@implementation CFHTTPDNSHTTPProtocol

#pragma mark NSURLProtocl API

/**
 *  是否拦截处理指定的请求
 *
 *  @param request 指定的请求
 *
 *  @return YES:拦截处理，NO:不拦截处理
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    //NSLog(@"Rry to handle request: %@.", request);
    BOOL shouldAccept = YES;
    BOOL isNOTHTTPS =  ![request.URL.scheme isEqualToString:@"https"] ;
    BOOL hasProcessed = ([NSURLProtocol propertyForKey:recursiveRequestFlagProperty inRequest:request] != nil);
    BOOL isInvalidRequest = (request == nil || request.URL == nil || request.URL.scheme == nil);
    if (
        isInvalidRequest ||
        isNOTHTTPS ||
        hasProcessed
        ) {
        shouldAccept = NO;
    }
    /*
     *  降级处理逻辑：
     *  1. 不拦截基于IP访问的请求；
     *  2. HTTPDNS无法返回对应Host的解析结果IP时，不拦截处理该请求，交由其他注册Protocol或系统原生网络库处理。
     *  基于此，可通过控制台下线域名，动态控制客户端降级。
     *  ***************************************************************************
     *  【注意】当HTTPDNS不可用时，一定要做好降级处理，减少网络请求处理的无意义干涉，降低风险。
     *  添加该降级逻辑时，一定要基于HTTPDNS最新版本SDK构建。
     *  HTTPDNS iOS SDK包括:
     *      AlicloudHttpDNS.framework
     *      AlicloudUtils.framework
     *      UTDID.framework
     *  各Framework都要升级到线上最新版本，否则不能使用该降级处理逻辑，切记！
     *  ***************************************************************************
     */
    if (shouldAccept && ![self canHTTPDNSResolveHost:request.URL.host]) {
        //NSLog(@"HTTPDNS can't resolve [%@] now.", request.URL.host);
        shouldAccept = NO;
    }
    
    if (shouldAccept) {
//        NSLog(@"Accept request: %@.", request);
    } else {
//        NSLog(@"Decline request: %@.", request);
    }
    
    //FIXME: 临时做法，需要删除
//    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@\n%@\n%@", @(__PRETTY_FUNCTION__), @(__LINE__),request, request.URL.host, @(shouldAccept));
//    if ([request.URL.host isEqualToString:@"mappsrv.yacai.com"] || [request.URL.host isEqualToString:@"hy.yacai.com"]) {
//        return YES;
//    }
    
    return shouldAccept;
}

//FIXME: 302
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return [request cyl_getPostRequestIncludeBody];
}

/**
 *  开始加载请求
 */
- (void)startLoading {
    //TODO:
    NSMutableURLRequest *recursiveRequest = [self.request mutableCopy];
//    NSMutableURLRequest *recursiveRequest = [[self request] mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:recursiveRequestFlagProperty inRequest:recursiveRequest];
    self.startTime = [NSDate timeIntervalSinceReferenceDate];
    // 构造CFHTTPDNSRequestTask，基于CFNetwork发送HTTPS请求
    NSURLRequest *swizzleRequest = [self httpdnsResolve:recursiveRequest];
    //NSLog(@"SwizzleRequest: %@", swizzleRequest);
    self.task = [[CFHTTPDNSRequestTask alloc] initWithURLRequest:recursiveRequest swizzleRequest:swizzleRequest delegate:self];
    if (self.task) {
        [self.task startLoading];
        self.task.taskID = [CYLRequestTimeMonitor changeToNextRequetNumber];
        [CYLRequestTimeMonitor setBeginTimeForTaskID:self.task.taskID];
    }
}

/**
 *  停止加载请求
 */
- (void)stopLoading {
    //NSLog(@"[%@] stop loading, elapsed %.1f seconds.", self.request, [NSDate timeIntervalSinceReferenceDate] - self.startTime);
    if (self.task) {
        [self.task stopLoading];
        self.task = nil;
    }
}

- (void)task:(CFHTTPDNSRequestTask *)task didReceiveRedirection:(NSURLRequest *)request response:(NSURLResponse *)response {
    //NSLog(@"Redirect from [%@] to [%@].", response.URL, request.URL);
    NSMutableURLRequest *mRequest = [request mutableCopy];
    [NSURLProtocol removePropertyForKey:recursiveRequestFlagProperty inRequest:mRequest];
    NSURLResponse *cResponse = [response copy];
    [task stopLoading];
    /*
     *  交由NSProtocolClient处理重定向请求
     *  request: 重定向后的request
     *  redirectResponse: 原请求返回的Response
     */
    [self.client URLProtocol:self wasRedirectedToRequest:mRequest redirectResponse:cResponse];
    [self.client URLProtocolDidFinishLoading:self];
//    [self setEndTimeForTaskID:task.taskID];
      [CYLRequestTimeMonitor setEndTimeForTaskID:task.taskID];
}

- (void)task:(CFHTTPDNSRequestTask *)task didReceiveResponse:(NSURLResponse *)response cachePolicy:(NSURLCacheStoragePolicy)cachePolicy {
    //NSLog(@"Did receive response: %@", response);
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:cachePolicy];
}

- (void)task:(CFHTTPDNSRequestTask *)task didReceiveData:(NSData *)data {
    //NSLog(@"Did receive data.");
    [self.client URLProtocol:self didLoadData:data];
}

- (void)task:(CFHTTPDNSRequestTask *)task didCompleteWithError:(NSError *)error {
    
    if (error) {
        //NSLog(@"Did complete with error, %@.", error);
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        //NSLog(@"Did complete success.");
        [self.client URLProtocolDidFinishLoading:self];
//        [self setCurrentTimeForKey:CYLRequestEndTime taskID:task.taskID];
//        [self setEndTimeForTaskID:task.taskID];
    }
}

/**
 *  HTTPDNS解析域名，重新构造请求
 *  若原始请求基于IP地址，无需做域名解析直接返回
 */
- (NSURLRequest *)httpdnsResolve:(NSURLRequest *)request {
    NSMutableURLRequest *swizzleRequest;
    //NSLog(@"HTTPDNS start resolve URL: %@", request.URL.absoluteString);
    NSURL *originURL = request.URL;
    NSString *originURLStr = originURL.absoluteString;
    swizzleRequest = [request mutableCopy];
    NSString *ip = [[HttpDnsService sharedInstance] getIpByHostAsync:originURL.host];
    // 通过HTTPDNS获取IP成功，进行URL替换和HOST头设置
    if (ip) {
        //NSLog(@"Get IP from HTTPDNS Successfully!");
        NSRange hostFirstRange = [originURLStr rangeOfString:originURL.host];
        if (NSNotFound != hostFirstRange.location) {
            NSString *newUrl = [originURLStr stringByReplacingCharactersInRange:hostFirstRange withString:ip];
            swizzleRequest.URL = [NSURL URLWithString:newUrl];
            [swizzleRequest setValue:originURL.host forHTTPHeaderField:@"host"];
        }
    } else {
        // 没有获取到域名解析结果
        return request;
    }
    return swizzleRequest;
}

/**
 *  检测当前HTTPDNS是否可以返回对应host解析结果
 *  host为空或host为IP地址，直接返回NO。
 */
+ (BOOL)canHTTPDNSResolveHost:(NSString *)host {
    if (!host || [self isIPAddress:host]) {
        return NO;
    }
    
    NSString *ip = [[HttpDnsService sharedInstance] getIpByHostAsync:host];
    return (ip != nil);
}

/**
 *  判断输入是否为IP地址
 */
+ (BOOL)isIPAddress:(NSString *)str {
    if (!str) {
        return NO;
    }
    int success;
    struct in_addr dst;
    struct in6_addr dst6;
    const char *utf8 = [str UTF8String];
    // check IPv4 address
    success = inet_pton(AF_INET, utf8, &(dst.s_addr));
    if (!success) {
        // check IPv6 address
        success = inet_pton(AF_INET6, utf8, &dst6);
    }
    return success;
}

@end
