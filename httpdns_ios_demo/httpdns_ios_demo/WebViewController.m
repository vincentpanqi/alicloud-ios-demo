//
//  WebViewController.m
//  httpdns_ios_demo
//
//  Created by fuyuan.lfy on 16/6/25.
//  Copyright © 2016年 alibaba. All rights reserved.
//

#import "WebViewController.h"
#import "WebViewURLProtocol.h"
#import <WebKit/WebKit.h>
//#import "NSURLProtocol+WKWebVIew.h"
static NSString *const CYLHTTPMethod = @"http";
static NSString *const CYLHTTPSMethod = @"https";

static BOOL  CYLUSEIP = YES;

//static NSString *const CYLIP = @"111.206.193.95";
//static NSString *const CYLHOST = @"3g.163.com";
//static NSString *const  CYLOriginalUrl = @"http://3g.163.com/touch/";


//static NSString *const CYLIP = @"115.159.231.166";
//static NSString *const CYLHOST = @"m.58.com";
//static NSString *const  CYLOriginalUrl = @"http://m.58.com/bj/";


static NSString *const CYLIP = @"115.159.231.166";
static NSString *const CYLHOST = @"m.m.58.com";
static NSString *const  CYLOriginalUrl = @"http://m.m.58.com/?58hm=m_my58_new&58cid=1";

@interface WebViewController ()
<WKNavigationDelegate ,
WKUIDelegate,
WKURLSchemeHandler, //FIXME:  iOS11 API
WKHTTPCookieStoreObserver
>

@property (nonatomic)  WKWebView* webView;

//@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) NSMutableURLRequest *request;

@end

@implementation WebViewController

+ (void)load {
    //不在load中注册，将导致`- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation`前无法获得cookie信息
    //不注册，后者在load中注册，不会有该问题。
    //    [NSURLProtocol wk_registerScheme:@"http"];
    //    [NSURLProtocol wk_registerScheme:@"https"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [NSURLProtocol registerClass:[WebViewURLProtocol class]];

    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    
    [cookieStroe addObserver:self];
    //不在load中注册，将导致`- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation`前无法获得cookie信息
    //不注册，后者在load中注册，不会有该问题。
    //    [NSURLProtocol wk_registerScheme:@"http"];
    //    [NSURLProtocol wk_registerScheme:@"https"];
    
    [self.view addSubview:self.webView];
    //    [self deleteAllNSHTTPCookie];
    
    //    [self deleteAllWKHTTPCookieStoreWithCompletionHandler:^{
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
    
    //        WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    //        [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
    //            NSLog(@"All cookies %@",cookies);
    //        }];
    
    
    //    sleep(10);
    //        [self addUserLoginCookieWithIsWK:NO completionHandler:^{
    [self copyNSHTTPCookieStorageToWKHTTPCookieStoreWithCompletionHandler:^{
        NSString *ip = CYLIP;
        //                NSString *urlString = @"http://www.163.com";
        BOOL isIP = CYLUSEIP; //arc4random_uniform(10)%2 == 0;
        //               NSString *string = isIP ? IPString : urlString;
        //                NSURL *url = [NSURL URLWithString:string];
        //                NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), string);
        //111.206.193.95
        //@"http://3g.163.com"
        NSString *originalUrl = CYLOriginalUrl;
        NSURL *url = [NSURL URLWithString:originalUrl];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        
        if (isIP) {
            // 通过HTTPDNS获取IP成功，进行URL替换和HOST头设置
            NSLog(@"Get IP(%@) for host(%@) from HTTPDNS Successfully!", ip, url.host);
            NSRange hostFirstRange = [originalUrl rangeOfString:url.host];
            if (NSNotFound != hostFirstRange.location) {
                NSString *newUrl = [originalUrl stringByReplacingCharactersInRange:hostFirstRange withString:ip];
                NSLog(@"New URL: %@", newUrl);
                request.URL = [NSURL URLWithString:newUrl];
                [request setValue:url.host forHTTPHeaderField:@"host"];
            }
        }
        
        [_webView loadRequest:request];
    }];
    //        }];
    
    //    [self testWKCookiStore];
    //    [self addNewCookie];
    //    }];
    
}

//- (void)viewDidLoad {
//    [super viewDidLoad];
//    // Do any additional setup after loading the view.
//    // 注册拦截请求的NSURLProtocol
//    [NSURLProtocol registerClass:[WebViewURLProtocol class]];
//
//    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
//    [self.view addSubview:self.webView];
//    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://www.apple.com"]];
//      [self.webView loadRequest:request];
//}

- (void)viewDidDisappear:(BOOL)animated {
    // 取消注册WebViewURLProtocol，避免拦截其他场景的请求
    [NSURLProtocol unregisterClass:[WebViewURLProtocol class]];
    [super viewDidDisappear:animated];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
}

- (WKWebView *)webView {
    if (!_webView) {
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        configuration.userContentController = [WKUserContentController new];
        
        //        configuration.websiteDataStore =
        
        WKWebsiteDataStore *dataStore = [WKWebsiteDataStore defaultDataStore];
        
        configuration.websiteDataStore = dataStore;
        
        //        [dataStore fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
        //                         completionHandler:^(NSArray<WKWebsiteDataRecord *> * __nonnull records) {
        //                             for (WKWebsiteDataRecord *record  in records)
        //                             {
        //                                 NSLog(@"WKWebsiteDataRecord:%@",[record description]);
        //                             }
        //                         }];
        
        WKPreferences *preferences = [WKPreferences new];
        preferences.javaScriptCanOpenWindowsAutomatically = YES;
        preferences.minimumFontSize = 30.0;
        configuration.preferences = preferences;
        
        _webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:configuration];
        _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        //TODO:  ios API
        //        [self _schemeHandler];
        if ([_webView respondsToSelector:@selector(setNavigationDelegate:)]) {
            [_webView setNavigationDelegate:self];
        }
        
        if ([_webView respondsToSelector:@selector(setDelegate:)]) {
            [_webView setUIDelegate:self];
        }
        
        
        
        
        
        
    }
    return _webView;
}

// 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    //    WKWebsiteDataStore *dataStore = [WKWebsiteDataStore defaultDataStore];
    //    [dataStore fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
    //                     completionHandler:^(NSArray<WKWebsiteDataRecord *> * __nonnull records) {
    //                         for (WKWebsiteDataRecord *record  in records)
    //                         {
    //                             NSLog(@"WKWebsiteDataRecord:%@",[record description]);
    //                         }
    //                     }];
    //    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
    //    [self testWKCookiStore];
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
    //    [self addNewCookie];
    //    [self changeCookieDomainFromIP:CYLIP toHost:CYLHOST];
    //    [self logCookies];
    //    [self copyWKHTTPCookieStoreToNSHTTPCookie];
    //    [self logCookies];
    
}

- (void)addNewNSHTTPCookie {
    
    NSString *timeStr = [NSString stringWithFormat:@"%@", @([[NSDate date] timeIntervalSince1970])];
    
    NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
    
    [cookieProperties setObject:[NSString stringWithFormat:@"username-", timeStr] forKey:NSHTTPCookieName];
    [cookieProperties setObject:[NSString stringWithFormat:@"rainbird-", timeStr] forKey:NSHTTPCookieValue];
    [cookieProperties setObject:[NSString stringWithFormat:@"cnrainbird.com-", timeStr] forKey:NSHTTPCookieDomain];
    [cookieProperties setObject:[NSString stringWithFormat:@"cnrainbird.com-%@", timeStr] forKey:NSHTTPCookieOriginURL];
    [cookieProperties setObject:@"/" forKey:NSHTTPCookiePath];
    [cookieProperties setObject:@"0" forKey:NSHTTPCookieVersion];
    
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
}

//WK默认是会存到NSHTTPCookieStore中去的，只是某些场景下
- (void)deleteAllWKHTTPCookieStoreWithCompletionHandler:(nullable void (^)())theCompletionHandler; {
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        if (cookies.count == 0) {
            !theCompletionHandler ?: theCompletionHandler();
            return ;
        }
        for (NSHTTPCookie *cookie in cookies) {
            [cookieStroe deleteCookie:cookie completionHandler:^{
                [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
                    for (id cookie in cookies) {
                        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), cookie);
                    }
                }];
                
                if ([[cookies lastObject] isEqual:cookie]) {
                    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
                    //                    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
                    [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
                        //                        NSLog(@"All cookies %@",cookies);
                    }];
                    !theCompletionHandler ?: theCompletionHandler();
                }
            }];
        }
    }];
}

- (void)deleteAllNSHTTPCookie {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
    cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), cookies);
    
    
}

// 解决wk无法持久化cookie的问题。
//TODO:  还有一个疑问，WKWebView网络请求时之前是不能主动携带cookie的，但是有了WKHTTPCookieStore，是不是就是说可以携带了？
//答案是YES，只要是存在WKHTTPCookieStore里的 cookie，WKWebView每次请求都会携带，存在NSHTTPCookieStorage的cookie，并不会携带。
- (void)copyNSHTTPCookieStorageToWKHTTPCookieStoreWithCompletionHandler:(nullable void (^)())theCompletionHandler; {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    if (cookies.count == 0) {
        !theCompletionHandler ?: theCompletionHandler();
        return;
    }
    for (NSHTTPCookie *cookie in cookies) {
        [cookieStroe setCookie:cookie completionHandler:^{
            if ([[cookies lastObject] isEqual:cookie]) {
                !theCompletionHandler ?: theCompletionHandler();
                return;
            }
        }];
    }
}


//WK默认是会存到NSHTTPCookieStore中去的，只是某些场景下
- (void)copyWKHTTPCookieStoreToNSHTTPCookie {
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), @"");
        for (NSHTTPCookie *cookie in cookies) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
        }
    }];
}

//- (void)copyNSHTTPCookieStorageToWKHTTPCookieStoreWithCompletionHandler:(nullable void (^)())theCompletionHandler; {
//    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
//    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
//    for (NSHTTPCookie *cookie in cookies) {
//        if (cookies.count == 0) {
//            !theCompletionHandler ?: theCompletionHandler();
//            break;
//        }
//        [cookieStroe setCookie:cookie completionHandler:^{
//            if ([[cookies lastObject] isEqual:cookie]) {
//                !theCompletionHandler ?: theCompletionHandler();
//                return;
//            }
//            //        NSLog(@"set cookie %@", timeStr);
//            //缺陷，本地没有固化，App重启后，缓存消失。
//            [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
//                NSLog(@"All cookies %@",cookies);
//                NSString *message = [NSString stringWithFormat:@"%@", @([cookies count])];
//                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"总cookie个数"message:message preferredStyle:UIAlertControllerStyleAlert];
//                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
//                }];
//                [alertController addAction:cancelAction];
//                [self presentAlertViewController:alertController];
//            }];
//        }];
//    }
//}


- (void)addUserLoginCookieWithIsWK:(BOOL)isWK completionHandler:(nullable void (^)())completionHandler {
    
    /*!
     * version:1
     name:A2
     value:"2|1:0|10:1501153547|2:A2|56:YzUzZGYxYTI3ZGQyNzBhYzc0MjlhNTQxOTJhYzgxMTg1MmFmMThiMg==|dcda7c0af58b097238bd09773cbf0ae83bd4593ddb3567cc9ace360a1b5dd496"
     expiresDate:'2018-07-27 11:05:46 +0000'
     created:'2017-07-27 11:06:00 +0000'
     sessionOnly:FALSE
     domain:.v2ex.com
     partition:none
     path:/
     isSecure:FALSE
     path:"/" isSecure:FALSE>
     2017-07-27 19:06:00.115410+0800 WKWebVIewHybridDemo[43658:7482607] 🔴类名与方法名：-[HybirdViewController deleteAllWKHTTPCookieStoreWithCompletionHandler:]_block_invoke_3（在第179行），描述：<NSHTTPCookie
     version:1
     name:V2EX_TAB
     value:"2|1:0|10:1501153547|8:V2EX_TAB|8:dGVjaA==|541cbe3f2986d664cabcb66155fb7996b7c150b2789c0782c016435a91bfc47f"
     expiresDate:'2017-08-10 11:05:46 +0000'
     created:'2017-07-27 11:06:00 +0000'
     sessionOnly:FALSE
     domain:www.v2ex.com
     partition:none
     path:/
     isSecure:FALSE
     path:"/" isSecure:FALSE>
     */
    NSHTTPCookie *cookie1 =  ({
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        
        dict[NSHTTPCookieName] = @"A2";//[NSString stringWithFormat:@"userid-%@", timeStr];
        dict[NSHTTPCookieValue] = @"2|1:0|10:1501153547|2:A2|56:YzUzZGYxYTI3ZGQyNzBhYzc0MjlhNTQxOTJhYzgxMTg1MmFmMThiMg==|dcda7c0af58b097238bd09773cbf0ae83bd4593ddb3567cc9ace360a1b5dd496";
        dict[NSHTTPCookieDomain] = @".v2ex.com";
        dict[NSHTTPCookiePath] = @"/";
        dict[NSHTTPCookieVersion] = @"1";
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:dict];
        if (isWK) {
            WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
            [cookieStroe setCookie:cookie completionHandler:nil];
            //        return;
        } else {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
        }
        cookie;
        
    });
    NSHTTPCookie *cookie2 =  ({
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        
        dict[NSHTTPCookieName] = @"V2EX_TAB";//[NSString stringWithFormat:@"userid-%@", timeStr];
        dict[NSHTTPCookieValue] = @"2|1:0|10:1501153547|8:V2EX_TAB|8:dGVjaA==|541cbe3f2986d664cabcb66155fb7996b7c150b2789c0782c016435a91bfc47f";
        dict[NSHTTPCookieDomain] = @"www.v2ex.com";
        dict[NSHTTPCookiePath] = @"/";
        dict[NSHTTPCookieVersion] = @"1";
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:dict];
        if (isWK) {
            WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
            [cookieStroe setCookie:cookie completionHandler:nil];
            //        return;
        } else {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
        }
        cookie;
        
    });
    
    //    NSString *timeStr = [NSString stringWithFormat:@"%@", @([[NSDate date] timeIntervalSince1970])];
    
    //    NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
    //
    //    [cookieProperties setObject:@"PB3_SESSION"; forKey:NSHTTPCookieName];
    //    [cookieProperties setObject:@"2|1:0|10:1501136353|11:PB3_SESSION|36:djJleDoxMDYuMTEuMzQuMjA4Ojg3NTk0ODkw|5815e5662ae397ebd0b7f3e16732b981ce68eab2e8066202ace593350c8935f8" forKey:NSHTTPCookieValue];
    //    [cookieProperties setObject:@"www.v2ex.com" forKey:NSHTTPCookieDomain];
    //    [cookieProperties setObject:[NSString stringWithFormat:@"cnrainbird.com-%@", timeStr] forKey:NSHTTPCookieOriginURL];
    //    [cookieProperties setObject:@"/" forKey:NSHTTPCookiePath];
    //    [cookieProperties setObject:@"0" forKey:NSHTTPCookieVersion];
    
    //    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:dict];
    //    sleep(5);
    !completionHandler ?: completionHandler();
    
    
    
}
//- (void)set {
//    if (isWK) {
//        WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
//        [cookieStroe setCookie:cookie completionHandler:nil];
//        //        return;
//    } else {
//        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
//    }
//}
- (void)addNewCookie {
    
    [self addNewNSHTTPCookie];
    
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    //set cookie
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    NSString *timeStr = [NSString stringWithFormat:@"%@", @([[NSDate date] timeIntervalSince1970])];
    dict[NSHTTPCookieName] = [NSString stringWithFormat:@"userid-%@", timeStr];
    dict[NSHTTPCookieValue] = @"123";
    dict[NSHTTPCookieDomain] = @"xxx.com";
    dict[NSHTTPCookiePath] = @"/";
    
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:dict];
    [cookieStroe setCookie:cookie completionHandler:^{
        //        NSLog(@"set cookie %@", timeStr);
        //缺陷，本地没有固化，App重启后，缓存消失。
        [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
            NSLog(@"All cookies %@",cookies);
            //- (void)showAlertIfNeeded {
            //FIXME:> ios8
            NSString *message = [NSString stringWithFormat:@"%@", @([cookies count])];
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"总cookie个数"message:message preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }];
            //                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:createCrashButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            //                    }];
            //                    [alertController addAction:okAction];
            [alertController addAction:cancelAction];
            
            [self presentAlertViewController:alertController];
            //}
            
            
        }];
    }];
    
    
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    
    for (NSHTTPCookie *cookie in cookies) {
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), cookie);
    }
    
}

- (void)logCookies {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), cookies);
    for (NSHTTPCookie *cookie in cookies) {
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述NSHTTPCookieStorage：%@", @(__PRETTY_FUNCTION__), @(__LINE__), cookie);
    }
    
    
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        for (NSHTTPCookie *cookie in cookies) {
            NSLog(@"🔴类名与方法名：%@（在第%@行），描述WKHTTPCookieStore：%@", @(__PRETTY_FUNCTION__), @(__LINE__), cookie);
        }
    }];
}

/**
 * 对于代码构建 UI 的项目一般在 didFinishLaunch 方法中初始化 window，
 * 想在 swizzling 方法中 present alertController 需要自己先初始化 window 并提供一个 rootViewController
 */
- (void)presentAlertViewController:(UIAlertController *)alertController {
    @try {
        id<UIApplicationDelegate> delegate = [UIApplication sharedApplication].delegate;
        /**
         * 判断项目是否是用 info.plist 配置 storyboard 的，
         * 是的话就不需要手动初始化 window 和 rootViewController
         */
        BOOL hasStoryboardInfo = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIMainStoryboardFile"];
        if (!hasStoryboardInfo) {
            delegate.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            delegate.window.rootViewController = [[UIViewController alloc] init];
        }
        [delegate.window makeKeyAndVisible];
        [delegate.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    } @catch (NSException *exception) {}
}
- (void)testWKCookiStore {
    
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    //    //set cookie
    //    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    //
    //    NSString *timeStr = [NSString stringWithFormat:@"%@", @([[NSDate date] timeIntervalSince1970])];
    //    dict[NSHTTPCookieName] = [NSString stringWithFormat:@"userid-%@", timeStr];
    //    dict[NSHTTPCookieValue] = @"123";
    //    dict[NSHTTPCookieDomain] = @"baidu.com";
    //    dict[NSHTTPCookiePath] = @"/";
    //
    //    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:dict];
    //    [cookieStroe setCookie:cookie completionHandler:^{
    //        NSLog(@"set cookie %@", timeStr);
    //    }];
    //
    //delete cookie
    //    [cookieStroe deleteCookie:cookie completionHandler:^{
    //        NSLog(@"delete cookie");
    //    }];
    
    
    //    sleep(5);
    
    //get cookies
    [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        NSLog(@"All cookies %@",cookies);
    }];
    // Do any additional setup after loading the view.
}
- (void)_schemeHandler
{
    //TODO:  ios11 API
    //FIXME: what is WKURLSchemeHandler?
    
    //    [_webView.configuration setURLSchemeHandler:self forURLScheme:@"scheme"];
    [_webView.configuration setURLSchemeHandler:self forURLScheme:@"data"];
    //file
    //    data
    
    //    [_webView.configuration setURLSchemeHandler:self forURLScheme:CYLHTTPSMethod];
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask {
    //随便返回个data，可以根据需求自定义
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), urlSchemeTask.description);
    NSData *data = [urlSchemeTask.request.URL.host dataUsingEncoding:(NSUTF8StringEncoding)];
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:urlSchemeTask.request.URL
                                                        MIMEType:@"text/html"
                                           expectedContentLength:data.length
                                                textEncodingName:nil];
    [urlSchemeTask didReceiveData:data];
    [urlSchemeTask didReceiveResponse:response];
    [urlSchemeTask didFinish];
}

/*!
 * 业界普遍认为 WKWebView 拥有自己的私有存储，不会将 Cookie 存入到标准的 Cookie 容器 NSHTTPCookieStorage 中。
 
 实践发现 WKWebView 实例其实也会将 Cookie 存储于 NSHTTPCookieStorage 中，但存储时机有延迟，在iOS 8上，当页面跳转的时候，当前页面的 Cookie 会写入 NSHTTPCookieStorage 中，而在 iOS 10 上，JS 执行 document.cookie 或服务器 set-cookie 注入的 Cookie 会很快同步到 NSHTTPCookieStorage 中，FireFox 工程师曾建议通过 reset WKProcessPool 来触发 Cookie 同步到 NSHTTPCookieStorage 中，实践发现不起作用，并可能会引发当前页面 session cookie 丢失等问题。
 
 
 所以那么到底有没有私有存储？还是统一存储到NSHTTPCookieStorage中？
 
 我猜测，是统一存到 NSHTTPCookieStorage 中，没必要存两份。之所以会有延迟，是异步存储的，至于WKWebView独立的cookie API，操作的应该都是内存级别的，最终都是更新 NSHTTPCookieStorage 中。
 */
- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask {
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), urlSchemeTask.description);
    NSLog(@"host %@",urlSchemeTask.request.URL.host);
}

- (void)updateWKHTTPCookieStoreDomainFromIP:(NSString *)IP toHost:(NSString *)host {
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        [[cookies copy] enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull cookie, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([cookie.domain isEqualToString:IP]) {
                NSMutableDictionary<NSHTTPCookiePropertyKey, id> *dict = [NSMutableDictionary dictionaryWithDictionary:cookie.properties];
                dict[NSHTTPCookieDomain] = host;
                NSHTTPCookie *newCookie = [NSHTTPCookie cookieWithProperties:[dict copy]];
                [cookieStroe setCookie:newCookie completionHandler:^{
                    [cookieStroe deleteCookie:cookie
                            completionHandler:^{
                                [self logCookies];
                            }];
                }];
            }
        }];
    }];
}

- (void)updateNSHTTPCookieStorageDomainFromIP:(NSString *)IP toHost:(NSString *)host {
    NSHTTPCookieStorage *cookieStroe = [NSHTTPCookieStorage sharedHTTPCookieStorage] ;
    NSArray *cookies = [cookieStroe cookies];
    [[cookies copy] enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull cookie, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([cookie.domain isEqualToString:IP]) {
            NSMutableDictionary<NSHTTPCookiePropertyKey, id> *dict = [NSMutableDictionary dictionaryWithDictionary:cookie.properties];
            dict[NSHTTPCookieDomain] = host;
            NSHTTPCookie *newCookie = [NSHTTPCookie cookieWithProperties:[dict copy]];
            [cookieStroe setCookie:newCookie];
            [cookieStroe deleteCookie:cookie];
            [self logCookies];
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    //111.206.193.95
    //@"http://3g.163.com"
    NSString *originalUrl = CYLOriginalUrl;
    NSURL *url = [NSURL URLWithString:originalUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [_webView loadRequest:request];
    
    //        [self changeCookieDomainFromIP:CYLIP toHost:CYLHOST];
    
}

- (NSHTTPCookie *)getNewCookieFromOldCookie:(NSHTTPCookie *)oldCookie host:(NSString *)host {
    NSMutableDictionary<NSHTTPCookiePropertyKey, id> *dict = [NSMutableDictionary dictionaryWithDictionary:oldCookie.properties];
    dict[NSHTTPCookieDomain] = host;
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:[dict copy]];
    NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), cookie);
    return cookie;
}

- (void)cookiesDidChangeInCookieStore:(WKHTTPCookieStore *)cookieStore {
    [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        NSLog(@"🔴类名与方法名：%@（在第%@行），描述：%@", @(__PRETTY_FUNCTION__), @(__LINE__), cookies);
    }];
    //    [self updateNSHTTPCookieStorageDomainFromIP:CYLIP toHost:CYLHOST];
}


@end
