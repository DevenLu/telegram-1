//
//  MessageTableItem.m
//  Telegram P-Edition
//
//  Created by Dmitry Kondratyev on 1/26/14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "MessageTableItem.h"
#import "MessageTableItemServiceMessage.h"
#import "MessageTableItemText.h"
#import "MessageTableItemPhoto.h"
#import "MessageTableItemVideo.h"
#import "MessageTableItemDocument.h"
#import "MessageTableItemGeo.h"
#import "MessageTableItemContact.h"
#import "MessageTableItemAudio.h"
#import "MessageTableItemGif.h"
#import "MessagetableitemUnreadMark.h"
#import "MessageTableItemAudioDocument.h"
#import "MessageTableItemServiceMessage.h"
#import "MessageTableItemSticker.h"
#import "MessageTableItemHole.h"
#import "TGDateUtils.h"
#import "PreviewObject.h"
#import "NSString+Extended.h"
#import "MessageTableHeaderItem.h"
#import "MessageTableItemSocial.h"
#import "TL_localMessage_old32.h"
#import "TL_localMessage_old34.h"
#import "TL_localMessage_old44.h"
#import "NSNumber+NumberFormatter.h"
#import "MessageTableItemMpeg.h"
#import "NSAttributedString+Hyperlink.h"
@interface TGItemCache : NSObject
@property (nonatomic,strong) NSMutableAttributedString *header;
@property (nonatomic,strong) TLUser *user;
@end


@implementation TGItemCache



@end

@interface MessageTableItem() <NSCopying>
@property (nonatomic) BOOL isChat;
@property (nonatomic) NSSize _viewSize;
@property (nonatomic,assign) BOOL autoStart;
@end

@implementation MessageTableItem


static NSCache *cItems;

- (id)initWithObject:(TL_localMessage *)object {
    self = [super init];
    if(self) {
        self.message = object;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            cItems = [[NSCache alloc] init];
            [cItems setCountLimit:100];
        });

        if(object.peer_id == [UsersManager currentUserId])
            object.flags&= ~TGUNREADMESSAGE;


        self.isForwadedMessage = self.message.fwd_from != nil;
        
        if(self.isForwadedMessage && [self.message.media isKindOfClass:[TL_messageMediaDocument class]] && ([self.message.media.document isSticker] || (self.message.media.document.audioAttr && !self.message.media.document.audioAttr.isVoice))) {
            self.isForwadedMessage = NO;
        }
        
        self.isChat = [self.message.to_id isKindOfClass:[TL_peerChat class]] || [self.message.to_id isKindOfClass:[TL_peerChannel class]];
        
        _containerOffset = 79;
        
        _containerOffsetForward = 87;
        
        
        if(self.message) {
            
            
            
            TGItemCache *cache = [cItems objectForKey:@(channelMsgId(_isChat ? 1 : 0, object.isPost ? object.peer_id : object.from_id))];
           
            if(cache) {
                _user = cache.user;
                if(_message.isPost) {
                    _user = _message.fromUser;
                }
                
                self.headerName = cache.header;
            } else {
                [self buildHeaderAndSaveToCache];
            }
            
             NSString *viaBotUserName;
            
            if(self.isViaBot) {
                
                if([self.message isKindOfClass:[TL_destructMessage45 class]]) {
                    viaBotUserName = ((TL_destructMessage45 *)self.message).via_bot_name;
                } else {
                     _via_bot_user = [[UsersManager sharedManager] find:self.message.via_bot_id];
                    viaBotUserName = _via_bot_user.username;
                }
               
                
                if(!self.isForwadedMessage)
                {
                    _headerName = [_headerName mutableCopy];
                    
                    [_headerName appendString:@" "];
                     NSRange range = [_headerName appendString:NSLocalizedString(@"ContextBot.Message.Via", nil) withColor:GRAY_TEXT_COLOR];
                    
                    [_headerName setFont:TGSystemFont(13) forRange:range];
                    
                    
                    [_headerName appendString:@" "];
                    range = [_headerName appendString:[NSString stringWithFormat:@"@%@",viaBotUserName] withColor:GRAY_TEXT_COLOR];
                    [_headerName addAttribute:NSForegroundColorAttributeName value:LINK_COLOR range:range];
                    [_headerName setLink:[NSString stringWithFormat:@"viabot:@%@",viaBotUserName] forRange:range];
                    
                    self.headerName = self.headerName;
                    
                }
                
                
                
            }
            
            if(self.isForwadedMessage) {
                
                if(object.fwd_from.from_id != 0) {
                    self.fwd_user = [[UsersManager sharedManager] find:object.fwd_from.from_id];
                }
                
                if(object.fwd_from.channel_id != 0) {
                    self.fwd_chat = [[ChatsManager sharedManager] find:object.fwd_from.channel_id];
                }
                
                NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
                
                [attr appendString:NSLocalizedString(@"Messages.ForwardedMessages", nil) withColor:GRAY_TEXT_COLOR];
                [attr setFont:TGSystemFont(13) forRange:attr.range];
                
                
                [attr detectAndAddLinks:URLFindTypeMentions];
                
                _forwardHeaderAttr = attr;
                
            }
            
            [self headerStringBuilder];
            
            [self rebuildDate];
            
            
            


            if(self.message.isPost) {
                [self updateViews];
            }
            
        }
    }
    return self;
}





-(int)makeSize {
    return MAX(NSWidth(((MessagesTableView *)self.table).viewController.view.frame) - 150,100);
}

-(void)buildHeaderAndSaveToCache {
    _user = self.message.fromUser;
    
    NSString *name = self.isChat ? self.user.fullName : self.user.dialogFullName;
    
    if(self.message.isPost)
    {
        name = self.message.conversation.chat.title;
    }
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    
    static NSColor * colors[6];
    static NSMutableDictionary *cacheColorIds;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colors[0] = NSColorFromRGB(0xce5247);
        colors[1] = NSColorFromRGB(0xcda322);
        colors[2] = NSColorFromRGB(0x5eaf33);
        colors[3] = NSColorFromRGB(0x468ec4);
        colors[4] = NSColorFromRGB(0xac6bc8);
        colors[5] = NSColorFromRGB(0xe28941);
        
        cacheColorIds = [[NSMutableDictionary alloc] init];
    });
    
    NSColor *nameColor = LINK_COLOR;
    
    
    if(self.isChat && !self.message.isPost && self.user.n_id != [UsersManager currentUserId]) {
        
        int colorMask = [TMAvatarImageView colorMask:self.user];
        
        nameColor = colors[colorMask % (sizeof(colors) / sizeof(colors[0]))];
        
    }
    
    NSMutableAttributedString *header = [[NSMutableAttributedString alloc] init];
    
    [header appendString:name withColor:nameColor];

    [header setFont:TGSystemMediumFont(13) forRange:header.range];
    
    [header addAttribute:NSLinkAttributeName value:[TMInAppLinks peerProfile:self.message.isPost ? self.message.peer : [TL_peerUser createWithUser_id:self.message.from_id]] range:header.range];
    
    self.headerName = header;
    
    
    TGItemCache *item = [[TGItemCache alloc] init];
    item.user = _user;
    item.header = header;
    
    long cacheId = channelMsgId(_isChat ? 1 : 0, _message.isPost ? _message.peer_id : _message.from_id);
    
    
    [cItems setObject:item forKey:@(cacheId)];
}

-(void)setHeaderName:(NSMutableAttributedString *)headerName {
    _headerName = headerName;
    
    self.headerSize = [self.headerName sizeForTextFieldForWidth:INT32_MAX];
}

- (void) headerStringBuilder {
    
    
    if([self isReplyMessage])
    {
        _replyObject = [[TGReplyObject alloc] initWithReplyMessage:self.message.replyMessage fromMessage:self.message tableItem:self];
            
    }
    
    if(self.isForwadedMessage) {
        self.forwardMessageAttributedString = [[NSMutableAttributedString alloc] init];
//        [self.forwardMessageAttributedString appendString:NSLocalizedString(@"Message.ForwardedFrom", nil) withColor:NSColorFromRGB(0x909090)];
        
        NSString *title = self.message.fwd_from.channel_id != 0 && !self.fwd_chat.isMegagroup ? self.fwd_chat.title : self.fwd_user.fullName ;
        
        NSRange rangeUser = NSMakeRange(0, 0);
        if(title) {
            rangeUser = [self.forwardMessageAttributedString appendString:title withColor:LINK_COLOR];
            [self.forwardMessageAttributedString setLink:[TMInAppLinks peerProfile:self.message.fwd_from.fwdPeer jumpId:self.message.fwd_from.channel_post] forRange:rangeUser];
            
        }
        
        [self.forwardMessageAttributedString setFont:TGSystemFont(12) forRange:self.forwardMessageAttributedString.range];
        
        
        if(self.message.fwd_from.channel_id != 0 && !self.message.chat.isMegagroup && self.message.fwd_from.from_id != 0) {
            [self.forwardMessageAttributedString appendString:@" (" withColor:LINK_COLOR];
            NSRange r = [self.forwardMessageAttributedString appendString:[NSString stringWithFormat:@"%@",self.fwd_user.first_name] withColor:LINK_COLOR];
            [self.forwardMessageAttributedString appendString:@")" withColor:LINK_COLOR];
            
            [self.forwardMessageAttributedString setLink:[TMInAppLinks peerProfile:self.message.fwd_from.fwdPeer] forRange:r];
            
            [self.forwardMessageAttributedString setFont:TGSystemMediumFont(13) forRange:r];
        }
        
        if([self isViaBot]) {
            [self.forwardMessageAttributedString appendString:@" "];
            NSRange range = [self.forwardMessageAttributedString appendString:NSLocalizedString(@"ContextBot.Message.Via", nil) withColor:GRAY_TEXT_COLOR];
            [self.forwardMessageAttributedString setFont:TGSystemFont(13) forRange:range];
            [self.forwardMessageAttributedString appendString:@" "];
            range = [self.forwardMessageAttributedString appendString:[NSString stringWithFormat:@"@%@",_via_bot_user.username] withColor:GRAY_TEXT_COLOR];
            [self.forwardMessageAttributedString setFont:TGSystemBoldFont(13) forRange:range];
            [self.forwardMessageAttributedString setLink:[NSString stringWithFormat:@"viabot:@%@",_via_bot_user.username] forRange:range];
            [self.forwardMessageAttributedString addAttribute:NSForegroundColorAttributeName value:LINK_COLOR range:range];
        }
        
         [self.forwardMessageAttributedString appendString:@"  " withColor:NSColorFromRGB(0x909090)];
    
        [self.forwardMessageAttributedString appendString:[TGDateUtils stringForLastSeen:self.message.fwd_from.date] withColor:NSColorFromRGB(0xbebebe)];
        
        
        [self.forwardMessageAttributedString setFont:TGSystemMediumFont(13) forRange:rangeUser];
        


    }
}

static NSTextAttachment *channelIconAttachment() {
    static NSTextAttachment *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [NSMutableAttributedString textAttachmentByImage:[image_newConversationBroadcast() imageWithInsets:NSEdgeInsetsMake(0, 1, 0, 4)]];
    });
    return instance;
}

- (void)setViewSize:(NSSize)viewSize {
    self._viewSize = viewSize;
}

- (NSSize)viewSize {
    NSSize viewSize = self._viewSize;
    
    if(!self.message.hole && ![self isKindOfClass:[MessageTableItemServiceMessage class]] && ![self isKindOfClass:[MessageTableItemUnreadMark class]] && ![self isKindOfClass:[MessageTableHeaderItem class]]) {
        if(self.isHeaderMessage) {
            viewSize.height += 32;
            
            if(self.isForwadedMessage)
                viewSize.height += 20;
            
//            if(self.isViaBot && !self.isForwadedMessage) {
//                viewSize.height+=16;
//                if(self.message.media != nil && ![self.message.media isKindOfClass:[TL_messageMediaWebPage class]] && ![self isReplyMessage]) {
//                    
//                    if([self.message.media isKindOfClass:[TL_messageMediaBotResult class]] && ![self.message.media.bot_result.send_message isKindOfClass:[TL_botInlineMessageText class]])
//                    viewSize.height+=6;
//                }
//            }
            
            
            if(viewSize.height < 44)
                viewSize.height = 44;
        } else {
            viewSize.height += 10;
            
            if(self.isForwadedMessage)
                viewSize.height += 18;

        }
        
        if([self isReplyMessage]) {
            viewSize.height +=self.replyObject.containerHeight+10;
        }
        
        if(self.isForwadedMessage && self.isHeaderForwardedMessage)
            viewSize.height += FORWARMESSAGE_TITLE_HEIGHT;
    }
    
    if(viewSize.height < 0)
        viewSize.height = 32;
    
    
    if([self.message.action isKindOfClass:[TL_messageActionChatMigrateTo class]]) {
        viewSize.height = 1;
    }
    
    return viewSize;
}

-(BOOL)isViaBot {
    return self.message.via_bot_id != 0 || ([self.message isKindOfClass:[TL_destructMessage45 class]] && ((TL_destructMessage45 *)self.message).via_bot_name.length > 0);
}

- (void) setBlockSize:(NSSize)blockSize {
    self->_blockSize = blockSize;
    
    self.viewSize = NSMakeSize(blockSize.width, blockSize.height);
}


+ (NSArray *)messageTableItemsFromMessages:(NSArray *)input {
    NSMutableArray *array = [NSMutableArray array];
    for(TLMessage *message in input) {
        MessageTableItem *item = [MessageTableItem messageItemFromObject:message];
        if(item) {
            item.isSelected = NO;
            [array insertObject:item atIndex:0];
        }
    }
    return array;
}

+ (id) messageItemFromObject:(TL_localMessage *)message {
    id objectReturn = nil;

    
    @try {
        if(message.class == [TL_localMessage_old46 class] || message.class == [TL_localMessage class] || message.class == [TL_localMessage_old32 class] || message.class == [TL_localMessage_old34 class] || message.class == [TL_localMessage_old44 class] || message.class == [TL_destructMessage class] || message.class == [TL_destructMessage45 class]) {
            
            if((message.media == nil || [message.media isKindOfClass:[TL_messageMediaEmpty class]]) || [message.media isMemberOfClass:[TL_messageMediaWebPage class]]) {
                
                objectReturn = [[MessageTableItemText alloc] initWithObject:message];
                
            } else if([message.media isKindOfClass:[TL_messageMediaUnsupported class]]) {
                
                message.message = @"This message is not supported on your version of Telegram. Update the app to view: https://telegram.org/dl/osx";
                objectReturn = [[MessageTableItemText alloc] initWithObject:message ];
                
            } else if([message.media isKindOfClass:[TL_messageMediaPhoto class]]) {
                
                objectReturn = [[MessageTableItemPhoto alloc] initWithObject:message ];
                
            } else if([message.media isKindOfClass:[TL_messageMediaVideo class]]) {
                
                objectReturn = [[MessageTableItemVideo alloc] initWithObject:message ];
                
            } else if([message.media isKindOfClass:[TL_messageMediaDocument class]] || [message.media isKindOfClass:[TL_messageMediaDocument_old44 class]]) {
                
                TLDocument *document = message.media.document;
            
                TL_documentAttributeAnimated *attr = (TL_documentAttributeAnimated *) [document attributeWithClass:[TL_documentAttributeAnimated class]];
                
                TL_documentAttributeAudio *audioAttr = (TL_documentAttributeAudio *) [document attributeWithClass:[TL_documentAttributeAudio class]];
                
                if([document.mime_type hasPrefix:@"video"] && attr != nil) {
                    objectReturn = [[MessageTableItemMpeg alloc] initWithObject:message];
                } else if([document.mime_type hasPrefix:@"video"] && [document attributeWithClass:[TL_documentAttributeVideo class]] != nil) {
                    objectReturn = [[MessageTableItemVideo alloc] initWithObject:message];
                } else if([document.mime_type isEqualToString:@"image/gif"] && ![document.thumb isKindOfClass:[TL_photoSizeEmpty class]]) {
                    objectReturn = [[MessageTableItemGif alloc] initWithObject:message];
                } else if((audioAttr && !audioAttr.isVoice) || ([document.mime_type isEqualToString:@"audio/mpeg"])) {
                    objectReturn = [[MessageTableItemAudioDocument alloc] initWithObject:message];
                } else if([document isSticker]) {
                    objectReturn = [[MessageTableItemSticker alloc] initWithObject:message];
                } else if((audioAttr && audioAttr.isVoice) || [message.media.document.mime_type isEqualToString:@"audio/ogg"]) {
                    objectReturn = [[MessageTableItemAudio alloc] initWithObject:message];
                } else {
                    objectReturn = [[MessageTableItemDocument alloc] initWithObject:message];
                }
                
            } else if([message.media isKindOfClass:[TL_messageMediaContact class]]) {
                
                objectReturn = [[MessageTableItemContact alloc] initWithObject:message];
                
            } else if([message.media isKindOfClass:[TL_messageMediaGeo class]] || [message.media isKindOfClass:[TL_messageMediaVenue class]]) {
                
                objectReturn = [[MessageTableItemGeo alloc] initWithObject:message];
                
            }  else if([message.media isKindOfClass:[TL_messageMediaBotResult class]]) {
                
                if([message.media.bot_result.send_message isKindOfClass:[TL_botInlineMessageText class]]) {
                    objectReturn = [[MessageTableItemText alloc] initWithObject:message];
                }
                
                if([message.media.bot_result.send_message isKindOfClass:[TL_botInlineMessageMediaAuto class]]) {
                    
                    if([message.media.bot_result isKindOfClass:[TL_botInlineMediaResultDocument class]]) {
                        if(([message.media.bot_result.document.mime_type isEqualToString:@"video/mp4"] && [message.media.bot_result.document attributeWithClass:[TL_documentAttributeAnimated class]]))
                            objectReturn = [[MessageTableItemMpeg alloc] initWithObject:message];
                    } else if([message.media.bot_result isKindOfClass:[TL_botInlineMediaResultPhoto class]])
                        objectReturn = [[MessageTableItemPhoto alloc] initWithObject:message];
                    else if([message.media.bot_result isKindOfClass:[TL_botInlineResult class]]) {
                        
                        if(([message.media.bot_result.content_type isEqualToString:@"video/mp4"] && [message.media.bot_result.type isEqualToString:@"gif"])) {
                            objectReturn = [[MessageTableItemMpeg alloc] initWithObject:message];
                        } else if([message.media.bot_result.type isEqualToString:@"photo"]) {
                            objectReturn = [[MessageTableItemPhoto alloc] initWithObject:message];
                        }
 
                    }
                    
                }
                
                if(!objectReturn) {
                    message.message = @"This message is not supported on your version of Telegram. Update the app to view: https://telegram.org/dl/osx";
                    objectReturn = [[MessageTableItemText alloc] initWithObject:message];
                }
                
            }
        } else if(message.hole != nil) {
            objectReturn = [[MessageTableItemHole alloc] initWithObject:message];
        } else if([message isKindOfClass:[TL_localMessageService class]] || [message isKindOfClass:[TL_secretServiceMessage class]]) {
            
             objectReturn = [[MessageTableItemServiceMessage alloc] initWithObject:message ];
        }

    }
    @catch (NSException *exception) {
        int bp = 0;
    }
    

    
    return objectReturn;
}

+(Class)socialClass:(NSString *)message {
    
    if(message == nil)
        return [NSNull class];
    
    NSDataDetector *detect = [[NSDataDetector alloc] initWithTypes:1ULL << 5 error:nil];
    
    
    NSArray *results = [detect matchesInString:message options:0 range:NSMakeRange(0, [message length])];

    
    if(results.count != 1)
        return [NSNull class];
    
    NSRange range = [results[0] range];
    
    if(range.location != 0 || range.length != message.length)
        return [NSNull class];

    // youtube checker
    
     NSString *vid = [YoutubeServiceDescription idWithURL:message];
    
    
    if(vid.length > 0)
        return [YoutubeServiceDescription class];
    
    
    NSString *iid = [InstagramServiceDescription idWithURL:message];
    
    if(iid.length > 0)
        return [InstagramServiceDescription class];
    
    return [NSNull class];
    
    
}

-(void)clean {
    [self.messageSender cancel];
    self.messageSender = nil;
    [self.downloadItem cancel];
    self.downloadItem = nil;
}

-(DownloadItem *)downloadItem {
    if(_downloadItem == nil)
        _downloadItem = [DownloadQueue find:self.message.n_id];
    
    return _downloadItem;

}

-(void)rebuildDate {
    self.date = [NSDate dateWithTimeIntervalSince1970:self.message.date];
    
    int time = self.message.date;
    time -= [[MTNetwork instance] getTime] - [[NSDate date] timeIntervalSince1970];
    
    self.dateStr = [TGDateUtils stringForMessageListDate:time];
    NSSize dateSize = [self.dateStr sizeWithAttributes:@{NSFontAttributeName: TGSystemFont(12)}];
    dateSize.width = roundf(dateSize.width)+5;
    dateSize.height = roundf(dateSize.height);
    self.dateSize = dateSize;
    
    NSDateFormatter *formatter = [NSDateFormatter new];
    
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.message.date];
    
    self.fullDate = [formatter stringFromDate:date];
}


- (Class)downloadClass {
    return [NSNull class];
}

- (BOOL)canDownload {
    return NO;
}

- (BOOL)isset {
    return YES;
}

-(BOOL)canShare {
    return NO;
}

-(NSURL *)shareObject {
    return [NSURL fileURLWithPath:mediaFilePath(self.message)];
}

- (BOOL)needUploader {
    return NO;
}

- (void)doAfterDownload {
    _downloadItem = nil;
}


- (void)checkStartDownload:(SettingsMask)setting size:(int)size {
    self.autoStart = [SettingsArchiver checkMaskedSetting:setting];
    
    if(size > [SettingsArchiver autoDownloadLimitSize])
        self.autoStart = NO;

        
    if((self.autoStart && !self.downloadItem && !self.isset) || (self.downloadItem && self.downloadItem.downloadState != DownloadStateCanceled)) {
        [self startDownload:NO force:NO];
    }
    
}

-(id)identifier {
    return @(self.message.n_id);
}


-(NSString *)string {
    return ((MessageTableItemText *)self).textAttributed.string;
}

- (void)startDownload:(BOOL)cancel force:(BOOL)force {


    DownloadItem *downloadItem = self.downloadItem;
    
    if(!downloadItem) {
        downloadItem = [[[self downloadClass] alloc] initWithObject:self.message];
    }
    
    if((downloadItem.downloadState == DownloadStateCanceled || downloadItem.downloadState == DownloadStateWaitingStart) && (force || self.autoStart)) {
        [downloadItem start];
    }
    
}


-(BOOL)isReplyMessage {
    return (self.message.reply_to_msg_id != 0 && ![self.message.replyMessage isKindOfClass:[TL_localEmptyMessage class]]) || ([self.message isKindOfClass:[TL_destructMessage45 class]] && ((TL_destructMessage45 *)self.message).reply_to_random_id != 0);
}

-(BOOL)isFwdMessage {
    return self.message.fwd_from != nil;
}

- (BOOL)makeSizeByWidth:(int)width {
    _blockWidth = width;
        
    return NO;
}

-(int)fontSize {
    return [SettingsArchiver checkMaskedSetting:BigFontSetting] ? 15 : 13;
}


-(BOOL)updateViews {
    
    NSAttributedString *o = _viewsCountAndSign;
    
    NSMutableAttributedString *signString = [[NSMutableAttributedString alloc] init];
    
    NSRange range = [signString appendString:[@(MAX(1,self.message.views)) prettyNumber] withColor:GRAY_TEXT_COLOR];
    
    if(self.message.isPost && self.message.from_id != 0) {
        [signString appendString:@" "];
        range = [signString appendString:_user.fullName withColor:GRAY_TEXT_COLOR];
        [signString setLink:[TMInAppLinks peerProfile:[TL_peerUser createWithUser_id:_user.n_id]] forRange:range];
    }
    
    _viewsCountAndSignSize = [signString sizeForTextFieldForWidth:INT32_MAX];
    _viewsCountAndSignSize.width =_viewsCountAndSignSize.width;
    _viewsCountAndSignSize.height = 17;
    
    [signString setFont:TGSystemFont(12) forRange:signString.range];
    
    _viewsCountAndSign = signString;
    
    return ![_viewsCountAndSign.string isEqualToString:o.string];
    
}

-(id)copy {
    MessageTableItem *item = [MessageTableItem messageItemFromObject:self.message];
    
    item.messageSender = self.messageSender;
    
    return item;
}


-(id)copyWithZone:(NSZone *)zone {
    return [self copy];
}

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *dateF = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateF = [[NSDateFormatter alloc] init];
    });
    return dateF;
}

@end
