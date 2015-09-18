//
//  TGMessageViewSender.m
//  Telegram
//
//  Created by keepcoder on 18.09.15.
//  Copyright (c) 2015 keepcoder. All rights reserved.
//

#import "TGMessageViewSender.h"
#import "TGTimer.h"
#import "TGTLSerialization.h"

@interface TGViewSender : NSObject
{
    TGTimer *timer;
    MTRequest *request;
    NSMutableArray *waitingItems;
}

@end


@implementation TGViewSender

-(instancetype)init {
    if(self = [super init]) {
        waitingItems = [[NSMutableArray alloc] init];
    }
    
    return self;
}

-(void)addItem:(MessageTableItem *)item {
    
    [ASQueue dispatchOnStageQueue:^{
        [waitingItems addObject:item];
        
        [timer invalidate];
        
        [[MTNetwork instance] cancelRequestWithInternalId:request.internalId];
        
        [request setCompleted:nil];
        
        timer = [[TGTimer alloc] initWithTimeout:3 repeat:NO completion:^{
            
            NSMutableArray *ids = [[NSMutableArray alloc] init];
            
            TL_conversation *conversation = [(MessageTableItem *)waitingItems[0] message].conversation;
            
            [waitingItems enumerateObjectsUsingBlock:^(MessageTableItem *obj, NSUInteger idx, BOOL *stop) {
                [ids addObject:@(obj.message.n_id)];
            }];
            
            
            request = [[MTRequest alloc] init];
            
            id body = [TLAPI_messages_getMessagesViews createWithPeer:conversation.inputPeer n_id:ids increment:YES];
            
            request.body = body;
            
            
            
            [request setPayload:[TGTLSerialization serializeMessage:body] metadata:body responseParser:^id(NSData *data) {
                
                NSMutableArray *vector = [[NSMutableArray alloc] init];
                
                SerializedData *stream = [[SerializedData alloc] init];
                NSInputStream *inputStream = [[NSInputStream alloc] initWithData:data];
                [inputStream open];
                // [stream setCacheData:data];
                [stream setInput:inputStream];
                
                int constructor = [stream readInt];
                
                if(constructor  == 481674261) {
                    int count = [stream readInt];
                    for(int i = 0; i < count; i++) {
                        int views = [stream readInt];
                        [vector addObject:@(views)];
                        
                    }
                }
                
            
                
                return vector;
                
            }];
            
            weakify();
            
            [request setCompleted:^(NSArray *result, NSTimeInterval t, id error) {
                
                
                [ASQueue dispatchOnStageQueue:^{
                    
                    assert(result.count == waitingItems.count);
                    
                    [strongSelf->waitingItems enumerateObjectsUsingBlock:^(MessageTableItem *obj, NSUInteger idx, BOOL *stop) {
                        obj.message.viewed = YES;
                        obj.message.views = [result[idx] intValue];
                        [obj.message save:NO];
                        
                    }];
                    
                    [strongSelf->waitingItems removeAllObjects];
                    
                }];
                
            }];
            
            [[MTNetwork instance] addRequest:request];
            
            
        } queue:[ASQueue globalQueue].nativeQueue];
        
        [timer start];
    }];
    
    
    
}

@end

@implementation TGMessageViewSender


static NSMutableDictionary *viewChannels;

+(void)initialize {
    viewChannels = [[NSMutableDictionary alloc] init];
}

+(void)addItem:(MessageTableItem *)item {
    
    [ASQueue dispatchOnStageQueue:^{
        
        TGViewSender *sender = viewChannels[@(item.message.peer_id)];
        
        if(!sender) {
            sender = [[TGViewSender alloc] init];
            viewChannels[@(item.message.peer_id)] = sender;
        }
        
        [sender addItem:item];
        
    }];
    
    
    
}

@end
