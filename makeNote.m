function note = makeNote( ...
    code, ...
    beats, ...
    oneBeatTime, ...
    fs, ...
    envelopeType, ...
    useHarmonics)


%% 1. D大调中音区频率表

freqTable = [ ...
    293.66 ... % 1，D4
    329.63 ... % 2，E4
    369.99 ... % 3，F#4
    392.00 ... % 4，G4
    440.00 ... % 5，A4
    493.88 ... % 6，B4
    554.37 ... % 7，C#5
];

%% 2. 计算持续时间和采样点数

duration = beats * oneBeatTime;

sampleCount = max(1, round(duration * fs));

t = (0:sampleCount-1) / fs;

%% 3. 休止符

if code == 0

    note = zeros(1, sampleCount);

    return;

end

%% 4. 判断音区

if code >= 21 && code <= 27

    degree = code - 20;
    octave = 2;

elseif code >= 11 && code <= 17

    degree = code - 10;
    octave = 1;

elseif code >= 1 && code <= 7

    degree = code;
    octave = 0;

elseif code <= -1 && code >= -7

    degree = abs(code);
    octave = -1;

else

    error('简谱编码错误：%g', code);

end

%% 5. 计算当前音符频率
%
% 高一个八度，频率乘2。
% 低一个八度，频率除2。

frequency = freqTable(degree) * 2^octave;

%% 6. 生成基波

fundamental = sin(2*pi*frequency*t);

%% 7. 加入谐波
%
% PDF建议：
% 基波幅度为1
% 二次谐波幅度为0.2
% 三次谐波幅度为0.3

if useHarmonics

    secondHarmonic = ...
        0.2 * sin(2*pi*2*frequency*t);

    thirdHarmonic = ...
        0.3 * sin(2*pi*3*frequency*t);

    wave = ...
        fundamental + ...
        secondHarmonic + ...
        thirdHarmonic;

    % 防止叠加后幅度过大
    wave = wave / 1.5;

else

    wave = fundamental;

end

%% 8. 生成包络

normalizedTime = linspace(0, 1, sampleCount);

switch lower(envelopeType)

    case 'none'

        % 不进行包络修正
        envelope = ones(1, sampleCount);

    case 'line'

        % 折线包络
        %
        % 起点音量为0
        % 1/5处快速上升到最大值
        % 1/3处衰减到0.7
        % 2/3处保持0.7
        % 结束时回到0

        pointX = [ ...
            0 ...
            1/5 ...
            1/3 ...
            2/3 ...
            1 ...
        ];

        pointY = [ ...
            0 ...
            1 ...
            0.7 ...
            0.7 ...
            0 ...
        ];

        envelope = interp1( ...
            pointX, ...
            pointY, ...
            normalizedTime, ...
            'linear');

    case 'exp'

        % 指数衰减包络
        %
        % normalizedTime.^4控制起音过程。
        % exp部分控制衰减。
        % 乘(1-normalizedTime)确保末尾回到0。

        envelope = ...
            (normalizedTime.^4) .* ...
            exp(-8 * sqrt(normalizedTime));

        if max(envelope) > 0
            envelope = envelope / max(envelope);
        end

        envelope = envelope .* (1 - normalizedTime);

    otherwise

        error('envelopeType只能写none、line或exp。');

end

%% 9. 包络修正

note = wave .* envelope;

%% 10. 单音归一化

if max(abs(note)) > 0

    note = 0.90 * note / max(abs(note));

end

end