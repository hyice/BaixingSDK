//
//  BXHttpRequest.h
//  BaixingSDK
//
//  Created by phoebus on 9/25/14.
//  Copyright (c) 2014 baixing. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BXHttpRequest : NSObject

+ (void)getByUrl:(NSString *)url
          header:(NSDictionary *)header
      parameters:(NSDictionary *)parameters
         success:( void (^) (NSURLSessionDataTask *task, id data) )success
         failure:( void (^) (NSURLSessionDataTask *task, NSError *error) )failure;

+ (void)postByUrl:(NSString *)url
           header:(NSDictionary *)header
       parameters:(NSDictionary *)parameters
          success:( void (^) (NSURLSessionDataTask *task, id data) )success
          failure:( void (^) (NSURLSessionDataTask *task, NSError *error) )failure;

@end
