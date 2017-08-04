//
//  CFHTTPDNSRequestTask.m
//  CFHTTPDNSRequest
//
//  Created by junmo on 16/12/8.
//  Copyright © 2016年 junmo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <arpa/inet.h>
#import <zlib.h>

#import "CFHTTPDNSRequestTask.h"
#import "CFHTTPDNSRequestTaskDelegate.h"

#import <AlicloudHttpDNS/AlicloudHttpDNS.h>

#define kAnchorAlreadyAdded @"AnchorAlreadyAdded"

// 数据读取缓冲区大小
static UInt32 BUFFER_SIZE = 16 * 1024;
// 默认请求超时时间为15秒
static double DEFAULT_TIMEOUT_INTERVAL = 15.0;

@interface CFHTTPDNSRequestResponse : NSObject

@property (nonatomic, assign) CFIndex statusCode;
@property (nonatomic, copy) NSDictionary *headerFields;
@property (nonatomic, copy) NSString *httpVersion;

@end

@implementation CFHTTPDNSRequestResponse
@end

@interface CFHTTPDNSRequestTask () <NSStreamDelegate>

@property (atomic, assign) BOOL completed;
@property (nonatomic, weak) id<CFHTTPDNSRequestTaskDelegate> delegate;
@property (nonatomic, copy) NSURLRequest *originalRequest;          // 原始网络请求
@property (nonatomic, copy) NSURLRequest *swizzleRequest;           // HTTPDNS处理过后请求
@property (nonatomic, copy) NSURLRequest *redirectRequest;          // 重定向请求
@property (nonatomic, strong) NSInputStream *inputStream;           // 读数据stream
@property (nonatomic, strong) NSRunLoop *runloop;                   // inputStream runloop
@property (nonatomic, strong) NSMutableData *resultData;            // 请求结果数据
@property (nonatomic, strong) CFHTTPDNSRequestResponse *response;   // 请求Response
@property (nonatomic, strong) NSTimer *timeoutTimer;                // 超时定时器

@end

@implementation CFHTTPDNSRequestTask

- (instancetype)init {
    if (self = [super init]) {
        self.completed = NO;
        self.response = [[CFHTTPDNSRequestResponse alloc] init];
    }
    return self;
}

#pragma mark external call

- (CFHTTPDNSRequestTask *)initWithURLRequest:(NSURLRequest *)request swizzleRequest:(NSURLRequest *)swizzleRequest delegate:(id<CFHTTPDNSRequestTaskDelegate>)delegate {
    
    if (!request || !delegate || !swizzleRequest) {
        return nil;
    }
    
    if (self = [self init]) {
        self.originalRequest = request;
        self.swizzleRequest = swizzleRequest;
        self.delegate = delegate;
        self.resultData = [NSMutableData data];
    }
    return self;
}

/**
 *  开始加载网络请求
 */
- (void)startLoading {
    // HTTP Header
    NSDictionary *headFields = self.swizzleRequest.allHTTPHeaderFields;
    
    // HTTP Body
    CFDataRef bodyData = NULL;
    if (self.swizzleRequest.HTTPBody) {
        bodyData = (__bridge_retained CFDataRef) self.swizzleRequest.HTTPBody;
    }
    

    //FIXME:  
//    else if (headFields[@"originalBody"]) {
//        /*
//         *  使用NSURLSession发POST请求时，Protocol拦截后无法获取请求Body，
//         *  假设发送请求前，将HTTP Body放入Header `originalBody` 字段暂存，
//         *  从Header `originalBody`中取出放回HTTP请求Body。
//         */
//        bodyData = (__bridge_retained CFDataRef) [headFields[@"originalBody"] dataUsingEncoding:NSUTF8StringEncoding];
//    }
    
    CFStringRef url = (__bridge CFStringRef) [self.swizzleRequest.URL absoluteString];
    CFURLRef requestURL = CFURLCreateWithString(kCFAllocatorDefault, url, NULL);
    
    // 原请求所使用的方法，GET或POST
    CFStringRef requestMethod = (__bridge_retained CFStringRef) self.swizzleRequest.HTTPMethod;
    
    // 根据请求的URL、方法、版本创建CFHTTPMessageRef对象
    CFHTTPMessageRef cfRequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault, requestMethod, requestURL, kCFHTTPVersion1_1);
    if (bodyData) {
        CFHTTPMessageSetBody(cfRequest, bodyData);
    }
    
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@\n%@---\n%@", @(__PRETTY_FUNCTION__), @(__LINE__), self.swizzleRequest, [[NSString alloc] initWithData:self.swizzleRequest.HTTPBody encoding:NSUTF8StringEncoding], bodyData);

    // Set HTTP Header
    for (NSString *header in headFields) {
        //FIXME:
//        if (![header isEqualToString:@"originalBody"]) {
            // 不包含POST请求时存放在Header的Body信息
            CFStringRef requestHeader = (__bridge CFStringRef) header;
            CFStringRef requestHeaderValue = (__bridge CFStringRef) [headFields valueForKey:header];
            CFHTTPMessageSetHeaderFieldValue(cfRequest, requestHeader, requestHeaderValue);
//        }
    }
    
    // 创建CFHTTPMessage对象的输入流
    CFReadStreamRef readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, cfRequest);
    self.inputStream = (__bridge_transfer NSInputStream *) readStream;
    
    // HTTPS请求处理SNI场景
    if ([self isHTTPSScheme]) {
        // 设置SNI host信息
        NSString *host = [self.swizzleRequest.allHTTPHeaderFields objectForKey:@"host"];
        if (!host) {
            host = self.originalRequest.URL.host;
        }
        [self.inputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
        NSDictionary *sslProperties = @{ (__bridge id) kCFStreamSSLPeerName : host };
        [self.inputStream setProperty:sslProperties forKey:(__bridge_transfer NSString *) kCFStreamPropertySSLSettings];
    }
    [self openInputStream];

    CFRelease(cfRequest);
    CFRelease(requestURL);
    cfRequest = NULL;
    CFRelease(requestMethod);
    if (bodyData) {
        CFRelease(bodyData);
    }
}

/**
 *  停止加载网络请求
 */
- (void)stopLoading {
    [self stopTimer];
    [self closeInputStream];
}

- (NSString *)getOriginalRequestHost {
    return self.originalRequest.URL.host;
}

- (NSHTTPURLResponse *)getRequestResponse {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.swizzleRequest.URL statusCode:self.response.statusCode HTTPVersion:self.response.httpVersion headerFields:self.response.headerFields];
    return response;
}

#pragma mark internal call

- (NSRunLoopMode)runloopMode {
    return NSRunLoopCommonModes;
}

- (void)openInputStream {
    //TODO:  添加打开流
    if ([self.delegate respondsToSelector:@selector(task:willSendRequest:redirectResponse:)]) {
        [self.delegate task:self willSendRequest:self.swizzleRequest redirectResponse:nil];
    }
    
    // 防止循环引用
    __weak typeof(self) weakSelf = self;
    self.runloop = [NSRunLoop currentRunLoop];
    [self startTimer];
    [self.inputStream setDelegate:weakSelf];
    [self.inputStream scheduleInRunLoop:self.runloop forMode:[self runloopMode]];
    [self.inputStream open];
}

- (void)closeInputStream {
    
    if (self.inputStream && self.inputStream.streamStatus != NSStreamStatusClosed) {
        [self.inputStream close];
        [self.inputStream removeFromRunLoop:self.runloop forMode:[self runloopMode]];
        [self.inputStream setDelegate:nil];
        self.inputStream = nil;
    }
}

/**
 *  打开网络请求访问超时定时器
 */
- (void)startTimer {
    if (!self.timeoutTimer) {
        self.timeoutTimer = [NSTimer timerWithTimeInterval:DEFAULT_TIMEOUT_INTERVAL target:self selector:@selector(checkTaskStatus) userInfo:nil repeats:NO];
        [self.runloop addTimer:self.timeoutTimer forMode:[self runloopMode]];
    }
}

/**
 *  关闭网络请求访问超时定时器
 */
- (void)stopTimer {
    if (self.timeoutTimer) {
        [self.timeoutTimer invalidate];
        self.timeoutTimer = nil;
    }
}

- (void)checkTaskStatus {
    if (self.timeoutTimer && !self.completed) {
        [self stopTimer];
        [self.delegate task:self didCompleteWithError:[NSError errorWithDomain:@"request timeout" code:-1 userInfo:nil]];
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            NSLog(@"InputStream opened success.");
            break;
        case NSStreamEventHasBytesAvailable:
        {
            if (![self analyseResponse]) {
                return;
            }
            UInt8 buffer[BUFFER_SIZE];
            NSInteger numBytesRead = 0;
            NSInputStream *inputstream = (NSInputStream *) aStream;
            // Read data
            do {
                numBytesRead = [inputstream read:buffer maxLength:sizeof(buffer)];
                if (numBytesRead > 0) {
                    [self.resultData appendBytes:buffer length:numBytesRead];
                }
            } while (numBytesRead > 0);
        }
            break;
        case NSStreamEventErrorOccurred:
            self.completed = YES;
            [self.delegate task:self didCompleteWithError:[aStream streamError]];
            break;
        case NSStreamEventEndEncountered:
            self.completed = YES;
            [self handleResult];
            break;
        default:
            break;
    }
}

/**
 * 根据服务器返回的响应内容进行不同的处理
 */
- (void)handleResult {
    /*
     *  检查`Content-Encoding`，返回数据是否需要进行解码操作；
     *  此处仅做了gzip解码的处理，业务场景若确定有其他编码格式，需自行完成扩展。
     */
    NSString *contentEncoding = [self.response.headerFields objectForKey:@"Content-Encoding"];
    if (contentEncoding && [contentEncoding isEqualToString:@"gzip"]) {
        [self.delegate task:self didReceiveData:[self ungzipData:self.resultData]];
    } else {
        [self.delegate task:self didReceiveData:self.resultData];
    }
    [self.delegate task:self didCompleteWithError:nil];
}

/**
 *  检查是否需要重定向
 */
- (BOOL)needRedirection {
    BOOL needRedirect = NO;
    switch (self.response.statusCode) {
        // 永久重定向
        case 301:
        // 暂时重定向
        case 302:
        // POST重定向GET
        case 303:
        {
            NSString *location = self.response.headerFields[@"Location"];
            if (location) {
                NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), location);
                NSURL *url = [[NSURL alloc] initWithString:location];
                NSMutableURLRequest *mRequest = [self.swizzleRequest mutableCopy];
                mRequest.URL = url;
                if ([[self.swizzleRequest.HTTPMethod lowercaseString] isEqualToString:@"post"]) {
                    // POST重定向为GET
                    mRequest.HTTPMethod = @"GET";
                    mRequest.HTTPBody = nil;
                }
                [mRequest setValue:nil forHTTPHeaderField:@"host"];
                self.redirectRequest = mRequest;
                needRedirect = YES;
                break;
            }
        }
        // POST不重定向为GET，询问用户是否携带POST数据(很少使用)
        //case 307:
        //    break;
        default:
            break;
    }
    return needRedirect;
}

- (BOOL)analyseResponse {
    BOOL result = YES;
    CFReadStreamRef readStream = (__bridge CFReadStreamRef) self.inputStream;
    CFHTTPMessageRef message = (CFHTTPMessageRef) CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    if (!message) {
        return NO;
    }
    result = CFHTTPMessageIsHeaderComplete(message);
    if (result) {
        NSNumber *added = objc_getAssociatedObject(self.inputStream, kAnchorAlreadyAdded);
        if (!added || ![added boolValue]) {
            objc_setAssociatedObject(self.inputStream, kAnchorAlreadyAdded, @YES, OBJC_ASSOCIATION_COPY);
            // Status Code
            self.response.statusCode = CFHTTPMessageGetResponseStatusCode(message);
            // HTTP Version
            CFStringRef cHttpVersion = CFHTTPMessageCopyVersion(message);
            self.response.httpVersion = (__bridge NSString *)cHttpVersion;
            // Response Header Fileds
            CFDictionaryRef cHeaderDic = CFHTTPMessageCopyAllHeaderFields(message);
            NSDictionary *headerDic = (__bridge NSDictionary *)cHeaderDic;
            self.response.headerFields = headerDic;
            
            CFRelease(cHttpVersion);
            CFRelease(cHeaderDic);
            
            if ([self needRedirection]) {
                // 重定向Response
                NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.redirectRequest.URL statusCode:self.response.statusCode HTTPVersion:self.response.httpVersion headerFields:self.response.headerFields];
                [self.delegate task:self didReceiveRedirection:self.redirectRequest response:response];
                result = NO;
            } else {
                /*
                 *  构造并返回响应Response，
                 *  NSHTTPURLResponse中包含：请求URL、响应状态码、HTTP版本和响应头部字段。
                 *  【注意】请求URL填充为原始请求`originalRequest.URL`，而不是替换后的请求`swizzleRequest.URL`。
                 *
                 *  例：WebView加载请求场景下，加载页面`https://a.b.com/aaa/bbb`，HTTPDNS解析后替换为`https://1.2.3.4/aaa/bbb`；
                 *  加载完成后，该页面需加载相对路径资源`../asset/xx`，计算绝对路径时根据Response返回的Request.URL计算。
                 *  Response若返回swizzleRequest.URL:`https://1.2.3.4/aaa/bbb`，加载相对路径资源WebView生成绝对路径URL：`https://1.2.3.4/asset/xx`，WebView重新发起网络请求时，由于缺少Host，HTTP请求可能导致服务端找不到对应资源，HTTPS请求导致SSL/TLS鉴权失败；
                 *  Response若返回originalRequest.URL:`https://a.b.com/aaa/bbb`，加载相对路径资源WebView生成绝对路径URL：`https://a.b.com/asset/xx`，WebView重新发起网络请求时，Host字段完整，可正常完成请求资源加载。
                 */
                NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.originalRequest.URL statusCode:self.response.statusCode HTTPVersion:self.response.httpVersion headerFields:self.response.headerFields];
                [self.delegate task:self didReceiveResponse:response cachePolicy:NSURLCacheStorageNotAllowed];
                
                // HTTPS校验证书
                if ([self isHTTPSScheme]) {
                    SecTrustRef trust = (__bridge SecTrustRef) [self.inputStream propertyForKey:(__bridge NSString *) kCFStreamPropertySSLPeerTrust];
                    SecTrustResultType res = kSecTrustResultInvalid;
                    NSMutableArray *policies = [NSMutableArray array];
                    NSString *domain = [[self.swizzleRequest allHTTPHeaderFields] valueForKey:@"host"];
                    if (domain) {
                        [policies addObject:(__bridge_transfer id) SecPolicyCreateSSL(true, (__bridge CFStringRef) domain)];
                    } else {
                        [policies addObject:(__bridge_transfer id) SecPolicyCreateBasicX509()];
                    }
                    // 绑定校验策略到服务端的证书上
                    SecTrustSetPolicies(trust, (__bridge CFArrayRef) policies);
                    if (SecTrustEvaluate(trust, &res) != errSecSuccess) {
                        [self.delegate task:self didCompleteWithError:[[NSError alloc] initWithDomain:@"can not evaluate the server trust" code:-1 userInfo:nil]];
                        result = NO;
                    } else if (res != kSecTrustResultProceed && res != kSecTrustResultUnspecified) {
                        // 证书验证不通过
                        [self.delegate task:self didCompleteWithError:[[NSError alloc] initWithDomain:@"fail to evaluate the server trust" code:-1 userInfo:nil]];
                        result = NO;
                    }
                }
            }
        }
    }
    CFRelease(message);
    return result;
}

/**
 *  判断是否为HTTPS请求
 */
- (BOOL)isHTTPSScheme {
    return [self.originalRequest.URL.scheme isEqualToString:@"https"];
}

- (NSData *)ungzipData:(NSData *)compressedData {
    if ([compressedData length] == 0) {
        return compressedData;
    }
    
    unsigned long full_length = [compressedData length];
    unsigned long half_length = [compressedData length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[compressedData bytes];
    strm.avail_in = (unsigned int) [compressedData length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    if (inflateInit2(&strm, (15+32)) != Z_OK) {
        return nil;
    }
    while (!done) {
        if (strm.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy: half_length];
        }
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (unsigned int) ([decompressed length] - strm.total_out);
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) {
            done = YES;
        } else if (status != Z_OK) {
            break;
        }
    }
    
    if (inflateEnd (&strm) != Z_OK) {
        return nil;
    }
    if (done) {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    return nil;
}

@end
