classdef GraphicEqualizer < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure               matlab.ui.Figure
        GridLayout             matlab.ui.container.GridLayout
        StopPlaybackButton     matlab.ui.control.Button
        PlayEqualizedButton    matlab.ui.control.Button
        PlayOriginalButton     matlab.ui.control.Button
        SaveAudioButton        matlab.ui.control.Button
        Label_7                matlab.ui.control.Label
        BackToWorkbenchButton  matlab.ui.control.Button
        Gain16kLabel           matlab.ui.control.Label
        Gain8kLabel            matlab.ui.control.Label
        Gain4kLabel            matlab.ui.control.Label
        Gain2kLabel            matlab.ui.control.Label
        Gain1kLabel            matlab.ui.control.Label
        Gain500Label           matlab.ui.control.Label
        Gain250Label           matlab.ui.control.Label
        Gain125Label           matlab.ui.control.Label
        Gain62Label            matlab.ui.control.Label
        Slider16k              matlab.ui.control.Slider
        Slider8k               matlab.ui.control.Slider
        Slider4k               matlab.ui.control.Slider
        Slider2k               matlab.ui.control.Slider
        Slider1k               matlab.ui.control.Slider
        Slider500              matlab.ui.control.Slider
        Slider250              matlab.ui.control.Slider
        Slider125              matlab.ui.control.Slider
        Label_6                matlab.ui.control.Label
        CurrentSongLabel       matlab.ui.control.Label
        Label_2                matlab.ui.control.Label
        kHzLabel_5             matlab.ui.control.Label
        kHzLabel_4             matlab.ui.control.Label
        kHzLabel_3             matlab.ui.control.Label
        kHzLabel_2             matlab.ui.control.Label
        kHzLabel               matlab.ui.control.Label
        HzLabel_5              matlab.ui.control.Label
        HzLabel_4              matlab.ui.control.Label
        HzLabel_3              matlab.ui.control.Label
        HzLabel_2              matlab.ui.control.Label
        GridLayout2            matlab.ui.container.GridLayout
        ProcessedSpectrumAxes  matlab.ui.control.UIAxes
        OriginalSpectrumAxes   matlab.ui.control.UIAxes
        EqualizerSwitch        matlab.ui.control.Switch
        Slider62               matlab.ui.control.Slider
        Label                  matlab.ui.control.Label
    end

    properties (Access = private)
        OriginalAudio = []
        ProcessedAudio = []
        SampleRate = []
        CurrentSongName = ''
        SourceFilePath = ''
        HasAudio = false
        IsEQEnabled = false
        MainApp = []
        CallbacksInitialized = false
        PlaybackPlayer = []
    end

    methods (Access = private)
        function initializeUserInterface(app)
            if app.CallbacksInitialized
                return;
            end

            sliders = { ...
                app.Slider62, ...
                app.Slider125, ...
                app.Slider250, ...
                app.Slider500, ...
                app.Slider1k, ...
                app.Slider2k, ...
                app.Slider4k, ...
                app.Slider8k, ...
                app.Slider16k};

            for k = 1:numel(sliders)
                sliders{k}.ValueChangingFcn = ...
                    @(src, event)gainValueChanging(app, src, event);

                sliders{k}.ValueChangedFcn = ...
                    @(src, event)gainValueChanged(app, src, event);
            end

            app.EqualizerSwitch.ValueChangedFcn = ...
                @(src, event)equalizerSwitchChanged(app, src, event);

            app.SaveAudioButton.ButtonPushedFcn = ...
                @(src, event)saveAudio(app, src, event);

            app.BackToWorkbenchButton.ButtonPushedFcn = ...
                @(src, event)returnToWorkbench(app, src, event);

            app.PlayOriginalButton.ButtonPushedFcn = ...
                @(src, event)playOriginalAudio(app, src, event);

            app.PlayEqualizedButton.ButtonPushedFcn = ...
                @(src, event)playEqualizedAudio(app, src, event);

            app.StopPlaybackButton.ButtonPushedFcn = ...
                @(src, event)stopPlayback(app, src, event);

            app.CallbacksInitialized = true;

            updateGainValueLabels(app);

        end

        function playOriginalAudio(app, ~, ~)


            if ~app.HasAudio || ...
                    isempty(app.OriginalAudio) || ...
                    isempty(app.SampleRate)

                uialert(app.UIFigure, ...
                    '请先在主工作台中载入音频。', ...
                    '无法播放', ...
                    'Icon', 'warning');

                return;
            end

            stopPlayback(app);

            try
                app.PlaybackPlayer = audioplayer( ...
                    app.OriginalAudio, ...
                    app.SampleRate);

                play(app.PlaybackPlayer);

            catch ME
                app.PlaybackPlayer = [];

                uialert(app.UIFigure, ...
                    ME.message, ...
                    '原声播放失败', ...
                    'Icon', 'error');
            end

        end

        function gainValueChanging(app, source, event)
            updateOneGainLabel(app, source, event.Value);
        end

        function gainValueChanged(app, source, event)
            updateOneGainLabel(app, source, source.Value);
            if app.IsEQEnabled && app.HasAudio
                refreshProcessedAudio(app);
            end
        end

        function playEqualizedAudio(app, ~, ~)

            if ~app.HasAudio || ...
                    isempty(app.OriginalAudio) || ...
                    isempty(app.SampleRate)

                uialert(app.UIFigure, ...
                    '请先在主工作台中载入音频。', ...
                    '无法播放', ...
                    'Icon', 'warning');

                return;
            end

            stopPlayback(app);

            try
                % 使用九个滑块当前的数值重新生成均衡音频
                app.ProcessedAudio = applyGraphicEqualizer( ...
                    app, ...
                    app.OriginalAudio);

                % 刷新均衡处理后的频谱
                plotSpectrum( ...
                    app, ...
                    app.ProcessedSpectrumAxes, ...
                    app.ProcessedAudio);

                app.PlaybackPlayer = audioplayer( ...
                    app.ProcessedAudio, ...
                    app.SampleRate);

                play(app.PlaybackPlayer);

            catch ME
                app.PlaybackPlayer = [];

                uialert(app.UIFigure, ...
                    ME.message, ...
                    '均衡音频播放失败', ...
                    'Icon', 'error');
            end

        end

        function stopPlayback(app, ~, ~)

            if isempty(app.PlaybackPlayer)
                return;
            end

            try
                if isvalid(app.PlaybackPlayer)
                    stop(app.PlaybackPlayer);
                end
            catch
            end

            app.PlaybackPlayer = [];

        end

        function equalizerSwitchChanged(app, source, event)
            app.IsEQEnabled = source.ValueIndex == 2;
            if ~app.HasAudio
                uialert(app.UIFigure, '请先在主工作台中载入音频。', '尚未载入音频', 'Icon', 'warning');
                return;
            end
            refreshProcessedAudio(app);
        end

        function updateGainValueLabels(app)
            sliders = {app.Slider62, app.Slider125, app.Slider250, app.Slider500, ...
                app.Slider1k, app.Slider2k, app.Slider4k, app.Slider8k, app.Slider16k};
            labels = {app.Gain62Label, app.Gain125Label, app.Gain250Label, app.Gain500Label, ...
                app.Gain1kLabel, app.Gain2kLabel, app.Gain4kLabel, app.Gain8kLabel, app.Gain16kLabel};
            for k = 1:numel(sliders)
                labels{k}.Text = formatGainValue(app, sliders{k}.Value);
            end
        end

        function updateOneGainLabel(app, source, value)
            sliders = {app.Slider62, app.Slider125, app.Slider250, app.Slider500, ...
                app.Slider1k, app.Slider2k, app.Slider4k, app.Slider8k, app.Slider16k};
            labels = {app.Gain62Label, app.Gain125Label, app.Gain250Label, app.Gain500Label, ...
                app.Gain1kLabel, app.Gain2kLabel, app.Gain4kLabel, app.Gain8kLabel, app.Gain16kLabel};
            for k = 1:numel(sliders)
                if isequal(source, sliders{k})
                    labels{k}.Text = formatGainValue(app, value);
                    return;
                end
            end
        end

        function textValue = formatGainValue(app, value)
            if abs(value) < 0.05
                textValue = '0.0dB';
            elseif value > 0
                textValue = sprintf('+%.1fdB', value);
            else
                textValue = sprintf('%.1fdB', value);
            end
        end

        function gains = getBandGainsDB(app)
            gains = [app.Slider62.Value app.Slider125.Value app.Slider250.Value ...
                app.Slider500.Value app.Slider1k.Value app.Slider2k.Value ...
                app.Slider4k.Value app.Slider8k.Value app.Slider16k.Value];
        end

        function outputAudio = applyGraphicEqualizer(app, inputAudio)
            gainsDB = getBandGainsDB(app);
            if all(abs(gainsDB) < 1e-12)
                outputAudio = inputAudio;
                return;
            end
            filters = designFilterBank(app);
            outputAudio = inputAudio;
            linearGain = 10.^(gainsDB / 20);
            for k = 1:numel(filters)
                if isempty(filters{k}) || abs(linearGain(k) - 1) < 1e-12
                    continue;
                end
                coefficients = filters{k};
                bandAudio = filter(coefficients{1}, coefficients{2}, inputAudio);
                outputAudio = outputAudio + (linearGain(k) - 1) .* bandAudio;
            end
            peakValue = max(abs(outputAudio(:)));
            if peakValue > 0.98
                outputAudio = outputAudio .* (0.98 / peakValue);
            end
        end

        function filters = designFilterBank(app)
            centers = [62 125 250 500 1000 2000 4000 8000 16000];
            nyquist = app.SampleRate / 2;
            safetyLimit = 0.999;
            filters = cell(1, numel(centers));
            try
                highEdge = min(centers(1) * sqrt(2), nyquist * safetyLimit);
                if highEdge > 0 && highEdge < nyquist
                    [b, a] = butter(2, highEdge / nyquist, 'low');
                    filters{1} = {b, a};
                end
                for k = 2:8
                    lowEdge = centers(k) / sqrt(2);
                    highEdge = centers(k) * sqrt(2);
                    if lowEdge < nyquist * safetyLimit
                        highEdge = min(highEdge, nyquist * safetyLimit);
                        if highEdge > lowEdge
                            [b, a] = butter(2, [lowEdge highEdge] / nyquist, 'bandpass');
                            filters{k} = {b, a};
                        end
                    end
                end
                lowEdge = centers(9) / sqrt(2);
                if lowEdge < nyquist * safetyLimit
                    [b, a] = butter(2, lowEdge / nyquist, 'high');
                    filters{9} = {b, a};
                end
            catch ME
                error('GraphicEqualizer:FilterDesignFailed', '滤波器设计失败：%s', ME.message);
            end
        end

        function refreshProcessedAudio(app)
            previousAudio = app.ProcessedAudio;
            try
                if app.IsEQEnabled
                    candidate = applyGraphicEqualizer(app, app.OriginalAudio);
                else
                    candidate = app.OriginalAudio;
                end
                app.ProcessedAudio = candidate;
                plotSpectrum(app, app.ProcessedSpectrumAxes, candidate);
            catch ME
                app.ProcessedAudio = previousAudio;
                uialert(app.UIFigure, ME.message, '均衡处理失败', 'Icon', 'error');
            end
        end

        function plotSpectrum(app, axesHandle, audioData)
            try
                cla(axesHandle);
                if isempty(audioData) || isempty(app.SampleRate)
                    return;
                end
                maxSamples = min(size(audioData, 1), 65536);
                segment = audioData(1:maxSamples, :);
                sampleCount = size(segment, 1);
                if sampleCount < 2
                    return;
                end
                window = 0.5 - 0.5 .* cos(2 .* pi .* (0:sampleCount-1)' ./ (sampleCount-1));
                nfft = 2^nextpow2(sampleCount);
                spectrum = fft(segment .* repmat(window, 1, size(segment, 2)), nfft, 1);
                magnitude = mean(abs(spectrum(1:nfft/2+1, :)), 2) ./ max(sum(window), eps);
                frequency = (0:nfft/2)' .* app.SampleRate ./ nfft;
                valid = frequency >= 20 & frequency <= min(20000, app.SampleRate / 2);
                plot(axesHandle, frequency(valid), 20 .* log10(magnitude(valid) + eps), 'LineWidth', 1);
                axesHandle.XScale = 'log';
                axesHandle.XLim = [20 max(20.1, min(20000, app.SampleRate / 2))];
                grid(axesHandle, 'on');
            catch ME
                cla(axesHandle);
                error('GraphicEqualizer:SpectrumFailed', '频谱绘制失败：%s', ME.message);
            end
        end

        function saveAudio(app, source, event)
            if ~app.HasAudio
                uialert(app.UIFigure, '请先在主工作台中载入音频。', '无法保存', 'Icon', 'warning');
                return;
            end
            try
                [~, baseName] = fileparts(app.CurrentSongName);
                if isempty(baseName)
                    baseName = 'audio';
                end
                [fileName, pathName] = uiputfile('*.wav', '保存均衡器音频', [baseName '_EQ.wav']);
                if isequal(fileName, 0)
                    return;
                end
                if app.IsEQEnabled
                    audioData = app.ProcessedAudio;
                else
                    audioData = app.OriginalAudio;
                end
                fullPath = fullfile(pathName, fileName);
                audiowrite(fullPath, audioData, app.SampleRate);
                uialert(app.UIFigure, ['音频已保存至：' newline fullPath], '保存成功', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, ME.message, '保存失败', 'Icon', 'error');
            end
        end

        function returnToWorkbench(app, source, event)
            try
                if ~isempty(app.MainApp) && isvalid(app.MainApp) && ...
                        isprop(app.MainApp, 'UIFigure') && isvalid(app.MainApp.UIFigure)
                    app.MainApp.UIFigure.Visible = 'on';
                    figure(app.MainApp.UIFigure);
                    app.UIFigure.Visible = 'off';
                else
                    uialert(app.UIFigure, '主工作台当前不可用。', '无法返回', 'Icon', 'warning');
                end
            catch ME
                uialert(app.UIFigure, ME.message, '无法返回工作台', 'Icon', 'error');
            end
        end
    end

    methods (Access = public)
        function setMainApp(app, mainApp)
            app.MainApp = mainApp;
            initializeUserInterface(app);
        end

        function loadAudioFromMainApp(app, audioData, sampleRate, songName, varargin)
            try
                initializeUserInterface(app);
                if nargin >= 5
                    app.MainApp = varargin{1};
                end
                if isempty(audioData) || ~isnumeric(audioData) || ndims(audioData) > 2
                    error('音频必须是非空的二维数值矩阵。');
                end
                if ~isscalar(sampleRate) || ~isfinite(sampleRate) || sampleRate <= 0
                    error('采样率必须为正的有限标量。');
                end
                if size(audioData, 2) > 2
                    error('仅支持单声道或双声道音频。');
                end
                audioData = double(audioData);
                if isrow(audioData)
                    audioData = audioData(:);
                end
                if any(~isfinite(audioData(:)))
                    error('音频包含 NaN 或 Inf。');
                end
                if nargin < 4 || isempty(songName)
                    songName = '未命名音频';
                end
                app.OriginalAudio = audioData;
                app.ProcessedAudio = audioData;
                app.SampleRate = double(sampleRate);
                app.CurrentSongName = char(songName);
                app.SourceFilePath = '';
                if nargin >= 6 && ~isempty(varargin{2})
                    app.SourceFilePath = char(varargin{2});
                end
                app.HasAudio = true;
                app.IsEQEnabled = false;
                app.EqualizerSwitch.ValueIndex = 1;
                app.CurrentSongLabel.Text = app.CurrentSongName;
                updateGainValueLabels(app);
                plotSpectrum(app, app.OriginalSpectrumAxes, app.OriginalAudio);
                plotSpectrum(app, app.ProcessedSpectrumAxes, app.ProcessedAudio);
            catch ME
                uialert(app.UIFigure, ME.message, '载入音频失败', 'Icon', 'error');
                return;
            end
        end

        function show(app)
            initializeUserInterface(app);
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                app.UIFigure.Visible = 'on';
                figure(app.UIFigure);
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 748 587];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Theme = 'light';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'0.2x', '2.8x', '2.8x', '2.8x', '2.8x', '2.8x', '2.8x', '2.8x', '2.8x', '2.8x', '0.2x'};
            app.GridLayout.RowHeight = {'0.9x', '0.67x', '2.5x', '2.5x', '2.5x', '0.67x', '1.2x', '1.2x', '1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout.BackgroundColor = [0.9216 0.9608 0.8824];

            % Create Label
            app.Label = uilabel(app.GridLayout);
            app.Label.HorizontalAlignment = 'center';
            app.Label.FontSize = 20;
            app.Label.FontWeight = 'bold';
            app.Label.Layout.Row = 1;
            app.Label.Layout.Column = [2 10];
            app.Label.Text = '九段图示均衡器';

            % Create Slider62
            app.Slider62 = uislider(app.GridLayout);
            app.Slider62.Limits = [-12 12];
            app.Slider62.MajorTicks = [-12 -6 0 6 12];
            app.Slider62.Orientation = 'vertical';
            app.Slider62.MinorTicksMode = 'manual';
            app.Slider62.Layout.Row = [3 5];
            app.Slider62.Layout.Column = 2;

            % Create EqualizerSwitch
            app.EqualizerSwitch = uiswitch(app.GridLayout, 'slider');
            app.EqualizerSwitch.Items = {'', ''};
            app.EqualizerSwitch.Layout.Row = [7 8];
            app.EqualizerSwitch.Layout.Column = 6;
            app.EqualizerSwitch.Value = '';

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.GridLayout);
            app.GridLayout2.Layout.Row = [9 14];
            app.GridLayout2.Layout.Column = [1 11];

            % Create OriginalSpectrumAxes
            app.OriginalSpectrumAxes = uiaxes(app.GridLayout2);
            title(app.OriginalSpectrumAxes, '均衡调节前')
            xlabel(app.OriginalSpectrumAxes, '频率/Hz')
            ylabel(app.OriginalSpectrumAxes, '幅度/dB')
            zlabel(app.OriginalSpectrumAxes, 'Z')
            app.OriginalSpectrumAxes.Layout.Row = [1 2];
            app.OriginalSpectrumAxes.Layout.Column = 1;

            % Create ProcessedSpectrumAxes
            app.ProcessedSpectrumAxes = uiaxes(app.GridLayout2);
            title(app.ProcessedSpectrumAxes, '均衡调节后')
            xlabel(app.ProcessedSpectrumAxes, '频率/Hz')
            ylabel(app.ProcessedSpectrumAxes, '幅度/dB')
            zlabel(app.ProcessedSpectrumAxes, 'Z')
            app.ProcessedSpectrumAxes.Layout.Row = [1 2];
            app.ProcessedSpectrumAxes.Layout.Column = 2;

            % Create HzLabel_2
            app.HzLabel_2 = uilabel(app.GridLayout);
            app.HzLabel_2.HorizontalAlignment = 'center';
            app.HzLabel_2.VerticalAlignment = 'bottom';
            app.HzLabel_2.FontSize = 14;
            app.HzLabel_2.Layout.Row = 2;
            app.HzLabel_2.Layout.Column = 3;
            app.HzLabel_2.Text = '125Hz';

            % Create HzLabel_3
            app.HzLabel_3 = uilabel(app.GridLayout);
            app.HzLabel_3.HorizontalAlignment = 'center';
            app.HzLabel_3.VerticalAlignment = 'bottom';
            app.HzLabel_3.FontSize = 14;
            app.HzLabel_3.Layout.Row = 2;
            app.HzLabel_3.Layout.Column = 2;
            app.HzLabel_3.Text = '62Hz';

            % Create HzLabel_4
            app.HzLabel_4 = uilabel(app.GridLayout);
            app.HzLabel_4.HorizontalAlignment = 'center';
            app.HzLabel_4.VerticalAlignment = 'bottom';
            app.HzLabel_4.FontSize = 14;
            app.HzLabel_4.Layout.Row = 2;
            app.HzLabel_4.Layout.Column = 4;
            app.HzLabel_4.Text = '250Hz';

            % Create HzLabel_5
            app.HzLabel_5 = uilabel(app.GridLayout);
            app.HzLabel_5.HorizontalAlignment = 'center';
            app.HzLabel_5.VerticalAlignment = 'bottom';
            app.HzLabel_5.FontSize = 14;
            app.HzLabel_5.Layout.Row = 2;
            app.HzLabel_5.Layout.Column = 5;
            app.HzLabel_5.Text = '500Hz';

            % Create kHzLabel
            app.kHzLabel = uilabel(app.GridLayout);
            app.kHzLabel.HorizontalAlignment = 'center';
            app.kHzLabel.VerticalAlignment = 'bottom';
            app.kHzLabel.FontSize = 14;
            app.kHzLabel.Layout.Row = 2;
            app.kHzLabel.Layout.Column = 6;
            app.kHzLabel.Text = '1kHz';

            % Create kHzLabel_2
            app.kHzLabel_2 = uilabel(app.GridLayout);
            app.kHzLabel_2.HorizontalAlignment = 'center';
            app.kHzLabel_2.VerticalAlignment = 'bottom';
            app.kHzLabel_2.FontSize = 14;
            app.kHzLabel_2.Layout.Row = 2;
            app.kHzLabel_2.Layout.Column = 7;
            app.kHzLabel_2.Text = '2kHz';

            % Create kHzLabel_3
            app.kHzLabel_3 = uilabel(app.GridLayout);
            app.kHzLabel_3.HorizontalAlignment = 'center';
            app.kHzLabel_3.VerticalAlignment = 'bottom';
            app.kHzLabel_3.FontSize = 14;
            app.kHzLabel_3.Layout.Row = 2;
            app.kHzLabel_3.Layout.Column = 8;
            app.kHzLabel_3.Text = '4kHz';

            % Create kHzLabel_4
            app.kHzLabel_4 = uilabel(app.GridLayout);
            app.kHzLabel_4.HorizontalAlignment = 'center';
            app.kHzLabel_4.VerticalAlignment = 'bottom';
            app.kHzLabel_4.FontSize = 14;
            app.kHzLabel_4.Layout.Row = 2;
            app.kHzLabel_4.Layout.Column = 9;
            app.kHzLabel_4.Text = '8kHz';

            % Create kHzLabel_5
            app.kHzLabel_5 = uilabel(app.GridLayout);
            app.kHzLabel_5.HorizontalAlignment = 'center';
            app.kHzLabel_5.VerticalAlignment = 'bottom';
            app.kHzLabel_5.FontSize = 14;
            app.kHzLabel_5.Layout.Row = 2;
            app.kHzLabel_5.Layout.Column = 10;
            app.kHzLabel_5.Text = '16kHz';

            % Create Label_2
            app.Label_2 = uilabel(app.GridLayout);
            app.Label_2.HorizontalAlignment = 'right';
            app.Label_2.FontSize = 13;
            app.Label_2.Layout.Row = 7;
            app.Label_2.Layout.Column = [1 2];
            app.Label_2.Text = '当前歌曲：';

            % Create CurrentSongLabel
            app.CurrentSongLabel = uilabel(app.GridLayout);
            app.CurrentSongLabel.FontSize = 13;
            app.CurrentSongLabel.Layout.Row = 7;
            app.CurrentSongLabel.Layout.Column = [3 4];

            % Create Label_6
            app.Label_6 = uilabel(app.GridLayout);
            app.Label_6.Layout.Row = [7 8];
            app.Label_6.Layout.Column = 7;
            app.Label_6.Text = '打开均衡';

            % Create Slider125
            app.Slider125 = uislider(app.GridLayout);
            app.Slider125.Limits = [-12 12];
            app.Slider125.MajorTicks = [-12 -6 0 6 12];
            app.Slider125.Orientation = 'vertical';
            app.Slider125.MinorTicksMode = 'manual';
            app.Slider125.Layout.Row = [3 5];
            app.Slider125.Layout.Column = 3;

            % Create Slider250
            app.Slider250 = uislider(app.GridLayout);
            app.Slider250.Limits = [-12 12];
            app.Slider250.MajorTicks = [-12 -6 0 6 12];
            app.Slider250.Orientation = 'vertical';
            app.Slider250.MinorTicksMode = 'manual';
            app.Slider250.Layout.Row = [3 5];
            app.Slider250.Layout.Column = 4;

            % Create Slider500
            app.Slider500 = uislider(app.GridLayout);
            app.Slider500.Limits = [-12 12];
            app.Slider500.MajorTicks = [-12 -6 0 6 12];
            app.Slider500.Orientation = 'vertical';
            app.Slider500.MinorTicksMode = 'manual';
            app.Slider500.Layout.Row = [3 5];
            app.Slider500.Layout.Column = 5;

            % Create Slider1k
            app.Slider1k = uislider(app.GridLayout);
            app.Slider1k.Limits = [-12 12];
            app.Slider1k.MajorTicks = [-12 -6 0 6 12];
            app.Slider1k.Orientation = 'vertical';
            app.Slider1k.MinorTicksMode = 'manual';
            app.Slider1k.Layout.Row = [3 5];
            app.Slider1k.Layout.Column = 6;

            % Create Slider2k
            app.Slider2k = uislider(app.GridLayout);
            app.Slider2k.Limits = [-12 12];
            app.Slider2k.MajorTicks = [-12 -6 0 6 12];
            app.Slider2k.Orientation = 'vertical';
            app.Slider2k.MinorTicksMode = 'manual';
            app.Slider2k.Layout.Row = [3 5];
            app.Slider2k.Layout.Column = 7;

            % Create Slider4k
            app.Slider4k = uislider(app.GridLayout);
            app.Slider4k.Limits = [-12 12];
            app.Slider4k.MajorTicks = [-12 -6 0 6 12];
            app.Slider4k.Orientation = 'vertical';
            app.Slider4k.MinorTicksMode = 'manual';
            app.Slider4k.Layout.Row = [3 5];
            app.Slider4k.Layout.Column = 8;

            % Create Slider8k
            app.Slider8k = uislider(app.GridLayout);
            app.Slider8k.Limits = [-12 12];
            app.Slider8k.MajorTicks = [-12 -6 0 6 12];
            app.Slider8k.Orientation = 'vertical';
            app.Slider8k.MinorTicksMode = 'manual';
            app.Slider8k.Layout.Row = [3 5];
            app.Slider8k.Layout.Column = 9;

            % Create Slider16k
            app.Slider16k = uislider(app.GridLayout);
            app.Slider16k.Limits = [-12 12];
            app.Slider16k.MajorTicks = [-12 -6 0 6 12];
            app.Slider16k.Orientation = 'vertical';
            app.Slider16k.MinorTicksMode = 'manual';
            app.Slider16k.Layout.Row = [3 5];
            app.Slider16k.Layout.Column = 10;

            % Create Gain62Label
            app.Gain62Label = uilabel(app.GridLayout);
            app.Gain62Label.HorizontalAlignment = 'center';
            app.Gain62Label.FontSize = 14;
            app.Gain62Label.Layout.Row = 6;
            app.Gain62Label.Layout.Column = 2;
            app.Gain62Label.Text = '0.0dB';

            % Create Gain125Label
            app.Gain125Label = uilabel(app.GridLayout);
            app.Gain125Label.HorizontalAlignment = 'center';
            app.Gain125Label.FontSize = 14;
            app.Gain125Label.Layout.Row = 6;
            app.Gain125Label.Layout.Column = 3;
            app.Gain125Label.Text = '0.0dB';

            % Create Gain250Label
            app.Gain250Label = uilabel(app.GridLayout);
            app.Gain250Label.HorizontalAlignment = 'center';
            app.Gain250Label.FontSize = 14;
            app.Gain250Label.Layout.Row = 6;
            app.Gain250Label.Layout.Column = 4;
            app.Gain250Label.Text = '0.0dB';

            % Create Gain500Label
            app.Gain500Label = uilabel(app.GridLayout);
            app.Gain500Label.HorizontalAlignment = 'center';
            app.Gain500Label.FontSize = 14;
            app.Gain500Label.Layout.Row = 6;
            app.Gain500Label.Layout.Column = 5;
            app.Gain500Label.Text = '0.0dB';

            % Create Gain1kLabel
            app.Gain1kLabel = uilabel(app.GridLayout);
            app.Gain1kLabel.HorizontalAlignment = 'center';
            app.Gain1kLabel.FontSize = 14;
            app.Gain1kLabel.Layout.Row = 6;
            app.Gain1kLabel.Layout.Column = 6;
            app.Gain1kLabel.Text = '0.0dB';

            % Create Gain2kLabel
            app.Gain2kLabel = uilabel(app.GridLayout);
            app.Gain2kLabel.HorizontalAlignment = 'center';
            app.Gain2kLabel.FontSize = 14;
            app.Gain2kLabel.Layout.Row = 6;
            app.Gain2kLabel.Layout.Column = 7;
            app.Gain2kLabel.Text = '0.0dB';

            % Create Gain4kLabel
            app.Gain4kLabel = uilabel(app.GridLayout);
            app.Gain4kLabel.HorizontalAlignment = 'center';
            app.Gain4kLabel.FontSize = 14;
            app.Gain4kLabel.Layout.Row = 6;
            app.Gain4kLabel.Layout.Column = 8;
            app.Gain4kLabel.Text = '0.0dB';

            % Create Gain8kLabel
            app.Gain8kLabel = uilabel(app.GridLayout);
            app.Gain8kLabel.HorizontalAlignment = 'center';
            app.Gain8kLabel.FontSize = 14;
            app.Gain8kLabel.Layout.Row = 6;
            app.Gain8kLabel.Layout.Column = 9;
            app.Gain8kLabel.Text = '0.0dB';

            % Create Gain16kLabel
            app.Gain16kLabel = uilabel(app.GridLayout);
            app.Gain16kLabel.HorizontalAlignment = 'center';
            app.Gain16kLabel.FontSize = 14;
            app.Gain16kLabel.Layout.Row = 6;
            app.Gain16kLabel.Layout.Column = 10;
            app.Gain16kLabel.Text = '0.0dB';

            % Create BackToWorkbenchButton
            app.BackToWorkbenchButton = uibutton(app.GridLayout, 'push');
            app.BackToWorkbenchButton.Layout.Row = 7;
            app.BackToWorkbenchButton.Layout.Column = 10;
            app.BackToWorkbenchButton.Text = '返回工作台';

            % Create Label_7
            app.Label_7 = uilabel(app.GridLayout);
            app.Label_7.HorizontalAlignment = 'right';
            app.Label_7.Layout.Row = [7 8];
            app.Label_7.Layout.Column = 5;
            app.Label_7.Text = '关闭均衡';

            % Create SaveAudioButton
            app.SaveAudioButton = uibutton(app.GridLayout, 'push');
            app.SaveAudioButton.Layout.Row = 7;
            app.SaveAudioButton.Layout.Column = 9;
            app.SaveAudioButton.Text = '保存音频';

            % Create PlayOriginalButton
            app.PlayOriginalButton = uibutton(app.GridLayout, 'push');
            app.PlayOriginalButton.Layout.Row = 8;
            app.PlayOriginalButton.Layout.Column = 2;
            app.PlayOriginalButton.Text = '播放原声';

            % Create PlayEqualizedButton
            app.PlayEqualizedButton = uibutton(app.GridLayout, 'push');
            app.PlayEqualizedButton.Layout.Row = 8;
            app.PlayEqualizedButton.Layout.Column = 9;
            app.PlayEqualizedButton.Text = '播放均衡';

            % Create StopPlaybackButton
            app.StopPlaybackButton = uibutton(app.GridLayout, 'push');
            app.StopPlaybackButton.Layout.Row = 8;
            app.StopPlaybackButton.Layout.Column = 10;
            app.StopPlaybackButton.Text = '暂停播放';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = GraphicEqualizer

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

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