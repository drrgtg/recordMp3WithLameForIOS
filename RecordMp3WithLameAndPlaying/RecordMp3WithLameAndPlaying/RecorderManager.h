//
//  RecorderManager.h
//  yyClassroomJS
//
//  Created by Liushanpei on 2018/1/11.
//  Copyright © 2018年 whty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol   RecorderManagerDelegate <NSObject>
@optional

// 音量代理
- (void)recordAudioPowerChange:(CGFloat )power;

- (void)recordAudioFilePath:(NSURL *)filePathUrl andDuration:(float )time;

- (void)playRecordFinish:(NSURL *) playUrl;

@end

@interface RecorderManager : NSObject

+ (instancetype)sharedInstance;


@property (weak, nonatomic) id<RecorderManagerDelegate>  delegate;



- (void)startRecording;
- (void)stopRecording;

- (void)cancelRecordingOrStopPlaying;


- (void)playMp3AudioWithUrl:(NSURL *)url;


@end
