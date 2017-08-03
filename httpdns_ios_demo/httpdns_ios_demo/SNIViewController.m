//
// SNIViewController.m
// httpdns_ios_demo
//
// SNI应用场景
// Created by fuyuan.lfy on 16/6/23.
// Copyright © 2016年 alibaba. All rights reserved.
//

#import "CFHttpMessageURLProtocol.h"
#import "NetworkManager.h"
#import "SNIViewController.h"
#import <AlicloudHttpDNS/AlicloudHttpDNS.h>

@interface SNIViewController () <NSURLConnectionDelegate, NSURLConnectionDataDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong) NSMutableURLRequest *request;
@end

@implementation SNIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    // 注册拦截请求的NSURLProtocol
    [NSURLProtocol registerClass:[CFHttpMessageURLProtocol class]];
    // 初始化HTTPDNS
    HttpDnsService *httpdns = [HttpDnsService sharedInstance];
    
    // 需要设置SNI的URL
//    NSString *originalUrl = @"https://dou.bz/23o8PS";

    NSString *originalUrl = @"https://dou.bz/23o8PS";
    NSURL *url = [NSURL URLWithString:originalUrl];
    self.request = [[NSMutableURLRequest alloc] initWithURL:url];
    NSString *ip = [httpdns getIpByHostAsync:url.host];
    // 通过HTTPDNS获取IP成功，进行URL替换和HOST头设置
    if (ip) {
        NSLog(@"Get IP from HTTPDNS Successfully!");
        NSRange hostFirstRange = [originalUrl rangeOfString:url.host];
        if (NSNotFound != hostFirstRange.location) {
            NSString *newUrl = [originalUrl stringByReplacingCharactersInRange:hostFirstRange withString:ip];
            self.request.URL = [NSURL URLWithString:newUrl];
            [_request setValue:url.host forHTTPHeaderField:@"host"];
        }
    }
    
    // NSURLConnection例子
    // [[NSURLConnection alloc] initWithRequest:_request delegate:self startImmediately:YES];
    
    // NSURLSession例子
//    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
//    NSArray *protocolArray = @[ [CFHttpMessageURLProtocol class] ];
//    configuration.protocolClasses = protocolArray;
//    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
//    NSURLSessionTask *task = [session dataTaskWithRequest:_request];
//    [task resume];
    
    // 注*：使用NSURLProtocol拦截NSURLSession发起的POST请求时，HTTPBody为空。
    // 解决方案有两个：1. 使用NSURLConnection发POST请求。
    // 2. 先将HTTPBody放入HTTP Header field中，然后在NSURLProtocol中再取出来。
    // 下面主要演示第二种解决方案
//     NSString *postStr = [NSString stringWithFormat:@"param1=%@&param2=%@", @"val1", @"val2"];
//     [_request addValue:postStr forHTTPHeaderField:@"originalBody"];
    //构造元素需要使用两个空格来进行缩进，右括号]或者}写在新的一行，并且与调用语法糖那行代码的第一个非空字符对齐：
//    NSDictionary *dictionary = @{
//                                 //冒号':'前后留有一个空格,按照Value来对齐
//                                 @"val1" : @"param1",
//                                 @"val2" : @"param2"
//                                 };
//    
     _request.HTTPMethod = @"POST";
    _request.HTTPBody = [@"I am HTTPBody" dataUsingEncoding:NSUTF8StringEncoding];
     NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
     NSArray *protocolArray = @[ [CFHttpMessageURLProtocol class] ];
     configuration.protocolClasses = protocolArray;
     NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
     NSURLSessionTask *task = [session dataTaskWithRequest:_request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
         if (error) {
             NSLog(@"🔴类名与方法名：%@（在第%@行），error描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), error);
         } else {
             NSLog(@"🔴类名与方法名：%@（在第%@行），response描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), response);
             //            NSLog(@"data: %@", data);
         }
     }];
     [task resume];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated {
    // 取消注册CFHttpMessageURLProtocol，避免拦截其他场景的请求
    [NSURLProtocol unregisterClass:[CFHttpMessageURLProtocol class]];
}

#pragma mark NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSLog(@"receive data:%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"receive response:%@", response);
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    return request;
}

#pragma mark NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSLog(@"data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSLog(@"response: %@", response);
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"error: %@", error);
    }
    else
        NSLog(@"complete");
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
