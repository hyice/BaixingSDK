//
//  BXNetworkManager.m
//  BaixingSDK
//
//  Created by phoebus on 9/10/14.
//  Copyright (c) 2014 baixing. All rights reserved.
//

#import "BXNetworkManager.h"
#import "BXHttpRequest.h"
#import "BXHttpCache.h"
#import "BXHttpCacheObject.h"
#import "BXHttpResponseObject.h"
#import "BXError.h"
#import "BXDBManager.h"

#import <AFNetworking/AFNetworking.h>

extern NSString * const kBXHttpCacheObjectRequest;
extern NSString * const kBXHttpCacheObjectExpire;
extern NSString * const kBXHttpCacheObjectResponse;

@interface BXNetworkManager ()

@end

@implementation BXNetworkManager

+ (instancetype)shareManager
{
    static dispatch_once_t token;
    static BXNetworkManager *manager;

    dispatch_once(&token, ^{
        manager = [[BXNetworkManager alloc] initInstance];
    });

    return manager;
}

- (instancetype)initInstance
{
    self = [super init];

    if (self) {
        [[AFNetworkReachabilityManager sharedManager] startMonitoring];
        
        AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@""]];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        self.sessionManager = manager;
        
        // create cache db table.
        NSString *sql = @"create table if not exists net_caches (request text primary key, expire text, response blob);";
        [[BXDBManager shareManager] batchExecuteSql:sql];
    }

    return self;
}

- (instancetype)init
{
    return [BXNetworkManager shareManager];
}

- (BOOL)isReachable
{
    AFNetworkReachabilityStatus status = [AFNetworkReachabilityManager sharedManager].networkReachabilityStatus;
    
    if (status == AFNetworkReachabilityStatusReachableViaWiFi ||
        status == AFNetworkReachabilityStatusReachableViaWWAN ||
        status == AFNetworkReachabilityStatusUnknown /* AppStart status */ ) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isWiFiNetwork
{
    AFNetworkReachabilityStatus status = [AFNetworkReachabilityManager sharedManager].networkReachabilityStatus;
    
    if (status == AFNetworkReachabilityStatusReachableViaWiFi ||
        status == AFNetworkReachabilityStatusUnknown /* AppStart status */ ) {
        return YES;
    }
    
    return NO;
}

- (void)setReachabilityStatusChangeBlock:(void (^)(AFNetworkReachabilityStatus status))block
{
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:block];
}


- (void)requestByUrl:(NSString *)url
              method:(BX_HTTP_METHOD)method
              header:(NSDictionary *)header
          parameters:(NSDictionary *)parameters
            useCache:(BOOL)useCache
             success:(void (^)(id data))success
             failure:(void (^)(BXError *bxError))failure
{
    if (method == BX_GET) {
        // read cache data
        if (useCache) {
            NSString *cacheKey = [[BXHttpCache shareCache] httpCacheKey:url header:header parameters:parameters];
            BXHttpCacheObject *cacheObject = [[BXHttpCache shareCache] validCacheForKey:cacheKey];
            if (nil != cacheObject) {
                id response = [NSKeyedUnarchiver unarchiveObjectWithData:cacheObject.response];
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    success(response);
                });
                return;
            }
        }

        // send request
        [BXHttpRequest getByUrl:url header:header parameters:parameters success:^(NSURLSessionDataTask *task, id data) {
            BXHttpResponseObject *httpResponse = [[BXHttpResponseObject alloc] initWithObject:data];
            if (useCache) {
                NSString *cacheKey = [[BXHttpCache shareCache] httpCacheKey:url header:header parameters:parameters];
                [[BXHttpCache shareCache] setCache:httpResponse forKey:cacheKey];
            }

            success(httpResponse.result);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            BXError *bxError = [self transformError:error];
            failure(bxError);
        }];
    }
    else {
        // send request
        [BXHttpRequest postByUrl:url header:header parameters:parameters success:^(NSURLSessionDataTask *task, id data) {
            BXHttpResponseObject *httpResponse = [[BXHttpResponseObject alloc] initWithObject:data];
            success(httpResponse.result);
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            BXError *bxError = [self transformError:error];
            failure(bxError);
        }];
    }
}

- (void)requestMultipart:(NSString *)url
                fileName:(NSString *)fileName
                    file:(NSData *)fileData
              parameters:(NSDictionary *)parameters
                progress:(void (^)(long long writedBytes,long long totalBytes))progress
                 success:(void (^)(id data))success
                 failure:(void (^)(BXError *bxError))failure
{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    manager.requestSerializer = [AFHTTPRequestSerializer serializer];

    [manager POST:url parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:fileData name:@"file" fileName:fileName mimeType:@"multipart/form-data"];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        if (progress) {
            progress(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if ([responseObject isKindOfClass:[NSData class]]) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
            success(json);
        } else {
            success(responseObject);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        BXError *bxError = [self transformError:error];
        failure(bxError);
    }];
}

- (void)uploadDataByUrl:(NSString *)url
                 header:(NSDictionary *)header
                   file:(NSData *)file
             parameters:(NSDictionary *)parameters
                success:(void (^)(id data))success
                failure:(void (^)(BXError *bxError))failure
{
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:url parameters:parameters error:nil];
    
    // header
    for (id key in [header allKeys]) {
        id value = [header objectForKey:key];
        if (!value || ([value isKindOfClass:[NSString class]] && [value length] == 0)) {
            continue;
        }
        [request setValue:value forHTTPHeaderField:key];
    }
    
    [request setHTTPBody:file];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSURLSessionDataTask *task = [manager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (error) {
            BXError *bxError = [self transformError:error];
            failure(bxError);
            return;
        }

        success(responseObject);
    }];

    [task resume];
}

#pragma mark - private -
- (BXError *)transformError:(NSError *)error
{
    id responseData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];

    if (responseData == nil) {
        BXError *bxError = [BXError errorWithNSError:error type:kBXErrorNetwork];
        
        if (bxError.code == NSURLErrorNotConnectedToInternet) {
            bxError.bxMessage = @"网络异常，请稍后重试";
        }
        
        return bxError;
    }

    NSError *err = nil;
    BXError *bxError = [BXError errorWithNSError:error type:kBXErrorNetwork];
    NSDictionary *errDic = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:&err];

    if (err || ![errDic isKindOfClass:[NSDictionary class]]) {
        bxError.type      = kBxErrorJson;
        bxError.bxMessage = @"服务异常, 请稍后重试";
    }
    else {
        bxError.errDictionary = errDic;
        bxError.type          = kBXErrorServer;
        bxError.bxCode        = [[errDic objectForKey:@"error"] intValue];
        bxError.bxMessage     = [[errDic objectForKey:@"message"] description].length ? [errDic objectForKey:@"message"] : @"";
        
        NSDictionary *extDic = [errDic objectForKey:@"ext"];
        if (extDic && [extDic isKindOfClass:[NSDictionary class]] && (![extDic isEqual:[NSNull null]])) {
            bxError.bxExt          = [[BXErrorExt alloc] init];
            bxError.bxExt.bangui   = [extDic objectForKey:@"bangui"];
            bxError.bxExt.rule     = [extDic objectForKey:@"rule"];
            bxError.bxExt.ruleInfo = [extDic objectForKey:@"ruleInfo"];
            bxError.bxExt.action   = [extDic objectForKey:@"action"];
        }
    }
    return bxError;
}

@end
