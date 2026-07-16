clear;
clc;
close all;

%% =========================================================
% 《鸟之诗》小提琴电子合成
%
% 本程序需要与makeNote_violin.m放在同一个文件夹。
%
% 最终声音使用：
% 多谐波加法合成
% 独立谐波包络
% 长音揉弦
% 轻微弓压变化
% 人工弓毛噪声
% 简化琴体共振
%
% 不使用真实乐器采样。
%% =========================================================

rng(2026);

%% 1. 基本参数

fs = 44100;

bpm = 72;

oneBeatTime = 60/bpm;

masterVolume = 0.90;

% 稳定版只使用8毫秒交叉淡化
crossFadeTime = 0.008;

fprintf('当前速度：%d BPM\n', bpm);
fprintf('每拍持续时间：%.3f 秒\n', oneBeatTime);
fprintf('采样频率：%d Hz\n\n', fs);

%% 2. D大调频率表

fprintf('D大调中音区频率表：\n');
fprintf('1(do)  = D4  = 293.66 Hz\n');
fprintf('2(re)  = E4  = 329.63 Hz\n');
fprintf('3(mi)  = F#4 = 369.99 Hz\n');
fprintf('4(fa)  = G4  = 392.00 Hz\n');
fprintf('5(sol) = A4  = 440.00 Hz\n');
fprintf('6(la)  = B4  = 493.88 Hz\n');
fprintf('7(si)  = C#5 = 554.37 Hz\n\n');

%% 3. 《鸟之诗》数字简谱

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

%% 4. 每个音符拍数

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

%% 5. 主体和再现段

mainScore = [ ...
    score1 ...
    score2 ...
    score3 ...
    score4 ...
    score5 ...
    score6 ...
];

mainBeats = [ ...
    beats1 ...
    beats2 ...
    beats3 ...
    beats4 ...
    beats5 ...
    beats6 ...
];

% 再现前两句，使总时长超过60秒
repriseScore = [ ...
    score1 ...
    score2 ...
];

repriseBeats = [ ...
    beats1 ...
    beats2 ...
];

score = [ ...
    mainScore ...
    repriseScore ...
];

beats = [ ...
    mainBeats ...
    repriseBeats ...
];

%% 6. 检查乐谱

fprintf('乐谱音符数量：%d\n', length(score));
fprintf('时值数量：%d\n\n', length(beats));

if length(score) ~= length(beats)

    error('score和beats的元素数量不一致。');

end

%% 7. 设置句间休止

length1 = length(score1);
length2 = length(score2);
length3 = length(score3);
length4 = length(score4);
length5 = length(score5);
length6 = length(score6);

lineEnd1 = length1;
lineEnd2 = lineEnd1 + length2;
lineEnd3 = lineEnd2 + length3;
lineEnd4 = lineEnd3 + length4;
lineEnd5 = lineEnd4 + length5;
lineEnd6 = lineEnd5 + length6;

lineEnd7 = lineEnd6 + length1;
lineEnd8 = lineEnd7 + length2;

pauseAfter = zeros(size(score));

pauseAfter(lineEnd1) = 0.35;
pauseAfter(lineEnd2) = 0.45;
pauseAfter(lineEnd3) = 0.55;
pauseAfter(lineEnd4) = 0.55;
pauseAfter(lineEnd5) = 0.75;
pauseAfter(lineEnd6) = 1.20;
pauseAfter(lineEnd7) = 0.45;
pauseAfter(lineEnd8) = 1.80;

%% 8. 自动力度曲线

noteCount = length(score);

velocity = zeros(1, noteCount);

for k = 1:noteCount

    phraseDynamic = ...
        0.67 ...
        + 0.10*sin( ...
        2*pi*(k-1)/26 - pi/2);

    if abs(score(k)) >= 20

        pitchCorrection = -0.06;

    elseif abs(score(k)) >= 10

        pitchCorrection = -0.02;

    else

        pitchCorrection = 0;

    end

    velocity(k) = ...
        phraseDynamic + pitchCorrection;

end

velocity = ...
    min(0.84, max(0.48, velocity));

%% 9. 生成小提琴主旋律

music = [];

fprintf('开始生成小提琴主旋律……\n');

for k = 1:noteCount

    currentCode = score(k);
    currentBeats = beats(k);

    noteDuration = ...
        currentBeats*oneBeatTime;

    if currentCode == 0

        oneNote = ...
            zeros(1, round(noteDuration*fs));

    else

        currentFrequency = ...
            codeToFrequency(currentCode);

        if currentBeats >= 1.0

            articulation = 'legato';

        elseif velocity(k) <= 0.55

            articulation = 'soft';

        elseif velocity(k) >= 0.78

            articulation = 'strong';

        else

            articulation = 'normal';

        end

        synthesisDuration = ...
            noteDuration + crossFadeTime;

        oneNote = ...
            makeNote_violin( ...
            currentFrequency, ...
            synthesisDuration, ...
            fs, ...
            velocity(k), ...
            articulation);

    end

    %% 相邻音符交叉淡化

    if isempty(music)

        music = oneNote;

    else

        overlapSamples = ...
            min( ...
            round(crossFadeTime*fs), ...
            min(length(music), length(oneNote)));

        if overlapSamples > 1 && currentCode ~= 0

            fadeOut = ...
                0.5 ...
                + 0.5*cos( ...
                linspace(0, pi, overlapSamples));

            fadeIn = ...
                0.5 ...
                - 0.5*cos( ...
                linspace(0, pi, overlapSamples));

            overlapPart = ...
                music(end-overlapSamples+1:end) ...
                .* fadeOut ...
                + oneNote(1:overlapSamples) ...
                .* fadeIn;

            music = [ ...
                music(1:end-overlapSamples) ...
                overlapPart ...
                oneNote(overlapSamples+1:end) ...
            ];

        else

            music = [ ...
                music ...
                oneNote ...
            ];

        end

    end

    %% 添加句尾休止

    if pauseAfter(k) > 0

        pauseDuration = ...
            pauseAfter(k)*oneBeatTime;

        pauseSamples = ...
            round(pauseDuration*fs);

        music = [ ...
            music ...
            zeros(1, pauseSamples) ...
        ];

    end

    if mod(k, 10) == 0 || k == noteCount

        fprintf( ...
            '已生成：%d / %d 个音符\n', ...
            k, ...
            noteCount);

    end

end

%% 10. 保存干声

musicDry = music;

%% 11. 加入极轻混响

music = ...
    addSimpleReverb( ...
    music, ...
    fs, ...
    0.025);

%% 12. 生成低音铺底

bass = zeros(size(music));

bassCodes = [ ...
    -1 ...
    -4 ...
    -5 ...
    -1 ...
];

bassChordBeats = 4;

bassStartTime = 0;

bassIndex = 1;

totalMusicDuration = ...
    length(music)/fs;

while bassStartTime < totalMusicDuration

    bassFrequency = ...
        codeToFrequency(bassCodes(bassIndex));

    bassDuration = ...
        bassChordBeats*oneBeatTime;

    bassNote = ...
        makeNote_violin( ...
        bassFrequency, ...
        bassDuration + 0.10, ...
        fs, ...
        0.28, ...
        'soft');

    startSample = ...
        round(bassStartTime*fs) + 1;

    endSample = ...
        min( ...
        length(bass), ...
        startSample + length(bassNote) - 1);

    validLength = ...
        endSample-startSample+1;

    if validLength > 0

        bass(startSample:endSample) = ...
            bass(startSample:endSample) ...
            + bassNote(1:validLength);

    end

    bassStartTime = ...
        bassStartTime + bassDuration;

    bassIndex = bassIndex + 1;

    if bassIndex > length(bassCodes)

        bassIndex = 1;

    end

end

%% 13. 低音使用较轻混响

bass = ...
    addSimpleReverb( ...
    bass, ...
    fs, ...
    0.06);

%% 14. 混合主旋律和低音

music = ...
    0.97*music ...
    + 0.035*bass;

%% 15. 整体动态变化

musicLength = length(music);

musicTime = ...
    (0:musicLength-1)/fs;

wholeDynamic = ...
    0.92 ...
    + 0.06*sin( ...
    2*pi*musicTime/18 - pi/2);

music = ...
    music .* wholeDynamic;

%% 16. 整体淡入淡出

fadeInTime = 0.80;
fadeOutTime = 2.00;

fadeInSamples = ...
    min( ...
    round(fadeInTime*fs), ...
    musicLength);

fadeOutSamples = ...
    min( ...
    round(fadeOutTime*fs), ...
    musicLength);

music(1:fadeInSamples) = ...
    music(1:fadeInSamples) ...
    .* ( ...
    0.5 ...
    - 0.5*cos( ...
    linspace(0, pi, fadeInSamples)));

music(end-fadeOutSamples+1:end) = ...
    music(end-fadeOutSamples+1:end) ...
    .* ( ...
    0.5 ...
    + 0.5*cos( ...
    linspace(0, pi, fadeOutSamples)));

%% 17. 去直流

music = ...
    music - mean(music);

%% 18. 轻微软限幅

drive = 1.06;

music = ...
    tanh(drive*music)/tanh(drive);

%% 19. 最终归一化

if max(abs(music)) > 0

    music = ...
        masterVolume ...
        * music ...
        / max(abs(music));

end

%% 20. 保存最终音乐

outputFile = ...
    'bird_song_violin_stable.wav';

dryOutputFile = ...
    'bird_song_violin_dry.wav';

audiowrite( ...
    outputFile, ...
    music(:), ...
    fs);

if max(abs(musicDry)) > 0

    musicDry = ...
        0.90*musicDry ...
        / max(abs(musicDry));

end

audiowrite( ...
    dryOutputFile, ...
    musicDry(:), ...
    fs);

%% 21. 播放

disp('开始播放《鸟之诗》小提琴电子合成稳定版……');

sound(music, fs);

%% 22. 显示结果

totalDuration = ...
    length(music)/fs;

fprintf('\n合成音乐总时长：%.2f 秒\n', ...
    totalDuration);

fprintf('已保存：%s\n', ...
    outputFile);

fprintf('已保存干声：%s\n', ...
    dryOutputFile);

if totalDuration < 60

    warning('当前总时长不足60秒。');

else

    fprintf('时长已达到60秒以上要求。\n');

end

%% 23. 绘制完整音乐波形

figure('Color', 'w');

plot(musicTime, music);

xlabel('时间 / s');
ylabel('幅度');

title('《鸟之诗》小提琴电子合成时域波形');

grid on;

xlim([0 musicTime(end)]);

%% 24. 绘制完整音乐频谱

NFFT = ...
    2^nextpow2(length(music));

Y = ...
    fft(music, NFFT);

magnitudeSpectrum = ...
    abs(Y(1:NFFT/2+1));

magnitudeSpectrum = ...
    magnitudeSpectrum ...
    / (max(magnitudeSpectrum) + eps);

frequencyAxis = ...
    fs*(0:NFFT/2)/NFFT;

figure('Color', 'w');

plot( ...
    frequencyAxis, ...
    20*log10(magnitudeSpectrum + 1e-8));

xlim([0 10000]);
ylim([-90 5]);

xlabel('频率 / Hz');
ylabel('归一化幅度 / dB');

title('《鸟之诗》小提琴电子合成频谱');

grid on;

%% 25. 绘制第一个单音的波形和频谱

testFrequency = ...
    codeToFrequency(score(1));

testNote = ...
    makeNote_violin( ...
    testFrequency, ...
    beats(1)*oneBeatTime, ...
    fs, ...
    velocity(1), ...
    'normal');

testTime = ...
    (0:length(testNote)-1)/fs;

figure('Color', 'w');

subplot(2,1,1);

plot(testTime, testNote);

xlabel('时间 / s');
ylabel('幅度');

title('第一个小提琴音符时域波形');

grid on;

testNFFT = ...
    2^nextpow2(length(testNote));

testFFT = ...
    fft(testNote, testNFFT);

testSpectrum = ...
    abs(testFFT(1:testNFFT/2+1));

testSpectrum = ...
    testSpectrum ...
    / (max(testSpectrum) + eps);

testFrequencyAxis = ...
    fs*(0:testNFFT/2)/testNFFT;

subplot(2,1,2);

plot( ...
    testFrequencyAxis, ...
    20*log10(testSpectrum + 1e-8));

xlim([0 8000]);
ylim([-90 5]);

xlabel('频率 / Hz');
ylabel('归一化幅度 / dB');

title('第一个小提琴音符频谱');

grid on;

disp('全部运行完成。');


%% =========================================================
% 局部函数：数字简谱编码转频率
%% =========================================================

function frequency = codeToFrequency(code)

if code == 0

    frequency = 0;
    return;

end

middleFrequency = [ ...
    293.66 ...
    329.63 ...
    369.99 ...
    392.00 ...
    440.00 ...
    493.88 ...
    554.37 ...
];

absoluteCode = abs(code);

if absoluteCode >= 21 && absoluteCode <= 27

    degree = ...
        absoluteCode - 20;

    octaveFactor = 4;

elseif absoluteCode >= 11 && absoluteCode <= 17

    degree = ...
        absoluteCode - 10;

    octaveFactor = 2;

elseif absoluteCode >= 1 && absoluteCode <= 7

    degree = absoluteCode;

    octaveFactor = 1;

else

    error( ...
        '无法识别数字简谱编码：%d', ...
        code);

end

frequency = ...
    middleFrequency(degree) ...
    * octaveFactor;

if code < 0

    frequency = ...
        middleFrequency(degree)/2;

end

end


%% =========================================================
% 局部函数：简化混响
%% =========================================================

function y = addSimpleReverb(x, fs, wetLevel)

delayTimes = [ ...
    0.029 ...
    0.043 ...
    0.067 ...
    0.097 ...
];

delayGains = [ ...
    0.36 ...
    0.25 ...
    0.17 ...
    0.10 ...
];

reverbSignal = ...
    zeros(size(x));

for delayIndex = 1:length(delayTimes)

    delaySamples = ...
        round(delayTimes(delayIndex)*fs);

    if delaySamples < length(x)

        delayedSignal = [ ...
            zeros(1, delaySamples) ...
            x(1:end-delaySamples) ...
        ];

        reverbSignal = ...
            reverbSignal ...
            + delayGains(delayIndex)*delayedSignal;

    end

end

y = ...
    (1-wetLevel)*x ...
    + wetLevel*reverbSignal;

end