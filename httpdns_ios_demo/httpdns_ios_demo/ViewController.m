//
//  ViewController.m
//  httpdns_ios_demo
//
//  Created by ryan on 27/1/2016.
//  Copyright © 2016 alibaba. All rights reserved.
//

#import "ViewController.h"
#import "NetworkManager.h"
#import <AlicloudHttpDNS/AlicloudHttpDNS.h>
#import "CFHTTPDNSHTTPProtocol.h"

@interface ViewController ()<NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@end

static HttpDnsService *httpdns;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    
//    // 初始化HTTPDNS
//    httpdns = [HttpDnsService sharedInstance];
//    
//
//    // 异步网络请求
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        
//        NSString *originalUrl = @"http://www.aliyun.com";
//        NSURL *url = [NSURL URLWithString:originalUrl];
//        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
//        request.HTTPMethod = @"POST";
//        request.HTTPBody = [@"I am 普通场景 HTTPBody" dataUsingEncoding:NSUTF8StringEncoding];
//        // 同步接口获取IP地址，由于我们是用来进行url访问请求的，为了适配IPv6的使用场景，我们使用getIpByHostInURLFormat接口
//        // 注* 当您使用IP形式的URL进行网络请求时，IPv4与IPv6的IP地址使用方式略有不同：
//        // IPv4: http://1.1.1.1/path
//        // IPv6: http://[2001:db8:c000:221::]/path
//        // 因此我们专门提供了适配URL格式的IP获取接口getIpByHostInURLFormat
//        // 如果您只是为了获取IP信息而已，可以直接使用getIpByHost接口
//        NSString *ip = [httpdns getIpByHostInURLFormat:url.host];
//        if (ip) {
//            // 通过HTTPDNS获取IP成功，进行URL替换和HOST头设置
//            NSLog(@"Get IP(%@) for host(%@) from HTTPDNS Successfully!", ip, url.host);
//            NSRange hostFirstRange = [originalUrl rangeOfString:url.host];
//            if (NSNotFound != hostFirstRange.location) {
//                NSString *newUrl = [originalUrl stringByReplacingCharactersInRange:hostFirstRange withString:ip];
//                NSLog(@"New URL: %@", newUrl);
//                request.URL = [NSURL URLWithString:newUrl];
//                [request setValue:url.host forHTTPHeaderField:@"host"];
//            }
//        }
//        NSHTTPURLResponse* response;
//        NSError *error;
//        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//        if (error != nil) {
//            NSLog(@"Error: %@", error);
//        } else {
//            NSLog(@"Response: %@",response);
//        }
//        
//        // 异步接口获取IP
//        ip = [httpdns getIpByHostAsyncInURLFormat:url.host];
//        if (ip) {
//            // 通过HTTPDNS获取IP成功，进行URL替换和HOST头设置
//            NSLog(@"Get IP(%@) for host(%@) from HTTPDNS Successfully!", ip, url.host);
//            NSRange hostFirstRange = [originalUrl rangeOfString:url.host];
//            if (NSNotFound != hostFirstRange.location) {
//                NSString *newUrl = [originalUrl stringByReplacingCharactersInRange:hostFirstRange withString:ip];
//                NSLog(@"New URL: %@", newUrl);
//                request.URL = [NSURL URLWithString:newUrl];
//                [request setValue:url.host forHTTPHeaderField:@"host"];
//            }
//        }
//
//        data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//        if (error != nil) {
//            NSLog(@"Error: %@", error);
//        } else {
//            NSLog(@"Response: %@",response);
//        }
//
//        
//        // 测试黑名单中的域名
//        ip = [httpdns getIpByHostAsyncInURLFormat:@"www.taobao.com"];
//        if (!ip) {
//            NSLog(@"由于在降级策略中过滤了www.taobao.com，无法从HTTPDNS服务中获取对应域名的IP信息");
//        }
//    });
    
    
    // 注册拦截请求的NSURLProtocol
    [NSURLProtocol registerClass:[CFHTTPDNSHTTPProtocol class]];
    // 初始化HTTPDNS
    HttpDnsService *httpdns = [HttpDnsService sharedInstance];
    
    // 需要设置SNI的URL
    NSString *originalUrl = @"https://book.douban.com/annual2015/#2";
    NSURL *url = [NSURL URLWithString:originalUrl];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    NSString *ip = [httpdns getIpByHostAsync:url.host];
    // 通过HTTPDNS获取IP成功，进行URL替换和HOST头设置
    if (ip) {         NSLog(@"Get IP from HTTPDNS Successfully!");
        NSRange hostFirstRange = [originalUrl rangeOfString:url.host];
        if (NSNotFound != hostFirstRange.location) {
            NSString *newUrl = [originalUrl stringByReplacingCharactersInRange:hostFirstRange withString:ip];
            request.URL = [NSURL URLWithString:newUrl];
            [request setValue:url.host forHTTPHeaderField:@"host"];
            NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), url.host);
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
    request.HTTPMethod = @"POST";
    request.HTTPBody = [@"I am HTTPBody" dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSArray *protocolArray = @[ [CFHTTPDNSHTTPProtocol class] ];
    configuration.protocolClasses = protocolArray;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionTask *task = [session dataTaskWithRequest:request];
    [task resume];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 * 降级过滤器，您可以自己定义HTTPDNS降级机制
 */
//- (BOOL)shouldDegradeHTTPDNS:(NSString *)hostName {
//    //FIXME:  linshi
////    NSLog(@"Enters Degradation filter.");
////    // 根据HTTPDNS使用说明，存在网络代理情况下需降级为Local DNS
////    if ([NetworkManager configureProxies]) {
////        NSLog(@"Proxy was set. Degrade!");
////        return YES;
////    }
////    
////    // 假设您禁止"www.taobao.com"域名通过HTTPDNS进行解析
////    if ([hostName isEqualToString:@"www.taobao.com"]) {
////        NSLog(@"The host is in blacklist. Degrade!");
////        return YES;
////    }
//    
//    return NO;
//}


@end
