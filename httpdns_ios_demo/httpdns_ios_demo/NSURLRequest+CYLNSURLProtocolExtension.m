//
//  NSURLRequest+CYLNSURLProtocolExtension.h
//
//
//  Created by ElonChan on 28/07/2017.
//  Copyright © 2017 ChenYilong. All rights reserved.
//

#import "NSURLRequest+CYLNSURLProtocolExtension.h"

@implementation NSURLRequest (CYLNSURLProtocolExtension)

- (NSURLRequest *)cyl_getPostRequestIncludeBody {
    return [[self cyl_getMutablePostRequestIncludeBody] copy];
}

- (NSMutableURLRequest *)cyl_getMutablePostRequestIncludeBody {
    NSMutableURLRequest * req = [self mutableCopy];
    if ([self.HTTPMethod isEqualToString:@"POST"]) {
        if (!self.HTTPBody) {
            uint8_t d[1024] = {0};
            NSInputStream *stream = self.HTTPBodyStream;
            NSMutableData *data = [[NSMutableData alloc] init];
            [stream open];
            while ([stream hasBytesAvailable]) {
                NSInteger len = [stream read:d maxLength:1024];
                if (len > 0 && stream.streamError == nil) {
                    [data appendBytes:(void *)d length:len];
                }
            }
            req.HTTPBody = [data copy];
            [stream close];
        }
    }
    return req;
}

@end

@implementation NSMutableURLRequest (CYLNSURLProtocolExtension)

- (void)cyl_handlePostRequestBody {
    if ([self.HTTPMethod isEqualToString:@"POST"]) {
        if (!self.HTTPBody) {
            uint8_t d[1024] = {0};
            NSInputStream *stream = self.HTTPBodyStream;
            NSMutableData *data = [[NSMutableData alloc] init];
            [stream open];
            while ([stream hasBytesAvailable]) {
                NSInteger len = [stream read:d maxLength:1024];
                if (len > 0 && stream.streamError == nil) {
                    [data appendBytes:(void *)d length:len];
                }
            }
            self.HTTPBody = [data copy];
            [stream close];
        }
    }
}

@end
