//
//  SocketRocketClient.m
//  Primus
//
//  Created by Nuno Sousa on 17/01/14.
//  Copyright (c) 2014 Seegno. All rights reserved.
//

#if __has_include(<SocketRocket/SRWebSocket.h>)

#import "SocketRocketClient.h"

typedef NS_ENUM(NSInteger, SocketRocketErrorCode) {
    kSocketRocketErrorCode = 1000,
    kSocketRocketErrorCodeNormal = 1000,
    kSocketRocketErrorCodeGoingAway = 1001,
    kSocketRocketErrorCodeProtocolError = 1002,
    kSocketRocketErrorCodeUnsupportedData = 1003,
    kSocketRocketErrorCodeReserved = 1004,
    kSocketRocketErrorCodeReservedForExtensions = 1005,
    kSocketRocketErrorCodeReservedForExtensions2 = 1006,
    kSocketRocketErrorCodeInconsistentOrInvalidData = 1007,
    kSocketRocketErrorCodePolicyViolation = 1008,
    kSocketRocketErrorCodeMessageTooBig = 1009,
    kSocketRocketErrorCodeExtensionHandshakeMissing = 1010,
    kSocketRocketErrorCodeAnUnexpectedConditionPreventedTheRequestFromBeingFulfilled = 1011
};

@implementation SocketRocketClient

- (id)initWithPrimus:(id<PrimusProtocol>)primus
{
    self = [super initWithPrimus:primus];

    if (self) {
        [_primus on:@"outgoing::open" selector:@selector(onOutgoingOpen) target:self];
        [_primus on:@"outgoing::data" selector:@selector(onOutgoingData:) target:self];
        [_primus on:@"outgoing::reconnect" selector:@selector(onOutgoingReconnect) target:self];
        [_primus on:@"outgoing::end" selector:@selector(onOutgoingEnd) target:self];
    }

    return self;
}

- (void)dealloc
{
    [_primus removeListener:@"outgoing::open" selector:@selector(onOutgoingOpen) target:self];
    [_primus removeListener:@"outgoing::data" selector:@selector(onOutgoingData:) target:self];
    [_primus removeListener:@"outgoing::reconnect" selector:@selector(onOutgoingReconnect) target:self];
    [_primus removeListener:@"outgoing::end" selector:@selector(onOutgoingEnd) target:self];
}

#pragma mark - Event listeners

- (void)onOutgoingOpen
{
    @try {
        _socket = [[SocketRocketWebSocket alloc] initWithURLRequest:_primus.request];

        _socket.delegate = self;
        _socket.stayConnectedInBackground = _primus.options.stayConnectedInBackground;

        [_socket open];
    }
    @catch (NSException *exception) {
        [_primus emit:@"incoming::error", exception];
    }
}

- (void)onOutgoingData:(id)data
{
    if (!_socket || SR_OPEN != _socket.readyState) {
        return;
    }

    @try {
//        [_socket send:data];
        //バイナリのまま送ると送信できなかったので、UTF8に変換してからsendメソッドを呼ぶように修正
        if( [data isKindOfClass:[NSString class]] ){
            [_socket send:data];
        }
        else{
            NSString *string = [[NSString alloc] initWithData:data
                                                     encoding:NSUTF8StringEncoding];
            [_socket send:string];
        }
    }
    @catch (NSException *exception) {
        [_primus emit:@"incoming::error", exception];
    }
}

- (void)onOutgoingReconnect
{
    if (_socket) {
        [_primus emit:@"outgoing::end"];
    }

    [_primus emit:@"outgoing::open"];

}

- (void)onOutgoingEnd
{
    if (! _socket) {
        return;
    }

    [_socket closeWithCode:kSocketRocketErrorCodeNormal reason:nil];
    _socket = nil;
}

#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    [_primus emit:@"incoming::open"];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [_primus emit:@"incoming::end", reason];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    [_primus emit:@"incoming::data", message];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    [_primus emit:@"incoming::error", error];
}

- (void)setStayConnectedInBackground:(BOOL)stayConnectedInBackground
{
    _primus.options.stayConnectedInBackground = stayConnectedInBackground;
    _socket.stayConnectedInBackground = stayConnectedInBackground;
}

@end

#endif
