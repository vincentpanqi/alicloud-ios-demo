//
//  NSMutableURLRequest+CYLNSURLProtocolExtension.h
//  httpdns_ios_demo
//
//  Created by 陈宜龙 on 28/07/2017.
//  Copyright © 2017 alibaba. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLRequest (CYLNSURLProtocolExtension)

- (NSMutableURLRequest *)cyl_getPostRequestIncludeBody;

@end


@interface NSMutableURLRequest (CYLNSURLProtocolExtension)

- (void)cyl_handlePostRequestBody;

@end
