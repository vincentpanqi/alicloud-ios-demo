//
//  NSData+CYLDataEncodingExtension.h
//  httpdns_ios_demo
//
//  Created by 陈宜龙 on 07/08/2017.
//  Copyright © 2017 alibaba. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (CYLDataEncodingExtension)

- (nullable NSData *)cyl_gunzippedData;

@end
