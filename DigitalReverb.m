classdef DigitalReverb < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        GridLayout            matlab.ui.container.GridLayout
        LeftPanel             matlab.ui.container.Panel
        GridLayout2           matlab.ui.container.GridLayout
        Button_7              matlab.ui.control.Button
        Label_4               matlab.ui.control.Label
        GridLayout5           matlab.ui.container.GridLayout
        Label8                matlab.ui.control.Label
        Label7                matlab.ui.control.Label
        Label6                matlab.ui.control.Label
        Label5                matlab.ui.control.Label
        Label_8               matlab.ui.control.Label
        Label_7               matlab.ui.control.Label
        Label_6               matlab.ui.control.Label
        Label_3               matlab.ui.control.Label
        Button_5              matlab.ui.control.Button
        Button_3              matlab.ui.control.Button
        Button_2              matlab.ui.control.Button
        Button                matlab.ui.control.Button
        RightPanel            matlab.ui.container.Panel
        GridLayout3           matlab.ui.container.GridLayout
        GridLayout6_6         matlab.ui.container.GridLayout
        FeedbackValueLabel    matlab.ui.control.Label
        Label_12              matlab.ui.control.Label
        GridLayout6_5         matlab.ui.container.GridLayout
        OutputGainValueLabel  matlab.ui.control.Label
        Label_14              matlab.ui.control.Label
        GridLayout6_4         matlab.ui.container.GridLayout
        HFDampingValueLabel   matlab.ui.control.Label
        Label_13              matlab.ui.control.Label
        GridLayout6_3         matlab.ui.container.GridLayout
        PreDelayValueLabel    matlab.ui.control.Label
        Label_11              matlab.ui.control.Label
        GridLayout6_2         matlab.ui.container.GridLayout
        WetDryValueLabel      matlab.ui.control.Label
        Label_10              matlab.ui.control.Label
        GridLayout6           matlab.ui.container.GridLayout
        ReverbTimeValueLabel  matlab.ui.control.Label
        Label_9               matlab.ui.control.Label
        sKnob                 matlab.ui.control.Knob
        Label_5               matlab.ui.control.Label
        msKnob                matlab.ui.control.Knob
        Knob                  matlab.ui.control.Knob
        Knob3                 matlab.ui.control.Knob
        Knob_3                matlab.ui.control.Knob
        Knob_2                matlab.ui.control.Knob
        GridLayout4           matlab.ui.container.GridLayout
        Button_6              matlab.ui.control.Button
        TextArea              matlab.ui.control.TextArea
        DropDown              matlab.ui.control.DropDown
        Label_2               matlab.ui.control.Label
        UIAxes2               matlab.ui.control.UIAxes
        UIAxes                matlab.ui.control.UIAxes
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
    end

    properties (Access = private)
        MainApp = []
        OriginalAudio = []
        ReverbAudio = []
        SampleRate = []
        SongName = '未载入'

        OriginalPlayer = []
        ReverbPlayer = []
        ActivePlayer = []
        ActivePlaybackType = ''
        PlaybackTimer = []

        OriginalWaveLine = []
        ReverbWaveLine = []
        OriginalCursorLine = []
        ReverbCursorLine = []

        ReverbIsValid = false
        IsProcessing = false
        IsClosing = false
    end

    methods (Access = private)

        function audio = convertAudioToDouble(~, audio)
            if isinteger(audio)
                className = class(audio);
                if className(1) == 'u'
                    scale = double(intmax(className));
                    midpoint = scale / 2;
                    audio = (double(audio) - midpoint) / max(midpoint, 1);
                else
                    scale = max(abs(double(intmin(className))), double(intmax(className)));
                    audio = double(audio) / max(scale, 1);
                end
            else
                audio = double(audio);
            end
        end

        function updateAudioInfo(app)
            if isempty(app.OriginalAudio) || isempty(app.SampleRate)
                app.Label5.Text = '未载入';
                app.Label6.Text = '--';
                app.Label7.Text = '--';
                app.Label8.Text = '--';
                return;
            end

            displayName = app.SongName;
            if numel(displayName) > 24
                displayName = [displayName(1:21) '...'];
            end
            app.Label5.Text = displayName;
            app.Label6.Text = sprintf('%.0f Hz', app.SampleRate);
            app.Label7.Text = sprintf('%d', size(app.OriginalAudio, 2));
            app.Label8.Text = sprintf('%.2f s', ...
                size(app.OriginalAudio, 1) / app.SampleRate);
        end

        function updateParameterValueLabels(app)

            app.ReverbTimeValueLabel.Text = ...
                sprintf('%.1f s', app.sKnob.Value);

            app.WetDryValueLabel.Text = ...
                sprintf('%.0f %%', app.Knob.Value);

            app.PreDelayValueLabel.Text = ...
                sprintf('%.0f ms', app.msKnob.Value);

            app.FeedbackValueLabel.Text = ...
                sprintf('%.2f', app.Knob_2.Value);

            app.HFDampingValueLabel.Text = ...
                sprintf('%.2f', app.Knob_3.Value);

            app.OutputGainValueLabel.Text = ...
                sprintf('%.2f', app.Knob3.Value);

        end

        function setStatus(app, message)
            if app.IsClosing || isempty(app.Label_4) || ...
                    ~isvalid(app.Label_4)
                return;
            end
            app.Label_4.Text = ['状态：' message];
        end

        function updateModelDescription(app)

            switch app.DropDown.Value

                case 'Schroeder混响'
                    app.TextArea.Value = { ...
                        'Schroeder模型：'; ...
                        '由多个并联梳状滤波器和级联全通滤波器组成，'; ...
                        '结构简单，计算量较小，适合基本人工混响模拟。'};

                    app.Knob_3.Enable = 'off';

                case 'Moorer混响'
                    app.TextArea.Value = { ...
                        'Moorer模型：'; ...
                        '在Schroeder模型基础上加入早期反射，并在反馈梳状滤波器中加入低通衰减，能够模拟更加自然的房间混响效果。'; ...
                      };

                    app.Knob_3.Enable = 'on';

                case 'Gardner混响'
                    app.TextArea.Value = { ...
                        'Gardner模型：'; ...
                        '采用多级全通扩散器和长延迟反馈网络，通过不同长度的延迟线提高回声密度，适合模拟空间感较强、扩散较均匀的混响效果。'; ...
                        };

                    app.Knob_3.Enable = 'on';

                otherwise
                    app.TextArea.Value = {'未知混响模型。'};
                    app.Knob_3.Enable = 'off';
            end
        end

        function updateControlState(app)
            hasAudio = ~isempty(app.OriginalAudio) && ~isempty(app.SampleRate);
            if hasAudio
                app.Button.Enable = 'on';
            else
                app.Button.Enable = 'off';
            end

            if hasAudio && ~app.IsProcessing
                app.Button_6.Enable = 'on';
            else
                app.Button_6.Enable = 'off';
            end

            if app.ReverbIsValid && ~isempty(app.ReverbAudio)
                app.Button_2.Enable = 'on';
                app.Button_5.Enable = 'on';
            else
                app.Button_2.Enable = 'off';
                app.Button_5.Enable = 'off';
            end
        end

        function invalidateReverb(app, message)
            if nargin < 2
                message = '参数或模型已改变，请重新生成混响。';
            end
            app.ReverbIsValid = false;
            if ~isempty(app.ReverbPlayer) && isvalid(app.ReverbPlayer)
                try
                    stop(app.ReverbPlayer);
                catch
                end
            end
            if strcmp(app.ActivePlaybackType, 'reverb')
                stopPlaybackTimer(app, false);
                app.ActivePlayer = [];
                app.ActivePlaybackType = '';
            end
            updateControlState(app);
            setStatus(app, message);
        end

        function params = getParameters(app)
            params.rt60 = app.sKnob.Value;
            params.wetRatio = app.Knob.Value / 100;
            params.preDelaySeconds = app.msKnob.Value / 1000;
            params.feedback = app.Knob_2.Value;
            params.hfDamping = app.Knob_3.Value;
            params.outputGain = app.Knob3.Value;
            validateParameters(app, params);
        end

        function validateParameters(~, params)
            values = [params.rt60, params.wetRatio, params.preDelaySeconds, ...
                params.feedback, params.hfDamping, params.outputGain];
            if any(~isfinite(values)) || ...
                    params.rt60 < 0.3 || params.rt60 > 5 || ...
                    params.wetRatio < 0 || params.wetRatio > 1 || ...
                    params.preDelaySeconds < 0 || params.preDelaySeconds > 0.2 || ...
                    params.feedback < 0 || params.feedback > 0.95 || ...
                    params.hfDamping < 0 || params.hfDamping > 1 || ...
                    params.outputGain < 0 || params.outputGain > 1.5
                error('DigitalReverb:InvalidParameters', '混响参数超出允许范围。');
            end
        end

        function [networkInput, dryAudio] = prepareNetworkInput(~, audio, fs, params)
            preDelaySamples = max(0, round(params.preDelaySeconds * fs));
            tailSamples = max(round(0.25 * fs), round(params.rt60 * fs));
            networkInput = [zeros(preDelaySamples, size(audio, 2)); ...
                audio; zeros(tailSamples, size(audio, 2))];
            dryAudio = zeros(size(networkInput));
            dryAudio(1:size(audio, 1), :) = audio;
        end

        function feedback = calculateCombFeedback(~, delaySamples, fs, params)
            rt60Feedback = 10 ^ (-3 * (delaySamples / fs) / params.rt60);
            feedbackScale = params.feedback / 0.70;
            feedback = min(0.97, max(0, rt60Feedback * feedbackScale));
        end

        function output = applyAllpassCascade(~, input, fs, delaySeconds, gain)
            output = input;
            for channel = 1:size(input, 2)
                channelAudio = input(:, channel);
                for index = 1:numel(delaySeconds)
                    delaySamples = max(1, round(delaySeconds(index) * fs) + channel - 1);
                    numerator = [-gain zeros(1, delaySamples - 1) 1];
                    denominator = [1 zeros(1, delaySamples - 1) -gain];
                    channelAudio = filter(numerator, denominator, channelAudio);
                end
                output(:, channel) = channelAudio;
            end
        end

        function wetAudio = applySchroederNetwork(app, input, fs, params)
            combDelaySeconds = [0.0297 0.0371 0.0411 0.0437];
            wetAudio = zeros(size(input));
            for channel = 1:size(input, 2)
                channelWet = zeros(size(input, 1), 1);
                for index = 1:numel(combDelaySeconds)
                    delaySamples = max(1, round(combDelaySeconds(index) * fs) + channel - 1);
                    feedback = calculateCombFeedback(app, delaySamples, fs, params);
                    denominator = [1 zeros(1, delaySamples - 1) -feedback];
                    channelWet = channelWet + filter(1, denominator, input(:, channel));
                end
                wetAudio(:, channel) = channelWet / numel(combDelaySeconds);
            end
            wetAudio = applyAllpassCascade(app, wetAudio, fs, [0.0050 0.0017], 0.70);
        end

        function earlyAudio = createEarlyReflections(~, input, fs)
            delaySeconds = [0.0043 0.0215 0.0225 0.0268 0.0270 0.0298];
            gains = [0.84 0.31 0.43 0.38 0.30 0.22];
            earlyAudio = zeros(size(input));
            for index = 1:numel(delaySeconds)
                delaySamples = max(1, round(delaySeconds(index) * fs));
                if delaySamples < size(input, 1)
                    earlyAudio(delaySamples + 1:end, :) = ...
                        earlyAudio(delaySamples + 1:end, :) + ...
                        gains(index) * input(1:end - delaySamples, :);
                end
            end
            earlyAudio = earlyAudio / max(1, sum(abs(gains)));
        end

        function wetAudio = applyMoorerNetwork(app, input, fs, params)
            earlyAudio = createEarlyReflections(app, input, fs);
            combDelaySeconds = [0.0500 0.0560 0.0610 0.0680 0.0720 0.0780];
            lateAudio = zeros(size(input));
            lowpassPole = min(0.95, max(0, 0.92 * params.hfDamping));

            for channel = 1:size(input, 2)
                channelWet = zeros(size(input, 1), 1);
                for index = 1:numel(combDelaySeconds)
                    delaySamples = max(2, round(combDelaySeconds(index) * fs) + channel - 1);
                    feedback = calculateCombFeedback(app, delaySamples, fs, params);
                    numerator = [1 -lowpassPole];
                    denominator = zeros(1, delaySamples + 1);
                    denominator(1) = 1;
                    denominator(2) = denominator(2) - lowpassPole;
                    denominator(delaySamples + 1) = ...
                        denominator(delaySamples + 1) - feedback * (1 - lowpassPole);
                    channelWet = channelWet + ...
                        filter(numerator, denominator, input(:, channel));
                end
                lateAudio(:, channel) = channelWet / numel(combDelaySeconds);
            end

            lateAudio = applyAllpassCascade(app, lateAudio, fs, [0.0060 0.0018], 0.68);
            wetAudio = 0.28 * earlyAudio + 0.72 * lateAudio;
        end

        function wetAudio = applyGardnerNetwork(app, input, fs, params)

            % 第一步：生成早期反射
            earlyAudio = createEarlyReflections(app, input, fs);

            % 第二步：使用短全通滤波器增加声音扩散
            diffusedAudio = applyAllpassCascade( ...
                app, input, fs, [0.0047 0.0123], 0.70);

            diffusedAudio = applyAllpassCascade( ...
                app, diffusedAudio, fs, [0.0227], 0.62);

            % 第三步：建立多条长延迟反馈通道
            delaySeconds = [0.031 0.043 0.059 0.071];

            lateAudio = zeros(size(diffusedAudio));

            % 高频衰减参数
            lowpassPole = min(0.95, max(0, ...
                0.90 * params.hfDamping));

            % 逐声道处理
            for channel = 1:size(diffusedAudio, 2)

                channelWet = zeros(size(diffusedAudio, 1), 1);

                % 逐延迟通道处理
                for index = 1:numel(delaySeconds)

                    delaySamples = max(2, ...
                        round(delaySeconds(index) * fs) + channel - 1);

                    % 根据RT60和反馈旋钮计算反馈系数
                    feedback = calculateCombFeedback( ...
                        app, delaySamples, fs, params);

                    % 防止反馈过强导致振荡
                    feedback = min(0.94, 0.92 * feedback);

                    % 低通反馈滤波器分子
                    numerator = [1 -lowpassPole];

                    % 低通反馈滤波器分母
                    denominator = zeros(1, delaySamples + 1);
                    denominator(1) = 1;

                    denominator(2) = ...
                        denominator(2) - lowpassPole;

                    denominator(delaySamples + 1) = ...
                        denominator(delaySamples + 1) - ...
                        feedback * (1 - lowpassPole);

                    % 对当前延迟通道进行滤波
                    delayedSignal = filter( ...
                        numerator, denominator, ...
                        diffusedAudio(:, channel));

                    % 累加各条延迟通道
                    channelWet = channelWet + delayedSignal;
                end

                % 对多条延迟通道取平均
                lateAudio(:, channel) = ...
                    channelWet / numel(delaySeconds);
            end

            % 第四步：增加长全通扩散
            lateAudio = applyAllpassCascade( ...
                app, lateAudio, fs, [0.029 0.037], 0.66);

            lateAudio = applyAllpassCascade( ...
                app, lateAudio, fs, [0.053], 0.58);

            % 第五步：合并早期反射和后期混响
            wetAudio = 0.20 * earlyAudio + ...
                0.80 * lateAudio;

            % 第六步：防止输出幅度过大
            wetPeak = max(abs(wetAudio(:)));

            if wetPeak > 1
                wetAudio = wetAudio / wetPeak;
            end
        end


        function output = mixAndProtectOutput(~, dryAudio, wetAudio, params)
            if isempty(wetAudio) || any(~isfinite(wetAudio(:)))
                error('DigitalReverb:InvalidWetAudio', '混响网络生成了无效音频。');
            end
            output = (1 - params.wetRatio) * dryAudio + ...
                params.wetRatio * wetAudio;
            output = output * params.outputGain;
            if isempty(output) || any(~isfinite(output(:)))
                error('DigitalReverb:InvalidOutput', '混响输出为空或包含 NaN/Inf。');
            end
            peakValue = max(abs(output(:)));
            if peakValue > 1
                output = output * (0.98 / peakValue);
            end
        end

        function output = renderSelectedModel(app, audio, fs, params)

            % 对输入音频增加预延迟和混响尾部空间
            [networkInput, dryAudio] = ...
                prepareNetworkInput(app, audio, fs, params);

            % 根据下拉框选择对应的混响模型
            switch app.DropDown.Value

                case 'Schroeder混响'
                    wetAudio = applySchroederNetwork( ...
                        app, networkInput, fs, params);

                case 'Moorer混响'
                    wetAudio = applyMoorerNetwork( ...
                        app, networkInput, fs, params);

                case 'Gardner混响'
                    wetAudio = applyGardnerNetwork( ...
                        app, networkInput, fs, params);

                otherwise
                    error('DigitalReverb:UnsupportedModel', ...
                        '所选混响模型尚未实现。');
            end

            % 将原声和混响声按照干湿比混合
            output = mixAndProtectOutput( ...
                app, dryAudio, wetAudio, params);
        end

        function finishProcessing(app)
            if ~isvalid(app) || app.IsClosing
                return;
            end
            app.IsProcessing = false;
            updateControlState(app);
        end

        function generateReverbInternal(app)
            if isempty(app.OriginalAudio) || isempty(app.SampleRate)
                uialert(app.UIFigure, '请先从主工作站载入一首音乐。', ...
                    '未载入音频', 'Icon', 'warning');
                return;
            end
            if app.IsProcessing
                return;
            end

            stopAllPlayback(app);
            app.IsProcessing = true;
            app.ReverbIsValid = false;
            updateControlState(app);
            setStatus(app, '正在生成混响...');
            drawnow;
            processingCleanup = onCleanup(@()finishProcessing(app));

            try
                params = getParameters(app);
                result = renderSelectedModel(app, app.OriginalAudio, app.SampleRate, params);
                if isempty(result) || any(~isfinite(result(:)))
                    error('DigitalReverb:InvalidOutput', '混响输出无效。');
                end
                app.ReverbAudio = result;
                app.ReverbIsValid = true;
                refreshWaveformData(app, 0);
                setStatus(app, '混响已生成。');
            catch ME
                app.ReverbAudio = [];
                app.ReverbIsValid = false;
                clearReverbWaveform(app);
                setStatus(app, '生成失败。');
                uialert(app.UIFigure, ME.message, '混响生成错误', 'Icon', 'error');
            end
            clear processingCleanup;
        end

        function initializeWaveformObjects(app)
            cla(app.UIAxes2);
            cla(app.UIAxes);
            grid(app.UIAxes2, 'on');
            grid(app.UIAxes, 'on');
            app.OriginalWaveLine = line(app.UIAxes2, nan, nan, ...
                'Color', [0.12 0.40 0.72], 'LineWidth', 0.8);
            app.ReverbWaveLine = line(app.UIAxes, nan, nan, ...
                'Color', [0.12 0.40 0.72], 'LineWidth', 0.8);
            app.OriginalCursorLine = line(app.UIAxes2, [0 0], [-1 1], ...
                'Color', [0.85 0.34 0.16], 'LineWidth', 1.2);
            app.ReverbCursorLine = line(app.UIAxes, [0 0], [-1 1], ...
                'Color', [0.85 0.34 0.16], 'LineWidth', 1.2);
            xlim(app.UIAxes2, [0 10]);
            xlim(app.UIAxes, [0 10]);
            ylim(app.UIAxes2, [-1 1]);
            ylim(app.UIAxes, [-1 1]);
        end

        function [xData, yData] = waveformSlice(~, audio, fs, lowTime, highTime)
            if isempty(audio)
                xData = nan;
                yData = nan;
                return;
            end
            firstSample = max(1, floor(lowTime * fs) + 1);
            lastSample = min(size(audio, 1), ceil(highTime * fs) + 1);
            if firstSample > lastSample
                xData = nan;
                yData = nan;
                return;
            end
            indices = firstSample:lastSample;
            stride = max(1, ceil(numel(indices) / 5000));
            indices = indices(1:stride:end);
            xData = (indices - 1) / fs;
            yData = mean(audio(indices, :), 2);
        end

        function refreshWaveformData(app, centerTime)
            if isempty(app.OriginalWaveLine) || ~isvalid(app.OriginalWaveLine)
                initializeWaveformObjects(app);
            end
            if isempty(app.SampleRate)
                return;
            end

            maxDuration = 0;
            if ~isempty(app.OriginalAudio)
                maxDuration = size(app.OriginalAudio, 1) / app.SampleRate;
            end
            if ~isempty(app.ReverbAudio)
                maxDuration = max(maxDuration, size(app.ReverbAudio, 1) / app.SampleRate);
            end
            lowTime = max(0, centerTime - 5);
            highTime = min(maxDuration, centerTime + 5);
            if highTime <= lowTime
                highTime = min(maxDuration, lowTime + 10);
            end
            if highTime <= lowTime
                highTime = lowTime + 0.01;
            end

            [xOriginal, yOriginal] = waveformSlice(app, app.OriginalAudio, ...
                app.SampleRate, lowTime, highTime);
            [xReverb, yReverb] = waveformSlice(app, app.ReverbAudio, ...
                app.SampleRate, lowTime, highTime);
            app.OriginalWaveLine.XData = xOriginal;
            app.OriginalWaveLine.YData = yOriginal;
            app.ReverbWaveLine.XData = xReverb;
            app.ReverbWaveLine.YData = yReverb;
            app.OriginalCursorLine.XData = [centerTime centerTime];
            app.ReverbCursorLine.XData = [centerTime centerTime];
            xlim(app.UIAxes2, [lowTime highTime]);
            xlim(app.UIAxes, [lowTime highTime]);

            originalPeak = 1;
            if ~isempty(app.OriginalAudio)
                originalPeak = max(1, 1.05 * max(abs(app.OriginalAudio(:))));
            end
            reverbPeak = 1;
            if ~isempty(app.ReverbAudio)
                reverbPeak = max(1, 1.05 * max(abs(app.ReverbAudio(:))));
            end
            ylim(app.UIAxes2, [-originalPeak originalPeak]);
            ylim(app.UIAxes, [-reverbPeak reverbPeak]);
            app.OriginalCursorLine.YData = [-originalPeak originalPeak];
            app.ReverbCursorLine.YData = [-reverbPeak reverbPeak];
        end

        function clearReverbWaveform(app)
            if ~isempty(app.ReverbWaveLine) && isvalid(app.ReverbWaveLine)
                app.ReverbWaveLine.XData = nan;
                app.ReverbWaveLine.YData = nan;
            end
            if ~isempty(app.ReverbCursorLine) && isvalid(app.ReverbCursorLine)
                app.ReverbCursorLine.XData = [0 0];
            end
        end

        function stopPlaybackTimer(app, deleteTimer)
            if nargin < 2
                deleteTimer = false;
            end
            if isempty(app.PlaybackTimer)
                return;
            end
            try
                if isvalid(app.PlaybackTimer)
                    stop(app.PlaybackTimer);
                    if deleteTimer
                        delete(app.PlaybackTimer);
                    end
                end
            catch
            end
            if deleteTimer || ~isvalid(app.PlaybackTimer)
                app.PlaybackTimer = [];
            end
        end

        function startPlaybackTimer(app)
            stopPlaybackTimer(app, false);
            if isempty(app.PlaybackTimer) || ~isvalid(app.PlaybackTimer)
                app.PlaybackTimer = timer( ...
                    'Name', 'DigitalReverbPlaybackTimer', ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'Period', 0.08, ...
                    'BusyMode', 'drop', ...
                    'TimerFcn', @(~, ~)updatePlaybackDisplay(app));
            end
            start(app.PlaybackTimer);
        end

        function updatePlaybackDisplay(app)
            if app.IsClosing || isempty(app.ActivePlayer) || ...
                    ~isvalid(app.ActivePlayer)
                stopPlaybackTimer(app, false);
                return;
            end
            try
                currentTime = max(0, ...
                    (app.ActivePlayer.CurrentSample - 1) / app.SampleRate);
                refreshWaveformData(app, currentTime);
                if ~isplaying(app.ActivePlayer)
                    stopPlaybackTimer(app, false);
                end
            catch
                stopPlaybackTimer(app, false);
            end
        end

        function stopPlayer(~, player)
            if isempty(player)
                return;
            end
            try
                if isvalid(player)
                    stop(player);
                    delete(player);
                end
            catch
            end
        end

        function stopAllPlayback(app)
            stopPlaybackTimer(app, false);
            stopPlayer(app, app.OriginalPlayer);
            stopPlayer(app, app.ReverbPlayer);
            app.OriginalPlayer = [];
            app.ReverbPlayer = [];
            app.ActivePlayer = [];
            app.ActivePlaybackType = '';
        end

        function playAudio(app, playbackType)
            stopAllPlayback(app);
            switch playbackType
                case 'original'
                    if isempty(app.OriginalAudio)
                        uialert(app.UIFigure, '没有可播放的原始音频。', ...
                            '无法播放', 'Icon', 'warning');
                        return;
                    end
                    app.OriginalPlayer = audioplayer(app.OriginalAudio, app.SampleRate);
                    app.ActivePlayer = app.OriginalPlayer;
                    app.ActivePlaybackType = 'original';
                    setStatus(app, '正在播放原声。');
                case 'reverb'
                    if ~app.ReverbIsValid || isempty(app.ReverbAudio)
                        uialert(app.UIFigure, '请先按当前参数重新生成混响。', ...
                            '无法播放', 'Icon', 'warning');
                        return;
                    end
                    app.ReverbPlayer = audioplayer(app.ReverbAudio, app.SampleRate);
                    app.ActivePlayer = app.ReverbPlayer;
                    app.ActivePlaybackType = 'reverb';
                    setStatus(app, '正在播放混响。');
            end
            play(app.ActivePlayer);
            startPlaybackTimer(app);
        end

        function fileName = defaultSaveName(app)
            [~, baseName] = fileparts(app.SongName);
            if isempty(baseName)
                baseName = '音频';
            end
            baseName = regexprep(baseName, '[\\/:*?"<>|]', '_');
            fileName = [baseName '_混响.wav'];
        end

        function cleanupResources(app)
            stopAllPlayback(app);
            stopPlaybackTimer(app, true);
            app.OriginalPlayer = [];
            app.ReverbPlayer = [];
            app.ActivePlayer = [];
        end

        function notifyMainAppClosed(app)
            if isempty(app.MainApp)
                return;
            end
            try
                if isvalid(app.MainApp) && ismethod(app.MainApp, 'digitalReverbClosed')
                    digitalReverbClosed(app.MainApp, app);
                end
            catch
            end
            app.MainApp = [];
        end
    end

    methods (Access = public)

        function setMainApp(app, mainApp)
            app.MainApp = mainApp;
        end

        function loadAudioFromMainApp(app, audioData, sampleRate, songName, varargin)
            if nargin >= 5
                app.MainApp = varargin{1};
            end
            if isempty(audioData)
                error('DigitalReverb:EmptyAudio', '传入的音频不能为空。');
            end
            if ~isnumeric(audioData) || ndims(audioData) > 2
                error('DigitalReverb:InvalidAudio', '音频必须是二维数值矩阵。');
            end
            if ~isscalar(sampleRate) || ~isfinite(sampleRate) || sampleRate <= 0
                error('DigitalReverb:InvalidSampleRate', '采样率必须为正的有限标量。');
            end

            audioData = convertAudioToDouble(app, audioData);
            if isrow(audioData)
                audioData = audioData(:);
            end
            if any(~isfinite(audioData(:)))
                error('DigitalReverb:NonfiniteAudio', '音频包含 NaN 或 Inf。');
            end
            if size(audioData, 2) > 2
                audioData = mean(audioData, 2);
            end
            if nargin < 4 || isempty(songName)
                songName = '未命名音频';
            end

            stopAllPlayback(app);
            app.OriginalAudio = audioData;
            app.SampleRate = double(sampleRate);
            app.SongName = char(songName);
            app.ReverbAudio = [];
            app.ReverbIsValid = false;
            updateAudioInfo(app);
            updateControlState(app);
            clearReverbWaveform(app);
            refreshWaveformData(app, 0);
            setStatus(app, '已载入音频，请生成混响。');
        end

        function generateReverb(app)
            generateReverbInternal(app);
        end

        function [audioData, sampleRate, isValid] = getReverbAudio(app)
            audioData = app.ReverbAudio;
            sampleRate = app.SampleRate;
            isValid = app.ReverbIsValid;
        end

        function show(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                app.UIFigure.Visible = 'on';
                figure(app.UIFigure);
            end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % 初始化波形显示对象
            initializeWaveformObjects(app);

            % 更新模型说明
            updateModelDescription(app);

            % 更新音频信息
            updateAudioInfo(app);

            % 更新按钮启用状态
            updateControlState(app);

            % 固定“混响时间”旋钮的刻度位置和显示文字
            app.sKnob.MajorTicks = [0.3 1.0 1.8 2.6 3.4 4.2 5.0];
            app.sKnob.MajorTickLabels = ...
                {'0.3', '1.0', '1.8', '2.6', '3.4', '4.2', '5.0'};

            % 固定“反馈系数”旋钮的刻度位置和显示文字
            app.Knob_2.MajorTicks = [0 0.2 0.4 0.6 0.8 0.95];
            app.Knob_2.MajorTickLabels = ...
                {'0', '0.2', '0.4', '0.6', '0.8', '0.95'};

            % 更新六个参数下方的具体数值
            updateParameterValueLabels(app);

            % 更新状态栏文字
            setStatus(app, '等待主工作站载入音频。');

        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.UIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 2x1 grid
                app.GridLayout.RowHeight = {751, 751};
                app.GridLayout.ColumnWidth = {'1x'};
                app.RightPanel.Layout.Row = 2;
                app.RightPanel.Layout.Column = 1;
            else
                % Change to a 1x2 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {227, '1x'};
                app.RightPanel.Layout.Row = 1;
                app.RightPanel.Layout.Column = 2;
            end
        end

        % Button pushed function: Button
        function PlayOriginalButtonPushed(app, event)
            playAudio(app, 'original');
        end

        % Button pushed function: Button_2
        function PlayReverbButtonPushed(app, event)
            playAudio(app, 'reverb');
        end

        % Button pushed function: Button_3
        function StopButtonPushed(app, event)
            stopAllPlayback(app);
            refreshWaveformData(app, 0);
            setStatus(app, '播放已停止。');
        end

        % Button pushed function: Button_5
        function SaveReverbButtonPushed(app, event)
            if ~app.ReverbIsValid || isempty(app.ReverbAudio)
                uialert(app.UIFigure, '请先生成有效的混响音频。', ...
                    '无法保存', 'Icon', 'warning');
                return;
            end
            if any(~isfinite(app.ReverbAudio(:)))
                uialert(app.UIFigure, '混响音频包含无效数值，不能保存。', ...
                    '保存失败', 'Icon', 'error');
                return;
            end
            [fileName, pathName] = uiputfile('*.wav', '保存混响音频', ...
                defaultSaveName(app));
            if isequal(fileName, 0)
                return;
            end
            try
                audiowrite(fullfile(pathName, fileName), ...
                    app.ReverbAudio, app.SampleRate);
                setStatus(app, '混响音频已保存。');
            catch ME
                uialert(app.UIFigure, ME.message, '保存失败', 'Icon', 'error');
            end
        end

        % Button pushed function: Button_7
        function ReturnToMainButtonPushed(app, event)
            stopAllPlayback(app);
            try
                if ~isempty(app.MainApp) && isvalid(app.MainApp) && ...
                        isprop(app.MainApp, 'UIFigure') && isvalid(app.MainApp.UIFigure)
                    app.MainApp.UIFigure.Visible = 'on';
                    figure(app.MainApp.UIFigure);
                    app.UIFigure.Visible = 'off';
                else
                    setStatus(app, '主工作站不可用。');
                end
            catch
                setStatus(app, '无法返回主工作站。');
            end
        end

        % Button pushed function: Button_6
        function GenerateReverbButtonPushed(app, event)
            generateReverbInternal(app);
        end

        % Value changed function: DropDown
        function ModelDropDownValueChanged(app, event)
            updateModelDescription(app);
            invalidateReverb(app, '模型已改变，请重新生成混响。');
            clearReverbWaveform(app);
        end

        % Value changed function: Knob, Knob3, Knob_2, Knob_3, msKnob, 
        % ...and 1 other component
        function ParameterValueChanged(app, event)
            updateParameterValueLabels(app);
            invalidateReverb(app, '参数已改变，请重新生成混响。');
            clearReverbWaveform(app);
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            if app.IsClosing
                return;
            end
            app.IsClosing = true;
            cleanupResources(app);
            notifyMainAppClosed(app);
            delete(app);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Color = [0.651 0.651 0.651];
            app.UIFigure.Position = [100 100 969 751];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Theme = 'light';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {227, '1x'};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.LeftPanel);
            app.GridLayout2.RowHeight = {'1x', '7x', '1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout2.BackgroundColor = [0.851 0.851 0.851];

            % Create Button
            app.Button = uibutton(app.GridLayout2, 'push');
            app.Button.ButtonPushedFcn = createCallbackFcn(app, @PlayOriginalButtonPushed, true);
            app.Button.FontSize = 18;
            app.Button.Layout.Row = 4;
            app.Button.Layout.Column = [1 2];
            app.Button.Text = '播放原声';

            % Create Button_2
            app.Button_2 = uibutton(app.GridLayout2, 'push');
            app.Button_2.ButtonPushedFcn = createCallbackFcn(app, @PlayReverbButtonPushed, true);
            app.Button_2.FontSize = 18;
            app.Button_2.Layout.Row = 5;
            app.Button_2.Layout.Column = [1 2];
            app.Button_2.Text = '播放混响';

            % Create Button_3
            app.Button_3 = uibutton(app.GridLayout2, 'push');
            app.Button_3.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.Button_3.FontSize = 18;
            app.Button_3.Layout.Row = 6;
            app.Button_3.Layout.Column = [1 2];
            app.Button_3.Text = '停止播放';

            % Create Button_5
            app.Button_5 = uibutton(app.GridLayout2, 'push');
            app.Button_5.ButtonPushedFcn = createCallbackFcn(app, @SaveReverbButtonPushed, true);
            app.Button_5.FontSize = 18;
            app.Button_5.Layout.Row = 7;
            app.Button_5.Layout.Column = [1 2];
            app.Button_5.Text = '保存音频';

            % Create GridLayout5
            app.GridLayout5 = uigridlayout(app.GridLayout2);
            app.GridLayout5.ColumnWidth = {'1x', '1.5x'};
            app.GridLayout5.RowHeight = {'1x', '1x', '1x', '1x'};
            app.GridLayout5.Layout.Row = 2;
            app.GridLayout5.Layout.Column = [1 2];
            app.GridLayout5.BackgroundColor = [0.851 0.851 0.851];

            % Create Label_3
            app.Label_3 = uilabel(app.GridLayout5);
            app.Label_3.FontSize = 14;
            app.Label_3.Layout.Row = 1;
            app.Label_3.Layout.Column = 1;
            app.Label_3.Text = '当前歌曲：';

            % Create Label_6
            app.Label_6 = uilabel(app.GridLayout5);
            app.Label_6.FontSize = 14;
            app.Label_6.Layout.Row = 2;
            app.Label_6.Layout.Column = 1;
            app.Label_6.Text = '采样频率：';

            % Create Label_7
            app.Label_7 = uilabel(app.GridLayout5);
            app.Label_7.FontSize = 14;
            app.Label_7.Layout.Row = 3;
            app.Label_7.Layout.Column = 1;
            app.Label_7.Text = '声道数：';

            % Create Label_8
            app.Label_8 = uilabel(app.GridLayout5);
            app.Label_8.FontSize = 14;
            app.Label_8.Layout.Row = 4;
            app.Label_8.Layout.Column = 1;
            app.Label_8.Text = '时长：';

            % Create Label5
            app.Label5 = uilabel(app.GridLayout5);
            app.Label5.Layout.Row = 1;
            app.Label5.Layout.Column = 2;
            app.Label5.Text = 'Label5';

            % Create Label6
            app.Label6 = uilabel(app.GridLayout5);
            app.Label6.Layout.Row = 2;
            app.Label6.Layout.Column = 2;
            app.Label6.Text = 'Label6';

            % Create Label7
            app.Label7 = uilabel(app.GridLayout5);
            app.Label7.Layout.Row = 3;
            app.Label7.Layout.Column = 2;
            app.Label7.Text = 'Label7';

            % Create Label8
            app.Label8 = uilabel(app.GridLayout5);
            app.Label8.Layout.Row = 4;
            app.Label8.Layout.Column = 2;
            app.Label8.Text = 'Label8';

            % Create Label_4
            app.Label_4 = uilabel(app.GridLayout2);
            app.Label_4.HorizontalAlignment = 'center';
            app.Label_4.VerticalAlignment = 'bottom';
            app.Label_4.FontSize = 18;
            app.Label_4.Layout.Row = 1;
            app.Label_4.Layout.Column = [1 2];
            app.Label_4.Text = '播放控制';

            % Create Button_7
            app.Button_7 = uibutton(app.GridLayout2, 'push');
            app.Button_7.ButtonPushedFcn = createCallbackFcn(app, @ReturnToMainButtonPushed, true);
            app.Button_7.FontSize = 18;
            app.Button_7.Layout.Row = 8;
            app.Button_7.Layout.Column = [1 2];
            app.Button_7.Text = '返回工作台';

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.RightPanel);
            app.GridLayout3.ColumnWidth = {'2x', '1x', '1x', '1x'};
            app.GridLayout3.RowHeight = {0, '1x', '2x', '2x', '1x', '2x', '2x', '1x', '3x', '1x', '3x', '1x'};
            app.GridLayout3.BackgroundColor = [0.851 0.851 0.851];

            % Create UIAxes
            app.UIAxes = uiaxes(app.GridLayout3);
            title(app.UIAxes, '混响后音频波形')
            xlabel(app.UIAxes, '时间/s')
            ylabel(app.UIAxes, '幅值')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Layout.Row = [6 8];
            app.UIAxes.Layout.Column = [1 4];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.GridLayout3);
            title(app.UIAxes2, '原始音频波形')
            xlabel(app.UIAxes2, '时间/s')
            ylabel(app.UIAxes2, '幅值')
            zlabel(app.UIAxes2, 'Z')
            app.UIAxes2.Layout.Row = [3 5];
            app.UIAxes2.Layout.Column = [1 4];

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.GridLayout3);
            app.GridLayout4.ColumnWidth = {'1x', '2x'};
            app.GridLayout4.RowHeight = {'1x', '2x', '1x'};
            app.GridLayout4.Layout.Row = [9 12];
            app.GridLayout4.Layout.Column = 1;
            app.GridLayout4.BackgroundColor = [0.851 0.851 0.851];

            % Create Label_2
            app.Label_2 = uilabel(app.GridLayout4);
            app.Label_2.HorizontalAlignment = 'right';
            app.Label_2.FontSize = 14;
            app.Label_2.FontWeight = 'bold';
            app.Label_2.Layout.Row = 1;
            app.Label_2.Layout.Column = 1;
            app.Label_2.Text = '模型选择';

            % Create DropDown
            app.DropDown = uidropdown(app.GridLayout4);
            app.DropDown.Items = {'Schroeder混响', 'Moorer混响', 'Gardner混响'};
            app.DropDown.ValueChangedFcn = createCallbackFcn(app, @ModelDropDownValueChanged, true);
            app.DropDown.FontWeight = 'bold';
            app.DropDown.Layout.Row = 1;
            app.DropDown.Layout.Column = 2;
            app.DropDown.Value = 'Schroeder混响';

            % Create TextArea
            app.TextArea = uitextarea(app.GridLayout4);
            app.TextArea.FontSize = 16;
            app.TextArea.Layout.Row = 2;
            app.TextArea.Layout.Column = [1 2];
            app.TextArea.Value = {'Schroeder模型：'; '由多个并联梳状滤波器和级联全通滤波器组成，'; '结构简单，计算量较小，适合基本混响模拟。'};

            % Create Button_6
            app.Button_6 = uibutton(app.GridLayout4, 'push');
            app.Button_6.ButtonPushedFcn = createCallbackFcn(app, @GenerateReverbButtonPushed, true);
            app.Button_6.FontSize = 18;
            app.Button_6.Layout.Row = 3;
            app.Button_6.Layout.Column = [1 2];
            app.Button_6.Text = '开始混响';

            % Create Knob_2
            app.Knob_2 = uiknob(app.GridLayout3, 'continuous');
            app.Knob_2.Limits = [0 0.95];
            app.Knob_2.MajorTickLabels = {'0', '0.2', '0.4', '0.6', '0.8', '0.95'};
            app.Knob_2.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.Knob_2.Layout.Row = 11;
            app.Knob_2.Layout.Column = 2;
            app.Knob_2.MinorTicksMode = 'manual';
            app.Knob_2.Value = 0.7;

            % Create Knob_3
            app.Knob_3 = uiknob(app.GridLayout3, 'continuous');
            app.Knob_3.Limits = [0 1];
            app.Knob_3.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.Knob_3.Layout.Row = 11;
            app.Knob_3.Layout.Column = 3;
            app.Knob_3.MinorTicksMode = 'manual';
            app.Knob_3.Value = 0.5;

            % Create Knob3
            app.Knob3 = uiknob(app.GridLayout3, 'continuous');
            app.Knob3.Limits = [0 1.5];
            app.Knob3.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.Knob3.Layout.Row = 11;
            app.Knob3.Layout.Column = 4;
            app.Knob3.Value = 1;

            % Create Knob
            app.Knob = uiknob(app.GridLayout3, 'continuous');
            app.Knob.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.Knob.Layout.Row = 9;
            app.Knob.Layout.Column = 3;
            app.Knob.MinorTicksMode = 'manual';
            app.Knob.Value = 40;

            % Create msKnob
            app.msKnob = uiknob(app.GridLayout3, 'continuous');
            app.msKnob.Limits = [0 200];
            app.msKnob.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.msKnob.Layout.Row = 9;
            app.msKnob.Layout.Column = 4;
            app.msKnob.MinorTicksMode = 'manual';
            app.msKnob.Value = 20;

            % Create Label_5
            app.Label_5 = uilabel(app.GridLayout3);
            app.Label_5.HorizontalAlignment = 'center';
            app.Label_5.FontSize = 24;
            app.Label_5.FontWeight = 'bold';
            app.Label_5.Layout.Row = 2;
            app.Label_5.Layout.Column = [1 4];
            app.Label_5.Text = '数字混响器';

            % Create sKnob
            app.sKnob = uiknob(app.GridLayout3, 'continuous');
            app.sKnob.Limits = [0.3 5];
            app.sKnob.MajorTickLabels = {'0.3', '1.0', '1.8', '2.6', '3.4', '4.2', '5'};
            app.sKnob.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.sKnob.Layout.Row = 9;
            app.sKnob.Layout.Column = 2;
            app.sKnob.MinorTicksMode = 'manual';
            app.sKnob.Value = 1.5;

            % Create GridLayout6
            app.GridLayout6 = uigridlayout(app.GridLayout3);
            app.GridLayout6.ColumnWidth = {'1.2x', '1x'};
            app.GridLayout6.RowHeight = {'1x'};
            app.GridLayout6.Layout.Row = 10;
            app.GridLayout6.Layout.Column = 2;

            % Create Label_9
            app.Label_9 = uilabel(app.GridLayout6);
            app.Label_9.HorizontalAlignment = 'right';
            app.Label_9.Layout.Row = 1;
            app.Label_9.Layout.Column = 1;
            app.Label_9.Text = '混响时间:';

            % Create ReverbTimeValueLabel
            app.ReverbTimeValueLabel = uilabel(app.GridLayout6);
            app.ReverbTimeValueLabel.Layout.Row = 1;
            app.ReverbTimeValueLabel.Layout.Column = 2;
            app.ReverbTimeValueLabel.Text = '1.5s';

            % Create GridLayout6_2
            app.GridLayout6_2 = uigridlayout(app.GridLayout3);
            app.GridLayout6_2.ColumnWidth = {'1.2x', '1x'};
            app.GridLayout6_2.RowHeight = {'1x'};
            app.GridLayout6_2.Layout.Row = 10;
            app.GridLayout6_2.Layout.Column = 3;

            % Create Label_10
            app.Label_10 = uilabel(app.GridLayout6_2);
            app.Label_10.HorizontalAlignment = 'right';
            app.Label_10.Layout.Row = 1;
            app.Label_10.Layout.Column = 1;
            app.Label_10.Text = '干湿比:';

            % Create WetDryValueLabel
            app.WetDryValueLabel = uilabel(app.GridLayout6_2);
            app.WetDryValueLabel.Layout.Row = 1;
            app.WetDryValueLabel.Layout.Column = 2;
            app.WetDryValueLabel.Text = '40%';

            % Create GridLayout6_3
            app.GridLayout6_3 = uigridlayout(app.GridLayout3);
            app.GridLayout6_3.ColumnWidth = {'1.2x', '1x'};
            app.GridLayout6_3.RowHeight = {'1x'};
            app.GridLayout6_3.Layout.Row = 10;
            app.GridLayout6_3.Layout.Column = 4;

            % Create Label_11
            app.Label_11 = uilabel(app.GridLayout6_3);
            app.Label_11.HorizontalAlignment = 'right';
            app.Label_11.VerticalAlignment = 'bottom';
            app.Label_11.Layout.Row = 1;
            app.Label_11.Layout.Column = 1;
            app.Label_11.Text = '预延迟:';

            % Create PreDelayValueLabel
            app.PreDelayValueLabel = uilabel(app.GridLayout6_3);
            app.PreDelayValueLabel.Layout.Row = 1;
            app.PreDelayValueLabel.Layout.Column = 2;
            app.PreDelayValueLabel.Text = '20ms';

            % Create GridLayout6_4
            app.GridLayout6_4 = uigridlayout(app.GridLayout3);
            app.GridLayout6_4.ColumnWidth = {'1.2x', '1x'};
            app.GridLayout6_4.RowHeight = {'1x'};
            app.GridLayout6_4.Layout.Row = 12;
            app.GridLayout6_4.Layout.Column = 3;

            % Create Label_13
            app.Label_13 = uilabel(app.GridLayout6_4);
            app.Label_13.HorizontalAlignment = 'right';
            app.Label_13.Layout.Row = 1;
            app.Label_13.Layout.Column = 1;
            app.Label_13.Text = '高频衰减:';

            % Create HFDampingValueLabel
            app.HFDampingValueLabel = uilabel(app.GridLayout6_4);
            app.HFDampingValueLabel.Layout.Row = 1;
            app.HFDampingValueLabel.Layout.Column = 2;
            app.HFDampingValueLabel.Text = '0.5';

            % Create GridLayout6_5
            app.GridLayout6_5 = uigridlayout(app.GridLayout3);
            app.GridLayout6_5.ColumnWidth = {'1.2x', '1x'};
            app.GridLayout6_5.RowHeight = {'1x'};
            app.GridLayout6_5.Layout.Row = 12;
            app.GridLayout6_5.Layout.Column = 4;

            % Create Label_14
            app.Label_14 = uilabel(app.GridLayout6_5);
            app.Label_14.HorizontalAlignment = 'right';
            app.Label_14.Layout.Row = 1;
            app.Label_14.Layout.Column = 1;
            app.Label_14.Text = '输出增益:';

            % Create OutputGainValueLabel
            app.OutputGainValueLabel = uilabel(app.GridLayout6_5);
            app.OutputGainValueLabel.Layout.Row = 1;
            app.OutputGainValueLabel.Layout.Column = 2;
            app.OutputGainValueLabel.Text = '1';

            % Create GridLayout6_6
            app.GridLayout6_6 = uigridlayout(app.GridLayout3);
            app.GridLayout6_6.ColumnWidth = {'1.2x', '1x'};
            app.GridLayout6_6.RowHeight = {'1x'};
            app.GridLayout6_6.Layout.Row = 12;
            app.GridLayout6_6.Layout.Column = 2;

            % Create Label_12
            app.Label_12 = uilabel(app.GridLayout6_6);
            app.Label_12.HorizontalAlignment = 'right';
            app.Label_12.Layout.Row = 1;
            app.Label_12.Layout.Column = 1;
            app.Label_12.Text = '反馈系数:';

            % Create FeedbackValueLabel
            app.FeedbackValueLabel = uilabel(app.GridLayout6_6);
            app.FeedbackValueLabel.Layout.Row = 1;
            app.FeedbackValueLabel.Layout.Column = 2;
            app.FeedbackValueLabel.Text = '0.7';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = DigitalReverb

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end