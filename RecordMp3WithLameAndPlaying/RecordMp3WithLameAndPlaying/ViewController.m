//
//  ViewController.m
//  RecordMp3WithLameAndPlaying
//
//  Created by Liushanpei on 2018/1/29.
//  Copyright © 2018年 Liushanpei. All rights reserved.
//

#import "ViewController.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "RecorderManager.h"

@interface VoiceModel :NSObject

@property (strong, nonatomic) NSURL * voiceUrl;
@property (strong, nonatomic) NSNumber * durationTime;


@end

@implementation VoiceModel

@end

@interface ViewController ()<RecorderManagerDelegate,UITableViewDelegate,UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UIButton *voiceBtn;
@property (weak, nonatomic) IBOutlet UIImageView *talksView;
@property (weak, nonatomic) IBOutlet UILabel *talksLabel;
@property (weak, nonatomic) IBOutlet UIView *backView;
@property (strong, nonatomic) RecorderManager * recorder;

@property (strong, nonatomic) NSMutableArray * recordingMp3Arrays;
@property (weak, nonatomic) IBOutlet UITableView *tableView;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.backView.layer.cornerRadius = 8;
    self.backView.layer.masksToBounds = YES;
    self.talksLabel.layer.cornerRadius = self.talksLabel.frame.size.height/2;
    self.talksLabel.layer.masksToBounds = YES;
    
    UILongPressGestureRecognizer *longPressGesUp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressUp:)];
    
    longPressGesUp.minimumPressDuration = 0.5;// 长按0.5秒后开始录音
    
    [self.voiceBtn addGestureRecognizer:longPressGesUp];
    self.recorder = [RecorderManager sharedInstance];
    self.recorder.delegate = self;
    self.recordingMp3Arrays = [NSMutableArray array];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:NSStringFromClass([UITableViewCell class])];
    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)touchDown:(id)sender {
    // 开始录制
    [self.recorder startRecording];
    self.backView.hidden = NO;
}
- (IBAction)touchUpInside:(id)sender {

    NSLog(@"说话声音太短");
    // 关闭录制
    if ([[UIDevice currentDevice] systemVersion].floatValue<9.0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.recorder cancelRecordingOrStopPlaying];
            
        });
    }
    else {
        [self.recorder cancelRecordingOrStopPlaying];
    }
    
    self.backView.hidden = YES;
}

- (void)longPressUp:(UILongPressGestureRecognizer *) press{

    CGPoint point = [press locationInView:self.voiceBtn];
    if (point.y<-35) {
        
        //  松开手指，取消发送
        [self.talksLabel setBackgroundColor:[UIColor redColor]];
        self.talksLabel.text = @"松开手指，取消发送";
    }
    else {
        //  手指上滑，取消发送
        [self.talksLabel setBackgroundColor:[UIColor clearColor]];
        self.talksLabel.text = @"手指上滑，取消发送";
    }
    
    if (press.state == UIGestureRecognizerStateBegan) {

    }
    else if (press.state == UIGestureRecognizerStateCancelled||press.state == UIGestureRecognizerStateEnded) {
        self.backView.hidden = YES;
        [self.talksLabel setBackgroundColor:[UIColor clearColor]];
        self.talksLabel.text = @"手指上滑，取消发送";
        
        if (point.y<-35) {
            /// 录音完成之后的处理，干嘛呢
            [self.recorder cancelRecordingOrStopPlaying];
        }
        else{
            [self.recorder stopRecording];
        }
    }
    else {
    }
    
}

#pragma mark - Delegate
// 音量代理
- (void)recordAudioPowerChange:(CGFloat )power{
    NSLog(@"Power%lf",power);
    
    // 语音-说话-0，语音-说话-1，语音-说话-2，语音-说话-3，语音-说话-4，语音-说话-5
    if (power<0.5) {
        self.talksView.image = [UIImage imageNamed:@"语音-说话-0"];
    }
    else if (power<0.60) {
        self.talksView.image = [UIImage imageNamed:@"语音-说话-1"];
        
    }
    else if (power<0.70) {
        self.talksView.image = [UIImage imageNamed:@"语音-说话-2"];
        
    }
    else if (power<0.80) {
        self.talksView.image = [UIImage imageNamed:@"语音-说话-3"];
        
    }
    else if (power<0.85) {
        self.talksView.image = [UIImage imageNamed:@"语音-说话-4"];
        
    }
    else {
        self.talksView.image = [UIImage imageNamed:@"语音-说话-5"];
    }
    
}

- (void)recordAudioFilePath:(NSURL *)filePathUrl andDuration:(float)time{
    NSLog(@"MP3Path: %@/ time:%f",filePathUrl,time);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        VoiceModel *model = [[VoiceModel alloc] init];
        model.durationTime = @(round(time));
        model.voiceUrl = filePathUrl;
        [self.recordingMp3Arrays addObject:model];
        [self.tableView reloadData];
    });

}
- (void)playRecordFinish:(NSURL *)playUrl {
    NSLog(@"FinishPlayUrl:%@",playUrl);
    // 是否播放下一条,暂时不处理
    
}

#pragma mark - tableView

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.recordingMp3Arrays.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class]) forIndexPath:indexPath];
    VoiceModel *model = self.recordingMp3Arrays[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"voice: %ld, duration: %@s",indexPath.row+1,model.durationTime];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    VoiceModel *model = self.recordingMp3Arrays[indexPath.row];
    [[RecorderManager sharedInstance] playMp3AudioWithUrl:model.voiceUrl];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
