//
//  TSMutableDictionary.h
//  Outlander
//
//  Created by Joseph McBride on 1/26/14.
//  Copyright (c) 2014 Joe McBride. All rights reserved.
//
// https://mikeash.com/pyblog/friday-qa-2011-10-14-whats-new-in-gcd.html

#import <Foundation/Foundation.h>

@interface TSMutableDictionary : NSObject {

    NSMutableDictionary *_cache;
    dispatch_queue_t _queue;
}
- (id)initWithName:(NSString *)queueName;
- (id)cacheObjectForKey: (id)key;
- (void)setCacheObject: (id)obj forKey: (id)key;
- (BOOL)cacheDoesContain: (id)key;
- (NSArray *)allItems;
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block;
@end
