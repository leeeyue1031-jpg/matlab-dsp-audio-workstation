clear;
clc;
close all;


%% 1. 基本参数

fs = 8000;              % 采样频率
bpm = 72;               % 舒缓速度，每分钟72拍
oneBeatTime = 60 / bpm; % 一拍持续时间

fprintf('当前速度：%d BPM\n', bpm);
fprintf('每拍持续时间：%.3f 秒\n\n', oneBeatTime);

%% 2. 最终播放使用的参数

% 最终播放使用指数包络，听感更柔和
finalEnvelopeType = 'exp';

% 使用二次、三次谐波
useHarmonics = true;

% 音量
masterVolume = 0.85;

%% 3. D大调频率表显示

fprintf('D大调中音区频率表：\n');
fprintf('1(do)  = 293.66 Hz\n');
fprintf('2(re)  = 329.63 Hz\n');
fprintf('3(mi)  = 369.99 Hz\n');
fprintf('4(fa)  = 392.00 Hz\n');
fprintf('5(sol) = 440.00 Hz\n');
fprintf('6(la)  = 493.88 Hz\n');
fprintf('7(si)  = 554.37 Hz\n\n');

%% 4. 《鸟之诗》简化旋律
%
% 编码规则：
% 0      = 休止符
% 1~7    = 中音1~7
% 11~17  = 高音1~7
% 21~27  = 更高音1~7
% -1~-7  = 低音1~7
%
% 每一行单独写，避免数组行长度不同导致vertcat报错。

score1 = [ ...
    6 7 11 15 13 13 12 13 12 13 15 11 7 11 ...
];

score2 = [ ...
    7 7 6 3 7 11 12 15 13 13 12 13 ...
];

score3 = [ ...
    12 13 15 13 15 11 7 6 3 12 13 15 16 17 ...
];

score4 = [ ...
    23 23 22 23 22 23 25 21 17 21 17 7 6 3 ...
];

score5 = [ ...
    16 17 11 15 13 13 12 13 12 13 15 13 15 11 17 ...
];

score6 = [ ...
    6 ...
];

score = [score1 score2 score3 score4 score5 score6];

%% 5. 每个音符的拍数
%
% 这里根据舒缓歌曲听感重新安排时值。
%
% 0.25 = 四分之一拍
% 0.5  = 半拍
% 1    = 一拍
% 1.5  = 一拍半
% 2    = 两拍
%
% 每一组beats必须与对应score元素数量一致。

beats1 = [ ...
    0.5 0.5 1.0 1.5 0.5 0.5 0.5 0.5 ...
    0.5 0.5 1.0 1.0 0.5 1.5 ...
];

beats2 = [ ...
    0.5 0.5 0.5 1.0 0.5 0.5 ...
    0.5 1.5 0.5 0.5 0.5 1.5 ...
];

beats3 = [ ...
    0.5 0.5 1.0 0.5 1.0 1.0 0.5 ...
    0.5 1.0 0.5 0.5 0.5 0.5 1.5 ...
];

beats4 = [ ...
    0.5 0.5 0.5 0.5 0.5 0.5 1.0 ...
    0.5 0.5 1.0 1.0 0.5 0.5 1.5 ...
];

beats5 = [ ...
    0.5 0.5 1.0 1.5 0.5 0.5 0.5 0.5 ...
    0.5 0.5 1.0 0.5 1.0 1.0 1.5 ...
];

beats6 = [ ...
    2.5 ...
];

beats = [beats1 beats2 beats3 beats4 beats5 beats6];

%% 6. 检查乐谱与时值数量

fprintf('乐谱音符数量：%d\n', length(score));
fprintf('时值数量：%d\n\n', length(beats));

if length(score) ~= length(beats)
    error('score和beats的元素数量不一致，请检查乐谱。');
end

%% 7. 句间休止时间
%
% pauseAfter表示每一个音之后额外增加多少拍的休止。
% 默认没有休止，句尾位置增加较短停顿。

pauseAfter = zeros(size(score));

lineEnd1 = length(score1);
lineEnd2 = lineEnd1 + length(score2);
lineEnd3 = lineEnd2 + length(score3);
lineEnd4 = lineEnd3 + length(score4);
lineEnd5 = lineEnd4 + length(score5);

pauseAfter(lineEnd1) = 0.5;
pauseAfter(lineEnd2) = 0.5;
pauseAfter(lineEnd3) = 0.75;
pauseAfter(lineEnd4) = 0.75;
pauseAfter(lineEnd5) = 1.0;
pauseAfter(end) = 1.5;

%% 8. 生成最终音乐

music = [];

for k = 1:length(score)

    currentCode = score(k);
    currentBeats = beats(k);

    oneNote = makeNote( ...
        currentCode, ...
        currentBeats, ...
        oneBeatTime, ...
        fs, ...
        finalEnvelopeType, ...
        useHarmonics);

    music = [music oneNote];

    % 在句尾加入休止
    if pauseAfter(k) > 0

        pauseDuration = pauseAfter(k) * oneBeatTime;
        pauseSamples = round(pauseDuration * fs);

        silence = zeros(1, pauseSamples);

        music = [music silence];
    end

end

%% 9. 整体归一化

if max(abs(music)) > 0
    music = masterVolume * music / max(abs(music));
end

%% 10. 播放最终音乐

disp('开始播放《鸟之诗》电子合成版本……');

sound(music, fs);

%% 11. 保存最终音乐

audiowrite('bird_song_final.wav', music, fs);

disp('已保存：bird_song_final.wav');

%% 12. 绘制完整音乐时域波形

musicTime = (0:length(music)-1) / fs;

figure;

plot(musicTime, music);

xlabel('时间 / s');
ylabel('幅度');
title('《鸟之诗》完整合成音乐时域波形');
grid on;

%% 13. 生成三种包络版本，用于比较
%
% PDF要求：
% 1. 包络修正前
% 2. 折线包络修正后
% 3. 指数衰减包络修正后
%
% 这里选择前三个音进行比较。

firstThreeScore = score(1:3);
firstThreeBeats = beats(1:3);

rawPart = [];
linePart = [];
expPart = [];

for k = 1:3

    rawNote = makeNote( ...
        firstThreeScore(k), ...
        firstThreeBeats(k), ...
        oneBeatTime, ...
        fs, ...
        'none', ...
        false);

    lineNote = makeNote( ...
        firstThreeScore(k), ...
        firstThreeBeats(k), ...
        oneBeatTime, ...
        fs, ...
        'line', ...
        false);

    expNote = makeNote( ...
        firstThreeScore(k), ...
        firstThreeBeats(k), ...
        oneBeatTime, ...
        fs, ...
        'exp', ...
        false);

    rawPart = [rawPart rawNote];
    linePart = [linePart lineNote];
    expPart = [expPart expNote];

end

compareTime = (0:length(rawPart)-1) / fs;

figure;

subplot(3,1,1);

plot(compareTime, rawPart);

xlabel('时间 / s');
ylabel('幅度');
title('前三个音：包络修正前');
grid on;

subplot(3,1,2);

plot(compareTime, linePart);

xlabel('时间 / s');
ylabel('幅度');
title('前三个音：折线包络修正后');
grid on;

subplot(3,1,3);

plot(compareTime, expPart);

xlabel('时间 / s');
ylabel('幅度');
title('前三个音：指数衰减包络修正后');
grid on;

%% 14. 单独画出两种包络曲线

testDuration = beats(1) * oneBeatTime;
testSamples = round(testDuration * fs);

normalizedTime = linspace(0, 1, testSamples);

% 折线包络
pointX = [0 1/5 1/3 2/3 1];
pointY = [0 1 0.7 0.7 0];

lineEnvelope = interp1( ...
    pointX, ...
    pointY, ...
    normalizedTime, ...
    'linear');

% 指数包络
expEnvelope = ...
    (normalizedTime.^4) .* ...
    exp(-8 * sqrt(normalizedTime));

if max(expEnvelope) > 0
    expEnvelope = expEnvelope / max(expEnvelope);
end

expEnvelope = expEnvelope .* (1 - normalizedTime);

envelopeTime = (0:testSamples-1) / fs;

figure;

subplot(2,1,1);

plot(envelopeTime, lineEnvelope);

xlabel('时间 / s');
ylabel('幅度');
title('折线包络');
grid on;

subplot(2,1,2);

plot(envelopeTime, expEnvelope);

xlabel('时间 / s');
ylabel('幅度');
title('指数衰减包络');
grid on;

%% 15. 比较纯基波与加入谐波后的波形

testCode = score(1);
testBeats = beats(1);

pureNote = makeNote( ...
    testCode, ...
    testBeats, ...
    oneBeatTime, ...
    fs, ...
    'exp', ...
    false);

harmonicNote = makeNote( ...
    testCode, ...
    testBeats, ...
    oneBeatTime, ...
    fs, ...
    'exp', ...
    true);

testTime = (0:length(pureNote)-1) / fs;

figure;

subplot(2,1,1);

plot(testTime, pureNote);

xlabel('时间 / s');
ylabel('幅度');
title('只有基波的音符');
grid on;

subplot(2,1,2);

plot(testTime, harmonicNote);

xlabel('时间 / s');
ylabel('幅度');
title('加入二次、三次谐波后的音符');
grid on;

%% 16. 绘制频谱
%
% 第一个音是6，D大调中的B4，约493.88 Hz。
% 二次谐波约987.76 Hz。
% 三次谐波约1481.64 Hz。

N = length(harmonicNote);

Y = fft(harmonicNote);

P2 = abs(Y / N);
P1 = P2(1:floor(N/2)+1);

if length(P1) > 2
    P1(2:end-1) = 2 * P1(2:end-1);
end

frequencyAxis = fs * (0:floor(N/2)) / N;

figure;

plot(frequencyAxis, P1);

xlim([0 2000]);

xlabel('频率 / Hz');
ylabel('幅度');
title('加入二次、三次谐波后的单边频谱');
grid on;

%% 17. 分别保存折线包络和指数包络版本
%
% 用于实验听感对比。

musicLine = [];
musicExp = [];

for k = 1:length(score)

    noteLine = makeNote( ...
        score(k), ...
        beats(k), ...
        oneBeatTime, ...
        fs, ...
        'line', ...
        true);

    noteExp = makeNote( ...
        score(k), ...
        beats(k), ...
        oneBeatTime, ...
        fs, ...
        'exp', ...
        true);

    musicLine = [musicLine noteLine];
    musicExp = [musicExp noteExp];

    if pauseAfter(k) > 0

        pauseDuration = pauseAfter(k) * oneBeatTime;
        pauseSamples = round(pauseDuration * fs);
        silence = zeros(1, pauseSamples);

        musicLine = [musicLine silence];
        musicExp = [musicExp silence];

    end

end

if max(abs(musicLine)) > 0
    musicLine = masterVolume * musicLine / max(abs(musicLine));
end

if max(abs(musicExp)) > 0
    musicExp = masterVolume * musicExp / max(abs(musicExp));
end

audiowrite('bird_song_line_envelope.wav', musicLine, fs);
audiowrite('bird_song_exp_envelope.wav', musicExp, fs);

disp('已保存：bird_song_line_envelope.wav');
disp('已保存：bird_song_exp_envelope.wav');

%% 18. 显示总时长

totalDuration = length(music) / fs;

fprintf('\n合成音乐总时长：%.2f 秒\n', totalDuration);

disp('全部运行完成。');