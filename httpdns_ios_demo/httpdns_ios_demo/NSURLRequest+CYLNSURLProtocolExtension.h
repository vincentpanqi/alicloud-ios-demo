//
//  NSURLRequest+CYLNSURLProtocolExtension.h
//
//
//  Created by ElonChan on 28/07/2017.
//  Copyright © 2017 ChenYilong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLRequest (CYLNSURLProtocolExtension)

- (NSURLRequest *)cyl_getPostRequestIncludeBody;
- (NSMutableURLRequest *)cyl_getMutablePostRequestIncludeBody;

@end

@interface NSMutableURLRequest (CYLNSURLProtocolExtension)

- (void)cyl_handlePostRequestBody;

@end
