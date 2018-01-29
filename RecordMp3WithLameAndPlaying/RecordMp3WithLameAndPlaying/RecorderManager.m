//
//  RecorderManager.m
//  yyClassroomJS
//
//  Created by Liushanpei on 2018/1/11.
//  Copyright © 2018年 whty. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "RecorderManager.h"
#import "ConvertAudioFile.h"
#define ETRECORD_RATE 11025.0

@interface RecorderManager ()<
AVAudioPlayerDelegate,
AVAudioRecorderDelegate
>
/**
 *  biubiu录音
 */
@property (nonatomic,strong)AVAudioRecorder *recorder;//音频录音机
/**
 *  biubiu的必须对player强持有。
 */
@property (nonatomic,strong) AVAudioPlayer *audioPlayer;//音频播放器，用于播放录音文件
@property (nonatomic,strong) NSTimer *timer;//录音声波监控（注意这里暂时不对播放进行监控）

@property (strong, nonatomic) NSURL * recordUrl;
@property (strong, nonatomic) NSURL * playUrl;

@property (assign, nonatomic) BOOL  isPlaying;

@end
@implementation RecorderManager

static RecorderManager *recorderManager = nil;

+ (RecorderManager *)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (recorderManager == nil) {
            recorderManager = [[RecorderManager alloc] init];
        }
    });
    return recorderManager;
}
- (instancetype)init {
    if (self= [super init]) {
        ;
    }
    return self;
}
- (void)stopRecording {
    [self.recorder stop];
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)startRecording {
    //创建录音文件保存路径
    NSURL *url=[self getSavePath];
    //创建录音格式设置
    NSDictionary *setting=[self getAudioSetting];
    //创建录音机
    NSError *error=nil;
    self.recorder=[[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
    self.recorder.delegate=self;
    self.recorder.meteringEnabled=YES;//如果要监控声波则必须设置为YES
    if (error) {
        NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
    }
//    [self.recorder recordForDuration:(NSTimeInterval) 60];//Maximum recording time : 60 seconds default

    [self setAudioSession];
}

- (void)cancelRecordingOrStopPlaying {
    if ([self.recorder isRecording]) {
        [self.recorder stop];
        if([self.recorder deleteRecording]){
            NSLog(@"删除成功");
        }
        if (self.timer) {
            [self.timer invalidate];
            self.timer = nil;
        }
    }
    else if([self.audioPlayer isPlaying]){
        [self.audioPlayer stop];
        NSLog(@"停止播放");
    }
    else {
        NSLog(@"弄啥呢，没啥东西在录制或播放");
    }
}

- (void)playMp3AudioWithUrl:(NSURL *)url {
    [self setPlayerAudioSession];
    if ([self.audioPlayer isPlaying]) {
        [self.audioPlayer stop];
    }
    NSString *filePath = [self createMp3PathWithYunPath:url.absoluteString];
    NSFileManager *man = [NSFileManager defaultManager];
    if ([man fileExistsAtPath:filePath]) {
        url = [NSURL fileURLWithPath:filePath];
        NSError *error=nil;
        self.audioPlayer=[[AVAudioPlayer alloc]initWithContentsOfURL:url error:&error];
        NSLog(@"%@",error.localizedDescription);
        self.audioPlayer.numberOfLoops=0;
        self.audioPlayer.delegate = self;
        self.audioPlayer.volume = 1;
        [self.audioPlayer prepareToPlay];
        if (error) {
            NSLog(@"创建播放器过程中发生错误，错误信息：%@",error.localizedDescription);

        }
        //1.一旦有物品靠近手机，离开手机时，都会发出通知。
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(sensorStateChange:) name:UIDeviceProximityStateDidChangeNotification object:nil];
        [UIDevice currentDevice].proximityMonitoringEnabled = YES; //播放前开启距离传感器

        [self.audioPlayer play];
        
        self.isPlaying = YES;
        self.playUrl = url;
    }
    else {
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            // 去下载
            NSLog(@"下载");
            NSData *data = [NSData dataWithContentsOfURL:url];
            if ([man createFileAtPath:filePath contents:data attributes:nil]){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self playMp3AudioWithUrl:url];
                });
                NSLog(@"下载完成");
                NSLog(@"%@",filePath);

            }
        });
    }

}


#pragma mark - 音量

-(void)audioPowerChange
{
    [self.recorder updateMeters];//更新测量值
    float power= [self.recorder averagePowerForChannel:0];//取得第一个通道的音频，注意音频强度范围时-160到0
    CGFloat progress=(1.0/160.0)*(power+160.0)-0.5;
    progress = progress/0.5;
    if ([self.delegate respondsToSelector:@selector(recordAudioPowerChange:)]) {
        [self.delegate recordAudioPowerChange:progress];
    }
}
- (void)setPlayerAudioSession {
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    //设置为播放和录音状态，以便可以在录制完之后播放录音
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
}

- (void)setAudioSession
{
    
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    //设置为播放和录音状态，以便可以在录制完之后播放录音
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession setActive:YES error:nil];
    
    if (![self.recorder isRecording]) {
        
        if ([[UIDevice currentDevice] systemVersion].floatValue<9.0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if ([self.recorder record]){
                    
                    self.timer =[NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(audioPowerChange) userInfo:nil repeats:YES];
                    [self.timer fire];
                };//首次使用应用时如果调用record方法会询问用户是否允许使用麦克风

            });
        }
        else {
            if ([self.recorder record]){
                
                self.timer =[NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(audioPowerChange) userInfo:nil repeats:YES];
                [self.timer fire];
            };//首次使用应用时如果调用record方法会询问用户是否允许使用麦克风

        }
        
    }
    else
    {
        [self.recorder pause];
        if (self.timer) {
            [self.timer invalidate];
            self.timer = nil;
        }
    }
}




/**
 *  获得录音文件保存位置
 *
 *  @return 录音文件位置
 */
-(NSURL *)getSavePath{
    NSString *urlStr=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    
    NSString *filepath = [NSString stringWithFormat:@"mp3voice/%ld_iOS.caf",(long)[[NSDate date] timeIntervalSince1970]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[urlStr stringByAppendingPathComponent:@"mp3voice"]]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[urlStr stringByAppendingPathComponent:@"mp3voice"] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    urlStr=[urlStr stringByAppendingPathComponent:filepath];
    NSLog(@"file path:%@",urlStr);
    NSURL *url=[NSURL fileURLWithPath:urlStr];
    self.recordUrl = url;
    return url;
}
- (NSString *)createMp3PathWithYunPath:(NSString *)yunPath {

    
    NSString *cacheLibStr=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *fileName = [[yunPath componentsSeparatedByString:@"/"] lastObject];/// 123142.mp3
    if (![[NSFileManager defaultManager] fileExistsAtPath:[cacheLibStr stringByAppendingPathComponent:@"mp3voice"]]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[cacheLibStr stringByAppendingPathComponent:@"mp3voice"] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *filePath = [[cacheLibStr stringByAppendingPathComponent:@"mp3voice"] stringByAppendingPathComponent:fileName];// 清除缓存时可清除文件夹
    
    return filePath;
}
/**
 *  录音文件信息设置
 *
 *  @return 录音设置
 */
-(NSDictionary *)getAudioSetting{
    NSMutableDictionary *dicM=[NSMutableDictionary dictionary];
    //    设置录音格式
    [dicM setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    //设置录音采样率，8000是电话采样率，对于一般录音已经够了
    [dicM setObject:@(ETRECORD_RATE) forKey:AVSampleRateKey];
    //设置通道,这里采用双声道
    [dicM setObject:@(2) forKey:AVNumberOfChannelsKey];
    //每个采样点位数,分为8、16、24、32
//    //比特采样率
    [dicM setObject:@(16) forKey: AVEncoderBitRateKey];
    [dicM setObject:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];

    return dicM;
}
#pragma mark - 获取时长
- (float)catchRecorderFileSecond:(NSURL *)url {
    NSDictionary *options = @{AVURLAssetPreferPreciseDurationAndTimingKey: @YES};
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:url options:options];
    CMTime audioDuration = audioAsset.duration;
    float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
    return audioDurationSeconds;
}

- (void)sensorStateChange:(NSNotification *)noti {

    if ([[UIDevice currentDevice] proximityState]) {
        NSLog(@"Device is close to user");
        //设置AVAudioSession 的播放模式
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        
    }else{
        NSLog(@"Device is not close to user");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
        
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
        
    }
}

#pragma mark ------------recorderDelegate --------------
-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{
    
    if ([self.delegate respondsToSelector:@selector(recordAudioFilePath:andDuration:)]&&[self catchRecorderFileSecond:self.recordUrl]>0) {
        [ConvertAudioFile conventToMp3WithCafFilePath:self.recordUrl.relativePath mp3FilePath:[self.recordUrl.relativePath stringByReplacingOccurrencesOfString:@".caf" withString:@".mp3"] sampleRate:ETRECORD_RATE callback:^(BOOL result) {
            if (result) {
               
                [self.delegate recordAudioFilePath:[NSURL URLWithString:[self.recordUrl.relativePath stringByReplacingOccurrencesOfString:@".caf" withString:@".mp3"]] andDuration:[self catchRecorderFileSecond:self.recordUrl]];
                NSError *error = nil;
                if (![[NSFileManager defaultManager] removeItemAtURL:self.recordUrl error:&error]) {
                    NSLog(@"%@",error);
                }
                NSLog(@"转换成功");
                [self playMp3AudioWithUrl:[NSURL URLWithString:[self.recordUrl.relativePath stringByReplacingOccurrencesOfString:@".caf" withString:@".mp3"]]];
            }
            else {
                NSLog(@"转换失败");
            }
        }];
    }

    
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSLog(@"播放完成!%d",flag);
    if ([self.delegate respondsToSelector:@selector(playRecordFinish:)]) {
        [self.delegate playRecordFinish:self.playUrl];
    }
    [[NSNotificationCenter defaultCenter]removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];  //移除通知
    [UIDevice currentDevice].proximityMonitoringEnabled = NO; //关闭距离传感器,节省电
}
@end
