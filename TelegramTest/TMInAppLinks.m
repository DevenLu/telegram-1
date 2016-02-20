//
//  TMInAppLinks.m
//  Telegram P-Edition
//
//  Created by Dmitry Kondratyev on 2/5/14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "TMInAppLinks.h"
#import "Telegram.h"
#import "TLPeer+Extensions.h"
#import "TGHeadChatPanel.h"
@implementation TMInAppLinks

+ (NSString *) userProfile:(int)user_id {
    return [NSString stringWithFormat:@"USER_PROFILE:%d", user_id];
}

+ (NSString *)peerProfile:(TLPeer*)peer jumpId:(int)jump_id {
    if(jump_id > 0) {
        return [NSString stringWithFormat:@"openWithPeer:%@:%d:%d",peer.className,peer.peer_id,jump_id];
    } else {
        return [self peerProfile:peer];
    }
    
}

+ (NSString *)peerProfile:(TLPeer*)peer {
    return [NSString stringWithFormat:@"openWithPeer:%@:%d",peer.className,peer.peer_id];
}

+ (void) parseUrlAndDo:(NSString *)url {
    NSArray *params = [url componentsSeparatedByString:@":"];
    if(params.count) {
        NSString *action = [params objectAtIndex:0];
        if([action isEqualToString:@"USER_PROFILE"]) {
            int user_id = [[params objectAtIndex:1] intValue];
            
            TL_conversation *conversation = [[[UsersManager sharedManager] find:user_id] dialog];
            
            [appWindow().navigationController showInfoPage:conversation];
            
            
            return;
        } else if([action isEqualToString:@"viabot"]) {
            NSString *botname = [params objectAtIndex:1];
            
            [appWindow().navigationController.messagesViewController setStringValueToTextField:[NSString stringWithFormat:@"%@ ",botname]];
            
            return;
        }
    }
    
    open_link(url);
}

@end
