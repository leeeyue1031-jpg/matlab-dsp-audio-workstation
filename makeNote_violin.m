function y = makeNote_violin(noteInput, duration, Fs, velocity, articulation)
% makeNote_violin
% =========================================================
% 使用DSP数学模型生成小提琴单音
%
% 调用示例：
% y = makeNote_violin(440, 1.0, 44100, 0.8, 'normal');
% y = makeNote_violin('A4', 1.0, 44100, 0.8, 'normal');
%
% 输入：
% noteInput    音名或频率
% duration     音符时长，单位为秒
% Fs           采样率
% velocity     力度，范围0到1
% articulation 演奏法：
%              'normal'
%              'legato'
%              'soft'
%              'strong'
%              'open'
%
% 输出：
% y            小提琴单音，行向量
%
% 本函数不使用真实乐器采样。
% =========================================================

%% 1. 默认参数

if nargin < 3 || isempty(Fs)
    Fs = 44100;
end

if nargin < 4 || isempty(velocity)
    velocity = 0.80;
end

if nargin < 5 || isempty(articulation)
    articulation = 'normal';
end

velocity = max(0, min(1, velocity));
duration = max(duration, 0.03);

%% 2. 音名转换为频率

if isnumeric(noteInput)

    f0 = noteInput;

else

    f0 = noteNameToFrequency(noteInput);

end

if f0 <= 0

    y = zeros(1, round(duration*Fs));
    return;

end

%% 3. 时间轴

N = max(1, round(duration*Fs));

t = (0:N-1)/Fs;

%% 4. 不同演奏法参数

switch lower(articulation)

    case 'legato'

        attackTime = min(0.045, 0.10*duration);
        releaseTime = min(0.090, 0.16*duration);

        vibratoDepthCents = 8.0;
        vibratoDelay = 0.18;

        bowNoiseLevel = 0.0009;
        attackNoiseLevel = 0.0012;

        brightness = 0.92;

    case 'soft'

        attackTime = min(0.075, 0.15*duration);
        releaseTime = min(0.130, 0.22*duration);

        vibratoDepthCents = 7.0;
        vibratoDelay = 0.25;

        bowNoiseLevel = 0.0007;
        attackNoiseLevel = 0.0010;

        brightness = 0.78;

    case 'strong'

        attackTime = min(0.030, 0.07*duration);
        releaseTime = min(0.100, 0.18*duration);

        vibratoDepthCents = 9.5;
        vibratoDelay = 0.16;

        bowNoiseLevel = 0.0015;
        attackNoiseLevel = 0.0030;

        brightness = 1.08;

    case 'open'

        attackTime = min(0.025, 0.06*duration);
        releaseTime = min(0.110, 0.19*duration);

        vibratoDepthCents = 2.0;
        vibratoDelay = 0.35;

        bowNoiseLevel = 0.0012;
        attackNoiseLevel = 0.0022;

        brightness = 1.15;

    otherwise

        attackTime = min(0.050, 0.11*duration);
        releaseTime = min(0.110, 0.20*duration);

        vibratoDepthCents = 8.0;
        vibratoDelay = 0.22;

        bowNoiseLevel = 0.0010;
        attackNoiseLevel = 0.0018;

        brightness = 0.95;

end

%% 5. 短音关闭揉弦，长音才使用揉弦

if duration < 0.65

    vibratoDepthCents = 0;

elseif duration < 1.10

    vibratoDepthCents = ...
        min(vibratoDepthCents, 3.0);

else

    vibratoDepthCents = ...
        min(vibratoDepthCents, 6.0);

end

%% 6. 整体小提琴包络

globalEnvelope = makeViolinEnvelope( ...
    N, ...
    Fs, ...
    duration, ...
    attackTime, ...
    releaseTime);

%% 7. 揉弦

vibratoRate = 5.25;

vibratoRiseTime = 0.32;

vibratoRamp = zeros(1, N);

vibratoIndex = t >= vibratoDelay;

vibratoRamp(vibratoIndex) = ...
    1 - exp( ...
    -(t(vibratoIndex)-vibratoDelay) ...
    / vibratoRiseTime);

vibratoPhase = ...
    2*pi*vibratoRate*t ...
    + 0.06*sin(2*pi*0.45*t);

vibratoCents = ...
    vibratoDepthCents ...
    .* vibratoRamp ...
    .* sin(vibratoPhase);

%% 8. 关闭随机音高抖动

pitchJitterCents = zeros(1, N);

instantaneousFrequency = ...
    f0 .* ...
    2.^((vibratoCents + pitchJitterCents)/1200);

fundamentalPhase = ...
    2*pi*cumsum(instantaneousFrequency)/Fs;

%% 9. 自动确定谐波数量

maximumHarmonicFrequency = ...
    min(9000, 0.46*Fs);

harmonicCount = ...
    floor(maximumHarmonicFrequency/f0);

harmonicCount = max(1, harmonicCount);
harmonicCount = min(20, harmonicCount);

%% 10. 小提琴谐波幅值模型

harmonicNumber = (1:harmonicCount)';

harmonicAmplitude = ...
    1 ./ harmonicNumber.^1.12;

spectralShape = ...
    1 ...
    + 0.18*exp( ...
    -0.5*((harmonicNumber-2.2)/0.8).^2) ...
    + 0.24*exp( ...
    -0.5*((harmonicNumber-4.7)/1.2).^2) ...
    + 0.12*exp( ...
    -0.5*((harmonicNumber-8.0)/2.2).^2);

harmonicAmplitude = ...
    harmonicAmplitude .* spectralShape;

highFrequencyRollOff = ...
    exp(-0.034*(harmonicNumber-1).^1.20);

harmonicAmplitude = ...
    harmonicAmplitude .* highFrequencyRollOff;

pitchBrightness = ...
    min(1.08, max(0.74, 480/f0));

brightnessExponent = ...
    0.14*(harmonicNumber-1);

harmonicAmplitude = ...
    harmonicAmplitude ...
    .* (brightness*pitchBrightness) ...
    .^ brightnessExponent;

%% 11. 空弦模式增强二、三次谐波

if strcmpi(articulation, 'open')

    if harmonicCount >= 2

        harmonicAmplitude(2) = ...
            1.18*harmonicAmplitude(2);

    end

    if harmonicCount >= 3

        harmonicAmplitude(3) = ...
            1.14*harmonicAmplitude(3);

    end

end

harmonicAmplitude = ...
    harmonicAmplitude ...
    / (sqrt(sum(harmonicAmplitude.^2)) + eps);

%% 12. 合成所有谐波

stringSignal = zeros(1, N);

for h = 1:harmonicCount

    harmonicAttackTime = ...
        max( ...
        0.008, ...
        attackTime*(1 - 0.012*(h-1)));

    harmonicAttack = ...
        1 - exp( ...
        -t/max(harmonicAttackTime, 1/Fs));

    transientBrightness = ...
        1 ...
        + (0.010 + 0.0035*h) ...
        .* exp( ...
        -t/(0.11 + 0.008*h));

    transientBrightness = ...
        min(transientBrightness, 1.18);

    amplitudeVariation = ...
        makeSmoothRandom( ...
        N, ...
        Fs, ...
        5.5 + 0.25*h);

    amplitudeVariation = ...
        amplitudeVariation ...
        / (max(abs(amplitudeVariation)) + eps);

    variationDepth = ...
        0.0015 + 0.00018*h;

    harmonicEnvelope = ...
        globalEnvelope ...
        .* harmonicAttack ...
        .* transientBrightness ...
        .* (1 + variationDepth*amplitudeVariation);

    initialPhase = ...
        mod(0.73*h^2 + 0.41*h, 2*pi);

    currentHarmonic = ...
        harmonicAmplitude(h) ...
        .* harmonicEnvelope ...
        .* sin( ...
        h*fundamentalPhase ...
        + initialPhase);

    stringSignal = ...
        stringSignal + currentHarmonic;

end

%% 13. 轻微弓压变化

bowPressureRandom = ...
    makeSmoothRandom(N, Fs, 2.6);

bowPressureRandom = ...
    bowPressureRandom ...
    / (max(abs(bowPressureRandom)) + eps);

bowPressure = ...
    1 ...
    + 0.004*sin(2*pi*2.05*t + 0.4) ...
    + 0.004*bowPressureRandom;

stringSignal = ...
    stringSignal .* bowPressure;

%% 14. 人工弓毛摩擦噪声

whiteNoise = randn(1, N);

smoothSamples = ...
    max(2, round(0.0015*Fs));

smoothKernel = ...
    ones(1, smoothSamples)/smoothSamples;

lowNoise = ...
    conv(whiteNoise, smoothKernel, 'same');

bowNoise = ...
    whiteNoise - lowNoise;

softSamples = ...
    max(2, round(0.00018*Fs));

softKernel = ...
    ones(1, softSamples)/softSamples;

bowNoise = ...
    conv(bowNoise, softKernel, 'same');

bowNoise = ...
    bowNoise/(std(bowNoise) + eps);

noiseEvolution = ...
    0.22 ...
    + 0.78*exp(-t/0.070);

frequencyNoiseScale = ...
    min(1.05, max(0.58, 450/f0));

bowNoiseComponent = ...
    bowNoiseLevel ...
    * frequencyNoiseScale ...
    .* bowNoise ...
    .* globalEnvelope ...
    .* noiseEvolution;

%% 15. 起音擦弦瞬态

attackNoise = randn(1, N);

attackNoise = ...
    attackNoise ...
    - conv(attackNoise, smoothKernel, 'same');

attackNoise = ...
    attackNoise/(std(attackNoise) + eps);

attackTransientEnvelope = ...
    (1-exp(-t/0.003)) ...
    .* exp(-t/0.022);

attackTransientEnvelope( ...
    t > min(0.080, 0.18*duration)) = 0;

attackTransient = ...
    attackNoiseLevel ...
    .* attackNoise ...
    .* attackTransientEnvelope;

%% 16. 合并琴弦声和弓噪声

excitation = ...
    stringSignal ...
    + bowNoiseComponent ...
    + attackTransient;

%% 17. 简化琴体共振

bodyFrequency = [ ...
    280, ...
    470, ...
    820, ...
    1180, ...
    1680, ...
    2450, ...
    3350 ...
];

bodyQ = [ ...
    4.0, ...
    5.5, ...
    6.5, ...
    7.0, ...
    7.5, ...
    8.5, ...
    9.5 ...
];

bodyGain = [ ...
    0.24, ...
    0.31, ...
    0.25, ...
    0.19, ...
    0.14, ...
    0.10, ...
    0.06 ...
];

bodySignal = zeros(1, N);

inputRms = ...
    sqrt(mean(excitation.^2)) + eps;

for resonanceIndex = 1:length(bodyFrequency)

    fc = bodyFrequency(resonanceIndex);

    if fc >= 0.45*Fs
        continue;
    end

    bandwidth = ...
        fc/bodyQ(resonanceIndex);

    radius = ...
        exp(-pi*bandwidth/Fs);

    angleValue = ...
        2*pi*fc/Fs;

    b = ...
        (1-radius)*[1, 0, -1];

    a = [ ...
        1, ...
        -2*radius*cos(angleValue), ...
        radius^2 ...
    ];

    resonated = ...
        filter(b, a, excitation);

    resonatedRms = ...
        sqrt(mean(resonated.^2)) + eps;

    resonated = ...
        resonated ...
        * inputRms/resonatedRms;

    bodySignal = ...
        bodySignal ...
        + bodyGain(resonanceIndex)*resonated;

end

bodySignal = ...
    bodySignal ...
    / (sum(abs(bodyGain)) + eps);

%% 18. 仅保留少量琴体共振

y = ...
    0.96*excitation ...
    + 0.04*bodySignal;

%% 19. 高频柔化

cutoffFrequency = ...
    min(9000, max(4800, 13*f0));

alpha = ...
    exp(-2*pi*cutoffFrequency/Fs);

filteredSignal = ...
    onePoleLowPass(y, alpha);

y = ...
    0.76*y ...
    + 0.24*filteredSignal;

%% 20. 力度控制

gain = ...
    0.30 + 0.70*velocity;

y = gain*y;

%% 21. 轻微软限幅

drive = 1.06;

y = ...
    tanh(drive*y)/tanh(drive);

%% 22. 防止峰值过大

peakValue = max(abs(y));

if peakValue > 0

    y = ...
        0.90*y/peakValue;

end

%% 23. 最终力度控制

y = ...
    y*(0.35 + 0.65*velocity);

end


%% =========================================================
% 局部函数：小提琴整体包络
%% =========================================================

function envelope = makeViolinEnvelope( ...
    N, Fs, duration, attackTime, releaseTime)

t = (0:N-1)/Fs;

attackTime = ...
    max(attackTime, 1/Fs);

releaseTime = ...
    max(releaseTime, 1/Fs);

attackEnvelope = ...
    1 - exp(-t/attackTime);

sustainVariation = ...
    0.985 ...
    + 0.015*exp(-t/0.30);

releaseStart = ...
    max(0, duration-releaseTime);

releaseEnvelope = ...
    ones(1, N);

releaseIndex = ...
    t >= releaseStart;

releaseEnvelope(releaseIndex) = ...
    0.5 ...
    + 0.5*cos( ...
    pi*(t(releaseIndex)-releaseStart) ...
    / max(releaseTime, 1/Fs));

releaseEnvelope(t >= duration) = 0;

envelope = ...
    attackEnvelope ...
    .* sustainVariation ...
    .* releaseEnvelope;

end


%% =========================================================
% 局部函数：音名转频率
%% =========================================================

function frequency = noteNameToFrequency(noteName)

noteName = strtrim(noteName);

if strcmpi(noteName, 'R') || ...
        strcmpi(noteName, 'REST') || ...
        strcmp(noteName, '0')

    frequency = 0;
    return;

end

expression = ...
    '^([A-Ga-g])([#b]?)(-?\d+)$';

tokens = ...
    regexp(noteName, expression, 'tokens', 'once');

if isempty(tokens)

    error( ...
        '无法识别音名"%s"。正确示例：A4、C#5、Bb3。', ...
        noteName);

end

letter = upper(tokens{1});
accidental = tokens{2};
octave = str2double(tokens{3});

switch letter

    case 'C'
        semitone = 0;

    case 'D'
        semitone = 2;

    case 'E'
        semitone = 4;

    case 'F'
        semitone = 5;

    case 'G'
        semitone = 7;

    case 'A'
        semitone = 9;

    case 'B'
        semitone = 11;

end

if strcmp(accidental, '#')

    semitone = semitone + 1;

elseif strcmp(accidental, 'b')

    semitone = semitone - 1;

end

midiNumber = ...
    12*(octave+1) + semitone;

frequency = ...
    440 * 2^((midiNumber-69)/12);

end


%% =========================================================
% 局部函数：平滑随机信号
%% =========================================================

function x = makeSmoothRandom(N, Fs, bandwidth)

whiteNoise = randn(1, N);

smoothingLength = ...
    max(3, round(Fs/max(bandwidth, 0.1)));

smoothingLength = ...
    min(smoothingLength, N);

kernel = ...
    ones(1, smoothingLength)/smoothingLength;

x = ...
    conv(whiteNoise, kernel, 'same');

x = x - mean(x);

x = ...
    x/(std(x) + eps);

end


%% =========================================================
% 局部函数：一阶低通滤波器
%% =========================================================

function y = onePoleLowPass(x, alpha)

y = zeros(size(x));

if isempty(x)
    return;
end

y(1) = ...
    (1-alpha)*x(1);

for sampleIndex = 2:length(x)

    y(sampleIndex) = ...
        (1-alpha)*x(sampleIndex) ...
        + alpha*y(sampleIndex-1);

end

end