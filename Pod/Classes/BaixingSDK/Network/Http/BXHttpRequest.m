//
//  BXHttpRequest.m
//  BaixingSDK
//
//  Created by phoebus on 9/25/14.
//  Copyright (c) 2014 baixing. All rights reserved.
//

#import "BXHttpRequest.h"
#import "NSObject+BXOperation.h"
#import "BXNetworkManager.h"

#import "AFNetworking.h"

@implementation BXHttpRequest

+ (void)getByUrl:(NSString *)url
          header:(NSDictionary *)header
      parameters:(NSDictionary *)parameters
         success:( void (^) (NSURLSessionDataTask *task, id data) )success
         failure:( void (^) (NSURLSessionDataTask *task, NSError *error) )failure;
{    
    AFHTTPSessionManager *manager = [BXNetworkManager shareManager].sessionManager;
    
    // header
    for (id key in [header allKeys]) {
        id value = [header bx_safeObjectForKey:key];
        if (!value || ([value isKindOfClass:[NSString class]] && [value length] == 0)) {
            continue;
        }
        [manager.requestSerializer setValue:value forHTTPHeaderField:key];
    }
    
    // send request
    [manager GET:url parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        success(task, responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        failure(task, error);
    }];
}

+ (void)postByUrl:(NSString *)url
           header:(NSDictionary *)header
       parameters:(NSDictionary *)parameters
          success:( void (^) (NSURLSessionDataTask *task, id data) )success
          failure:( void (^) (NSURLSessionDataTask *task, NSError *error) )failure;
{
    AFHTTPSessionManager *manager = [BXNetworkManager shareManager].sessionManager;
    
    // header
    for (id key in [header allKeys]) {
        id value = [header bx_safeObjectForKey:key];
        if (!value || ([value isKindOfClass:[NSString class]] && [value length] == 0)) {
            continue;
        }
        [manager.requestSerializer setValue:value forHTTPHeaderField:key];
    }
    
    // send request
    [manager POST:url parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        success(task, responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        failure(task, error);
    }];
}

@end
