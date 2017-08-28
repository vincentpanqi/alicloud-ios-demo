//
// SNIViewController.m
// httpdns_ios_demo
//
// SNI应用场景
// Created by junmo on 16/12/8.
// Copyright © 2016年 junmo. All rights reserved.
//

#import <AlicloudHttpDNS/AlicloudHttpDNS.h>
#import "NetworkManager.h"
#import "SNIViewController.h"
#import "CFHTTPDNSHTTPProtocol.h"

/**
 *  本示例用于演示HTTPS SNI场景下HTTPDNS的处理方式。
 *  场景包括：WebView加载、基于NSURLConnection加载、基于NSURLSession加载；
 *  WebView加载请求场景，HTTPDNS域名解析必须在拦截请求后进行；
 *  NSURLConnection/NSURLSession加载请求场景，可在发起请求前或拦截请求后进行HTTPDNS域名解析；
 *  Demo为实现统一的NSURLProtocol，统一在`CFHTTPDNSProtocol`拦截请求后进行HTTPDNS域名解析。
 *  由于在SNI场景下，网络请求必须基于底层CFNetwork完成，建议不要拦截非SNI场景的网络请求，尽可能走上层网络库发送网络请求。
 */
@interface SNIViewController () <NSURLConnectionDelegate, NSURLConnectionDataDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation SNIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [NSURLProtocol registerClass:[CFHTTPDNSHTTPProtocol class]];
    NSString *urlString = @"https://dou.bz/23o8PS";
    
//    NSString *urlString = @"https://feature.yoho.cn/0929/ADRIANNE/index.html?app_version=5.2.1.1611250001&client_secret=b6379fcc5944e71dbb6e99c8a47d3454&client_type=iphone&os_version=9.3.4&screen_size=320x568&share_id=1437&title=Adrianne%20Ho%E7%9A%84%E7%94%B7%E8%A3%85%E6%90%AD%E9%85%8D%E7%BB%8F&udid=9f6f0c2733503615e8fdea0c2070b8ec9a8c04fc&uid=15344064&v=7&yh_channel=1%22";

    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    //FIXME:
    request.HTTPMethod = @"POST";
    request.HTTPBody = [@"I am HTTPBody" dataUsingEncoding:NSUTF8StringEncoding];
    
    
    /*!
     *  NSMutableURLRequest *bbsURLRequest = [[NSMutableURLRequest alloc] initWithURL:url];
     [bbsURLRequest setValue:@"0b7e7f7e80a011e785fd525400a5dd54" forHTTPHeaderField:@"cid"];
     NSString* userName;
     userName= [[NSUserDefaults standardUserDefaults] objectForKey:@"userName"];
     //        JCYACAILog(@"...%@..",userName);
     if ([userName isEqual:[NSNull null]]) {
     [bbsURLRequest addValue:[@"" stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forHTTPHeaderField:@"userName"];
     }else{
     [bbsURLRequest addValue:[userName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forHTTPHeaderField:@"userName"];
     }
     */
    
    /*
     *  WebView加载资源场景
     */
//    [self.webView loadRequest:request];
    
    /*
     *  NSURLConnection加载资源场景
     */
    //[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
    
    /*
     *  NSURLSession加载资源场景
     */
    //NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    //NSArray *protocolArray = @[ [CFHTTPDNSHTTPProtocol class] ];
    //configuration.protocolClasses = protocolArray;
    //NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    //NSURLSessionTask *task = [session dataTaskWithRequest:request];
    //[task resume];
    
    // 注*：使用NSURLProtocol拦截NSURLSession发起的POST请求时，HTTPBody为空。
    // 解决方案有两个：1. 使用NSURLConnection发POST请求。
    // 2. 先将HTTPBody放入HTTP Header field中，然后在NSURLProtocol中再取出来。
    // 下面主要演示第二种解决方案
    //NSString *postStr = [NSString stringWithFormat:@"param1=%@&param2=%@", @"val1", @"val2"];
    //[request addValue:postStr forHTTPHeaderField:@"originalBody"];
    //request.HTTPMethod = @"POST";
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSArray *protocolArray = @[ [CFHTTPDNSHTTPProtocol class] ];
    configuration.protocolClasses = protocolArray;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    //----------------- <FROM：统计代码执行时间>-----------------
    NSDate *methodStart = [NSDate date];
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //----------------- <TO：统计代码执行时间>-----------------
        NSDate *methodFinish = [NSDate date];
        NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
        NSLog(@"executionTime(执行时间) = %f", executionTime);
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@\n%@", @(__PRETTY_FUNCTION__), @(__LINE__), error, response);
    }];
    [task resume];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated {
    // 取消注册NSURLProtocol，避免拦截其他场景的请求
    [NSURLProtocol unregisterClass:[CFHTTPDNSHTTPProtocol class]];
    [super viewDidDisappear:animated];
}

#pragma mark NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    //NSLog(@"receive data:%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    //NSLog(@"receive response:%@", response);
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    return request;
}

#pragma mark NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    //NSLog(@"data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    //NSLog(@"response: %@", response);
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        //NSLog(@"error: %@", error);
    }
    else {
        //NSLog(@"complete");
    }
}

@end
