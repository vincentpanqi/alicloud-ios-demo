
// MyCFHttpMessageURLProtocol.m
// NSURLProtocolDemo
//
// Created by fuyuan.lfy on 16/6/14.
// Copyright © 2016年 Jaylon. All rights reserved.
//

#import "CFHttpMessageURLProtocol.h"
#import "NetworkManager.h"
#import <AlicloudHttpDNS/AlicloudHttpDNS.h>
#import <objc/runtime.h>
#import "NSURLRequest+CYLNSURLProtocolExtension.h"

#define protocolKey @"CFHttpMessagePropertyKey"
#define kAnchorAlreadyAdded @"AnchorAlreadyAdded"

@interface CFHttpMessageURLProtocol () <NSStreamDelegate> {
    NSMutableURLRequest *curRequest;
    NSRunLoop *curRunLoop;
    NSInputStream *inputStream;
}

@end

@implementation CFHttpMessageURLProtocol

/**
 *  是否拦截处理指定的请求
 *
 *  @param request 指定的请求
 *
 *  @return 返回YES表示要拦截处理，返回NO表示不拦截处理
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    
    /* 防止无限循环，因为一个请求在被拦截处理过程中，也会发起一个请求，这样又会走到这里，如果不进行处理，就会造成无限循环 */
    if ([NSURLProtocol propertyForKey:protocolKey inRequest:request]) {
        return NO;
    }
    
    NSString *url = request.URL.absoluteString;
    
    // 如果url以https开头，则进行拦截处理，否则不处理
    if ([url hasPrefix:@"https"]) {
        return YES;
    }
    return NO;
}

/**
 * 如果需要对请求进行重定向，添加指定头部等操作，可以在该方法中进行
 */
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

/**
 * 开始加载，在该方法中，加载一个请求
 */
- (void)startLoading {
    NSMutableURLRequest *request = [self.request mutableCopy];
    [request cyl_handlePostRequestBody];
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), request);
    // 表示该请求已经被处理，防止无限循环
    [NSURLProtocol setProperty:@(YES) forKey:protocolKey inRequest:request];
    curRequest = request;
    [self startRequest];
}

/**
 * 取消请求
 */
- (void)stopLoading {
    if (inputStream.streamStatus == NSStreamStatusOpen) {
        [inputStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
        [inputStream setDelegate:nil];
        [inputStream close];
    }
    [self.client URLProtocol:self didFailWithError:[[NSError alloc] initWithDomain:@"stop loading" code:-1 userInfo:nil]];
}

/**
 * 使用CFHTTPMessage转发请求
 */
- (void)startRequest {
    
//    [curRequest cyl_handlePostRequestBody];

    // 原请求的header信息
    NSDictionary *headFields = curRequest.allHTTPHeaderFields;
    // 添加http post请求所附带的数据
    CFStringRef requestBody = CFSTR("");
    CFDataRef bodyData = CFStringCreateExternalRepresentation(kCFAllocatorDefault, requestBody, kCFStringEncodingUTF8, 0);
    
    if (curRequest.HTTPBody) {
        bodyData = (__bridge_retained CFDataRef) curRequest.HTTPBody;
    } else {
      // [curRequest cyl_handlePostRequestBody];
    }
    
    //FIXME:  删除 body方案
//    else if (headFields[@"originalBody"]) {
//        // 使用NSURLSession发POST请求时，将原始HTTPBody从header中取出
//        bodyData = (__bridge_retained CFDataRef) [headFields[@"originalBody"] dataUsingEncoding:NSUTF8StringEncoding];
//    }
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@\n%@---\n%@", @(__PRETTY_FUNCTION__), @(__LINE__), curRequest, [[NSString alloc] initWithData:curRequest.HTTPBody encoding:NSUTF8StringEncoding], bodyData);
    CFStringRef url = (__bridge CFStringRef) [curRequest.URL absoluteString];
    CFURLRef requestURL = CFURLCreateWithString(kCFAllocatorDefault, url, NULL);
    
    // 原请求所使用的方法，GET或POST
    CFStringRef requestMethod = (__bridge_retained CFStringRef) curRequest.HTTPMethod;
    
    // 根据请求的url、方法、版本创建CFHTTPMessageRef对象
    CFHTTPMessageRef cfrequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault, requestMethod, requestURL, kCFHTTPVersion1_1);
    CFHTTPMessageSetBody(cfrequest, bodyData);
    
    // copy原请求的header信息
    for (NSString *header in headFields) {
        //FIXME:  删除Body
//        if (![header isEqualToString:@"originalBody"]) {
            // 不包含POST请求时存放在header的body信息
            CFStringRef requestHeader = (__bridge CFStringRef) header;
            CFStringRef requestHeaderValue = (__bridge CFStringRef) [headFields valueForKey:header];
            CFHTTPMessageSetHeaderFieldValue(cfrequest, requestHeader, requestHeaderValue);
//        }
    }
    
    // 创建CFHTTPMessage对象的输入流
    CFReadStreamRef readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, cfrequest);
    inputStream = (__bridge_transfer NSInputStream *) readStream;
    
    // 设置SNI host信息，关键步骤
    NSString *host = [curRequest.allHTTPHeaderFields objectForKey:@"host"];
    if (!host) {
        host = curRequest.URL.host;
    }
    [inputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
    NSDictionary *sslProperties = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   host, (__bridge id) kCFStreamSSLPeerName,
                                   nil];
    [inputStream setProperty:sslProperties forKey:(__bridge_transfer NSString *) kCFStreamPropertySSLSettings];
    [inputStream setDelegate:self];
    
    if (!curRunLoop) {
        curRunLoop = [NSRunLoop currentRunLoop];
    }
        // 保存当前线程的runloop，这对于重定向的请求很关键
    // 将请求放入当前runloop的事件队列
    [inputStream scheduleInRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
    [inputStream open];
    
    CFRelease(cfrequest);
    CFRelease(requestURL);
    CFRelease(url);
    cfrequest = NULL;
    CFRelease(bodyData);
    CFRelease(requestBody);
    CFRelease(requestMethod);
}

/**
 * 根据服务器返回的响应内容进行不同的处理
 */
- (void)handleResponse {
    // 获取响应头部信息
    CFReadStreamRef readStream = (__bridge_retained CFReadStreamRef) inputStream;
    CFHTTPMessageRef message = (CFHTTPMessageRef) CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    if (CFHTTPMessageIsHeaderComplete(message)) {
        // 确保response头部信息完整
        NSDictionary *headDict = (__bridge NSDictionary *) (CFHTTPMessageCopyAllHeaderFields(message));
        
        // 获取响应头部的状态码
        CFIndex myErrCode = CFHTTPMessageGetResponseStatusCode(message);
        
        // 把当前请求关闭
        [inputStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
        [inputStream setDelegate:nil];
        [inputStream close];
        
        if (myErrCode >= 200 && myErrCode < 300) {
            
            // 返回码为2xx，直接通知client
            [self.client URLProtocolDidFinishLoading:self];
            
        } else if (myErrCode >= 300 && myErrCode < 400) {
            // 返回码为3xx，需要重定向请求，继续访问重定向页面
            NSString *location = headDict[@"Location"];
            if (!location) {
                location = headDict[@"location"];
            }
            NSURL *url = [[NSURL alloc] initWithString:location];
            curRequest.URL = url;
            if ([[curRequest.HTTPMethod lowercaseString] isEqualToString:@"post"]) {
                // 根据RFC文档，当重定向请求为POST请求时，要将其转换为GET请求
                curRequest.HTTPMethod = @"GET";
                curRequest.HTTPBody = nil;
            }
            
            /***********重定向通知client处理或内部处理*************/
            // client处理
            // NSURLResponse* response = [[NSURLResponse alloc] initWithURL:curRequest.URL MIMEType:headDict[@"Content-Type"] expectedContentLength:[headDict[@"Content-Length"] integerValue] textEncodingName:@"UTF8"];
            // [self.client URLProtocol:self wasRedirectedToRequest:curRequest redirectResponse:response];
            
            // 内部处理，将url中的host通过HTTPDNS转换为IP，不能在startLoading线程中进行同步网络请求，会被阻塞
            NSString *ip = [[HttpDnsService sharedInstance] getIpByHostAsync:url.host];
            if (ip) {
                NSLog(@"Get IP from HTTPDNS Successfully!");
                NSRange hostFirstRange = [location rangeOfString:url.host];
                if (NSNotFound != hostFirstRange.location) {
                    NSString *newUrl = [location stringByReplacingCharactersInRange:hostFirstRange withString:ip];
                    curRequest.URL = [NSURL URLWithString:newUrl];
                    [curRequest setValue:url.host forHTTPHeaderField:@"host"];
                }
            }
            [self startRequest];
        } else {
            // 其他情况，直接返回响应信息给client
            [self.client URLProtocolDidFinishLoading:self];
        }
    } else {
        // 头部信息不完整，关闭inputstream，通知client
        [inputStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
        [inputStream setDelegate:nil];
        [inputStream close];
        [self.client URLProtocolDidFinishLoading:self];
    }
}

#pragma mark - NSStreamDelegate
/**
 * input stream 收到header complete后的回调函数
 */
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if (eventCode == NSStreamEventHasBytesAvailable) {
        CFReadStreamRef readStream = (__bridge_retained CFReadStreamRef) aStream;
        CFHTTPMessageRef message = (CFHTTPMessageRef) CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
        if (CFHTTPMessageIsHeaderComplete(message)) {
            // 以防response的header信息不完整
            UInt8 buffer[16 * 1024];
            UInt8 *buf = NULL;
            unsigned long length = 0;
            NSInputStream *inputstream = (NSInputStream *) aStream;
            NSNumber *alreadyAdded = objc_getAssociatedObject(aStream, kAnchorAlreadyAdded);
            if (!alreadyAdded || ![alreadyAdded boolValue]) {
                objc_setAssociatedObject(aStream, kAnchorAlreadyAdded, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_COPY);
                // 通知client已收到response，只通知一次
                NSDictionary *headDict = (__bridge NSDictionary *) (CFHTTPMessageCopyAllHeaderFields(message));
                CFStringRef httpVersion = CFHTTPMessageCopyVersion(message);
                // 获取响应头部的状态码
                CFIndex myErrCode = CFHTTPMessageGetResponseStatusCode(message);
                NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:curRequest.URL statusCode:myErrCode HTTPVersion:(__bridge NSString *) httpVersion headerFields:headDict];
                
                [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                
                // 验证证书
                SecTrustRef trust = (__bridge SecTrustRef) [aStream propertyForKey:(__bridge NSString *) kCFStreamPropertySSLPeerTrust];
                SecTrustResultType res = kSecTrustResultInvalid;
                NSMutableArray *policies = [NSMutableArray array];
                NSString *domain = [[curRequest allHTTPHeaderFields] valueForKey:@"host"];
                NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), domain);

                if (domain) {
                    [policies addObject:(__bridge_transfer id) SecPolicyCreateSSL(true, (__bridge CFStringRef) domain)];
                } else {
                    [policies addObject:(__bridge_transfer id) SecPolicyCreateBasicX509()];
                }
                /*
                 * 绑定校验策略到服务端的证书上
                 */
                SecTrustSetPolicies(trust, (__bridge CFArrayRef) policies);
                if (SecTrustEvaluate(trust, &res) != errSecSuccess) {
                    [aStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
                    [aStream setDelegate:nil];
                    [aStream close];
                    [self.client URLProtocol:self didFailWithError:[[NSError alloc] initWithDomain:@"can not evaluate the server trust" code:-1 userInfo:nil]];
                }
                if (res != kSecTrustResultProceed && res != kSecTrustResultUnspecified) {
                    /* 证书验证不通过，关闭input stream */
                    [aStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
                    [aStream setDelegate:nil];
                    [aStream close];
                    [self.client URLProtocol:self didFailWithError:[[NSError alloc] initWithDomain:@"fail to evaluate the server trust" code:-1 userInfo:nil]];
                    
                } else {
                    // 证书通过，返回数据
                    if (![inputstream getBuffer:&buf length:&length]) {
                        NSInteger amount = [inputstream read:buffer maxLength:sizeof(buffer)];
                        buf = buffer;
                        length = amount;
                    }
                    NSData *data = [[NSData alloc] initWithBytes:buf length:length];
                    
                    [self.client URLProtocol:self didLoadData:data];
                    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), data);
                }
            } else {
                // 证书已验证过，返回数据
                if (![inputstream getBuffer:&buf length:&length]) {
                    NSInteger amount = [inputstream read:buffer maxLength:sizeof(buffer)];
                    buf = buffer;
                    length = amount;
                }
                NSData *data = [[NSData alloc] initWithBytes:buf length:length];
                NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), data);
                [self.client URLProtocol:self didLoadData:data];
            }
        }
    } else if (eventCode == NSStreamEventErrorOccurred) {
        [aStream removeFromRunLoop:curRunLoop forMode:NSRunLoopCommonModes];
        [aStream setDelegate:nil];
        [aStream close];
        // 通知client发生错误了
        [self.client URLProtocol:self didFailWithError:[aStream streamError]];
    } else if (eventCode == NSStreamEventEndEncountered) {
        [self handleResponse];
    }
}

@end
