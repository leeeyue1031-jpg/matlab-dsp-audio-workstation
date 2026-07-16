classdef MusicPlayer < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure               matlab.ui.Figure
        GridLayout             matlab.ui.container.GridLayout
        PlaylistPanel          matlab.ui.container.Panel
        PlaylistGrid           matlab.ui.container.GridLayout
        PlaylistListBox        matlab.ui.control.ListBox
        PlaylistListBoxLabel   matlab.ui.control.Label
        ClearPlaylistButton    matlab.ui.control.Button
        DeleteMusicButton      matlab.ui.control.Button
        OpenMusicButton        matlab.ui.control.Button
        CurrentSongPanel       matlab.ui.container.Panel
        GridLayout3            matlab.ui.container.GridLayout
        DurationLabel          matlab.ui.control.Label
        SongNameLabel          matlab.ui.control.Label
        DurationTitleLabel     matlab.ui.control.Label
        SongNameTitleLabel     matlab.ui.control.Label
        GridLayout5            matlab.ui.container.GridLayout
        CurrentTimeLabel       matlab.ui.control.Label
        TotalTimeLabel         matlab.ui.control.Label
        ProgressSlider         matlab.ui.control.Slider
        SaveAudioButton        matlab.ui.control.Button
        PauseButton            matlab.ui.control.Button
        PlayButton             matlab.ui.control.Button
        NextButton             matlab.ui.control.Button
        PreviousButton         matlab.ui.control.Button
        SpectrumAxes           matlab.ui.control.UIAxes
        WaveformAxes           matlab.ui.control.UIAxes
        PlaybackSettingsPanel  matlab.ui.container.Panel
        GridLayout4            matlab.ui.container.GridLayout
        DSPLabel               matlab.ui.control.Label
        VocalProcessDropDown   matlab.ui.control.DropDown
        Label_10               matlab.ui.control.Label
        VolumeSlider           matlab.ui.control.Slider
        Label_4                matlab.ui.control.Label
        PlaybackSpeedDropDown  matlab.ui.control.DropDown
        Label_8                matlab.ui.control.Label
        PlayModeDropDown       matlab.ui.control.DropDown
        Label_9                matlab.ui.control.Label
        ChannelModeDropDown    matlab.ui.control.DropDown
        Label_5                matlab.ui.control.Label
        ReverbButton           matlab.ui.control.Button
        EqualizerButton        matlab.ui.control.Button
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
        twoPanelWidth = 768;
    end

    properties (Access = private)
        PlaylistData = struct('Name', {}, 'Type', {}, 'Audio', {}, 'Fs', {}, 'FilePath', {})
        CurrentAudio = []
        CurrentFs = []
        CurrentIndex = 0
        Player = []
        ProcessedAudio = []
        ProcessedFs = []
        ProgressTimer = []
        FigureDeleteListener = []
        IsSliderDragging = false
        IsUserStopping = false
        IsChangingSong = false
        IsClosing = false
        WasPlayingBeforeSeek = false
        PausedSample = 1
        PendingSeekSample = 1
        PlaybackStartSample = 1
        LastSpectrumUpdateClock = []
        DigitalReverbApp = []
        GraphicEqualizerApp = []
    end
    methods (Access = private)
        function loadDefaultSongs(app)
            appFolder = fileparts(mfilename('fullpath'));
            files = {fullfile(appFolder, '鸟之诗-小提琴版.wav'), ...
                     fullfile(appFolder, '鸟之诗-基础版.wav')};
            app.PlaylistData = struct('Name', {}, 'Type', {}, ...
                'Audio', {}, 'Fs', {}, 'FilePath', {});
            for k = 1:numel(files)
                if ~isfile(files{k})
                    continue;
                end
                [audio, fs] = audioread(files{k});
                if size(audio, 2) > 2
                    audio = mean(audio, 2);
                end
                [~, name, ext] = fileparts(files{k});
                song = struct('Name', name, 'Type', upper(erase(ext, '.')), ...
                    'Audio', audio, 'Fs', fs, 'FilePath', files{k});
                app.PlaylistData(end + 1) = song;
            end
            refreshPlaylist(app);
        end
        function refreshPlaylist(app)
            if isempty(app.PlaylistData)
                app.PlaylistListBox.Items = {};
                app.PlaylistListBox.Value = {};
                return;
            end
            names = {app.PlaylistData.Name};
            app.PlaylistListBox.Items = names;
            if app.CurrentIndex >= 1 && app.CurrentIndex <= numel(names)
                app.PlaylistListBox.Value = names{app.CurrentIndex};
            else
                app.PlaylistListBox.Value = names{1};
            end
        end
        function selectSong(app, newIndex, shouldPlay)
            if nargin < 3
                shouldPlay = false;
            end
            if isempty(app.PlaylistData)
                clearCurrentSong(app);
                return;
            end
            newIndex = max(1, min(round(newIndex), numel(app.PlaylistData)));
            app.IsChangingSong = true;
            cleanupFlag = onCleanup(@()setChangingSongFalse(app));
            equalizerApp = app.GraphicEqualizerApp;
            app.GraphicEqualizerApp = [];
            if ~isempty(equalizerApp)
                try
                    if isvalid(equalizerApp) && isprop(equalizerApp, 'UIFigure') && ...
                            ~isempty(equalizerApp.UIFigure) && isvalid(equalizerApp.UIFigure)
                        close(equalizerApp.UIFigure);
                    elseif isvalid(equalizerApp)
                        delete(equalizerApp);
                    end
                catch
                end
            end
            stopCurrentPlayer(app, false);
            app.CurrentIndex = newIndex;
            app.CurrentAudio = app.PlaylistData(newIndex).Audio;
            app.CurrentFs = app.PlaylistData(newIndex).Fs;
            app.PausedSample = 1;
            app.PendingSeekSample = 1;
            app.PlaybackStartSample = 1;
            refreshPlaylist(app);
            updateSongInfo(app);
            buildProcessedAudio(app);
            resetProgress(app);
            updateDynamicWaveform(app, 0);
            updateDynamicSpectrum(app, 0);
            if shouldPlay
                playCurrentSong(app, 1);
            end
            clear cleanupFlag;
        end
        function setChangingSongFalse(app)
            app.IsChangingSong = false;
        end
        function updateSongInfo(app)
            if isempty(app.PlaylistData) || app.CurrentIndex < 1 || ...
                    app.CurrentIndex > numel(app.PlaylistData)
                app.SongNameLabel.Text = '无';
                app.DurationLabel.Text = '00:00';
                app.TotalTimeLabel.Text = '00:00';
                return;
            end
            song = app.PlaylistData(app.CurrentIndex);
            app.SongNameLabel.Text = song.Name;
            durationText = formatTime(app, size(song.Audio, 1) / song.Fs);
            app.DurationLabel.Text = durationText;
            app.TotalTimeLabel.Text = durationText;
        end
        function text = formatTime(~, seconds)
            if isempty(seconds) || ~isfinite(seconds) || seconds < 0
                seconds = 0;
            end
            totalSeconds = floor(seconds);
            text = sprintf('%02d:%02d', floor(totalSeconds / 60), mod(totalSeconds, 60));
        end
        function buildProcessedAudio(app)
            if isempty(app.CurrentAudio) || isempty(app.CurrentFs)
                app.ProcessedAudio = [];
                app.ProcessedFs = [];
                return;
            end
            audio = double(app.CurrentAudio);
            if size(audio, 2) > 2
                audio = mean(audio, 2);
            end
            if app.VocalProcessDropDown.ValueIndex == 2 && size(audio, 2) >= 2
                audio = audio(:, 1) - audio(:, 2);
            end
            switch app.ChannelModeDropDown.ValueIndex
                case 2
                    selectedChannel = audio(:, 1);
                    audio = [selectedChannel, zeros(size(selectedChannel))];
                case 3
                    if size(audio, 2) >= 2
                        selectedChannel = audio(:, 2);
                    else
                        selectedChannel = audio(:, 1);
                    end
                    audio = [zeros(size(selectedChannel)), selectedChannel];
                case 4
                    if size(audio, 2) >= 2
                        audio = mean(audio, 2);
                    end
            end
            audio = audio * (app.VolumeSlider.Value / 100);
            app.ProcessedAudio = max(-1, min(1, audio));
            app.ProcessedFs = app.CurrentFs;
        end
        function factor = getSpeedFactor(app)
            speedText = char(app.PlaybackSpeedDropDown.Value);
            factor = sscanf(speedText, '%f', 1);
            if isempty(factor) || ~isfinite(factor) || factor <= 0
                factor = 1;
            end
        end
        function playCurrentSong(app, startSample)
            if isempty(app.CurrentAudio) || isempty(app.CurrentFs)
                return;
            end
            if isempty(app.ProcessedAudio)
                buildProcessedAudio(app);
            end
            totalSamples = size(app.ProcessedAudio, 1);
            startSample = max(1, min(round(startSample), totalSamples));
            stopCurrentPlayer(app, false);
            app.PlaybackStartSample = startSample;
            app.PausedSample = startSample;
            app.PendingSeekSample = startSample;
            playbackFs = max(1, round(app.CurrentFs * getSpeedFactor(app)));
            app.Player = audioplayer(app.ProcessedAudio(startSample:end, :), playbackFs);
            play(app.Player);
            createProgressTimer(app);
            startProgressTimer(app);
            updatePlaybackDisplay(app, true);
        end
        function applyPlaybackSettings(app)
            if isempty(app.CurrentAudio)
                return;
            end
            currentSample = getAbsoluteCurrentSample(app);
            wasPlaying = isPlayerPlaying(app);
            wasPaused = ~wasPlaying && ~isempty(app.Player) && ...
                isvalid(app.Player) && currentSample > 1;
            stopCurrentPlayer(app, false);
            buildProcessedAudio(app);
            app.PausedSample = currentSample;
            app.PendingSeekSample = currentSample;
            if wasPlaying
                playCurrentSong(app, currentSample);
            elseif wasPaused
                updatePlaybackDisplay(app, true);
            else
                updateDynamicWaveform(app, sampleToTime(app, currentSample));
                updateDynamicSpectrum(app, sampleToTime(app, currentSample));
            end
        end
        function restartPlaybackAtCurrentPosition(app)
            applyPlaybackSettings(app);
        end
        function stopCurrentPlayer(app, isUserAction)
            if nargin < 2
                isUserAction = false;
            end
            app.IsUserStopping = logical(isUserAction);
            stopProgressTimer(app);
            if ~isempty(app.Player)
                try
                    if isvalid(app.Player)
                        stop(app.Player);
                        delete(app.Player);
                    end
                catch ME
                    if ~app.IsClosing
                        warning('MusicPlayer:PlayerCleanup', '%s', ME.message);
                    end
                end
            end
            app.Player = [];
            app.IsUserStopping = false;
        end
        function resetProgress(app)
            duration = getCurrentDuration(app);
            if duration > 0
                app.ProgressSlider.Limits = [0, duration];
            else
                app.ProgressSlider.Limits = [0, 1];
            end
            app.ProgressSlider.Value = 0;
            app.CurrentTimeLabel.Text = '00:00';
            app.PausedSample = 1;
            app.PendingSeekSample = 1;
        end
        function createProgressTimer(app)
            if ~isempty(app.ProgressTimer)
                try
                    if isvalid(app.ProgressTimer)
                        return;
                    end
                catch
                end
            end
            app.ProgressTimer = timer('Name', 'MusicPlayerProgressTimer', ...
                'ExecutionMode', 'fixedSpacing', 'Period', 0.1, ...
                'BusyMode', 'drop', ...
                'TimerFcn', @(~, ~)updatePlaybackDisplay(app, false));
        end
        function startProgressTimer(app)
            createProgressTimer(app);
            if strcmp(app.ProgressTimer.Running, 'off')
                start(app.ProgressTimer);
            end
        end
        function stopProgressTimer(app)
            if isempty(app.ProgressTimer)
                return;
            end
            try
                if isvalid(app.ProgressTimer) && strcmp(app.ProgressTimer.Running, 'on')
                    stop(app.ProgressTimer);
                end
            catch ME
                if ~app.IsClosing
                    warning('MusicPlayer:TimerStop', '%s', ME.message);
                end
            end
        end
        function updatePlaybackDisplay(app, forceSpectrum)
            if nargin < 2
                forceSpectrum = false;
            end

            if app.IsClosing || isempty(app.CurrentAudio) || ...
                    isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end

            % 先单独读取播放器状态。
            playerExists = false;
            playerIsPlaying = false;
            playerCurrentSample = 1;

            if ~isempty(app.Player)
                try
                    if isvalid(app.Player)
                        playerExists = true;
                        playerIsPlaying = isplaying(app.Player);
                        playerCurrentSample = app.Player.CurrentSample;
                    end
                catch
                    playerExists = false;
                end
            end

            currentSample = getAbsoluteCurrentSample(app);

            % 播放过程中，持续保存最后一次可靠的绝对采样位置。
            if playerExists && playerIsPlaying
                app.PausedSample = currentSample;
                app.PendingSeekSample = currentSample;
            end

            % audioplayer 自然播放结束后，CurrentSample 可能回到 1。
            % 因此不能再使用 currentSample >= 总采样数判断结束，
            % 而是检查播放期间保存的最后可靠位置。
            if playerExists && ~playerIsPlaying && playerCurrentSample <= 1 && ...
                    ~app.IsUserStopping && ~app.IsChangingSong && ~app.IsClosing

                totalSamples = size(app.CurrentAudio, 1);

                % 定时器每 0.1 秒更新一次，需要允许一定采样误差。
                % 倍速越高，两次定时器更新之间跨越的原始采样点越多。
                toleranceSamples = ceil(0.5 * app.CurrentFs * getSpeedFactor(app));
                toleranceSamples = max(1, toleranceSamples);

                if app.PausedSample >= totalSamples - toleranceSamples
                    handlePlaybackFinished(app);
                    return;
                end
            end

            currentTime = sampleToTime(app, currentSample);
            duration = getCurrentDuration(app);
            currentTime = max(0, min(currentTime, duration));

            if ~app.IsSliderDragging
                app.CurrentTimeLabel.Text = formatTime(app, currentTime);
                app.ProgressSlider.Value = ...
                    max(app.ProgressSlider.Limits(1), ...
                    min(currentTime, app.ProgressSlider.Limits(2)));
            end

            updateDynamicWaveform(app, currentTime);

            if forceSpectrum || isempty(app.LastSpectrumUpdateClock) || ...
                    toc(app.LastSpectrumUpdateClock) >= 0.2
                updateDynamicSpectrum(app, currentTime);
                app.LastSpectrumUpdateClock = tic;
            end
        end
        function updateDynamicWaveform(app, currentTime)
            if isempty(app.ProcessedAudio) || isempty(app.CurrentFs)
                cla(app.WaveformAxes);
                return;
            end
            windowDuration = 10;
            totalDuration = size(app.ProcessedAudio, 1) / app.CurrentFs;
            startTime = max(0, currentTime - windowDuration / 2);
            endTime = startTime + windowDuration;
            if endTime > totalDuration
                endTime = totalDuration;
                startTime = max(0, endTime - windowDuration);
            end
            firstSample = max(1, floor(startTime * app.CurrentFs) + 1);
            lastSample = min(size(app.ProcessedAudio, 1), ceil(endTime * app.CurrentFs));
            segment = app.ProcessedAudio(firstSample:lastSample, :);
            if size(segment, 2) > 1
                segment = mean(segment, 2);
            end
            sampleNumbers = (firstSample:lastSample)';
            stride = max(1, ceil(numel(sampleNumbers) / 4000));
            sampleNumbers = sampleNumbers(1:stride:end);
            segment = segment(1:stride:end);
            times = (sampleNumbers - 1) / app.CurrentFs;
            cla(app.WaveformAxes);
            plot(app.WaveformAxes, times, segment, 'Color', [0.12 0.40 0.72]);
            hold(app.WaveformAxes, 'on');
            xline(app.WaveformAxes, currentTime, 'r-', 'LineWidth', 1.2);
            hold(app.WaveformAxes, 'off');
            xlim(app.WaveformAxes, [startTime, max(endTime, startTime + 0.01)]);
            ylim(app.WaveformAxes, [-1, 1]);
            grid(app.WaveformAxes, 'on');
            title(app.WaveformAxes, '当前播放波形');
            xlabel(app.WaveformAxes, '时间 / s');
            ylabel(app.WaveformAxes, '幅值');
        end
        function updateDynamicSpectrum(app, currentTime)
            if isempty(app.ProcessedAudio) || isempty(app.CurrentFs)
                cla(app.SpectrumAxes);
                return;
            end
            windowDuration = 0.5;
            endTime = min(getCurrentDuration(app), max(currentTime, windowDuration));
            startTime = max(0, endTime - windowDuration);
            firstSample = max(1, floor(startTime * app.CurrentFs) + 1);
            lastSample = min(size(app.ProcessedAudio, 1), max(firstSample, ceil(endTime * app.CurrentFs)));
            segment = app.ProcessedAudio(firstSample:lastSample, :);
            if size(segment, 2) > 1
                segment = mean(segment, 2);
            end
            segment = segment - mean(segment);
            N = length(segment);
            if N > 1
                window = 0.5 - 0.5 * cos(2 * pi * (0:N-1)' / (N-1));
            else
                window = ones(N, 1);
            end
            nfft = max(2048, 2 ^ nextpow2(max(N, 1)));
            values = fft(segment .* window, nfft);
            halfLength = floor(nfft / 2) + 1;
            magnitude = abs(values(1:halfLength));
            if any(magnitude > 0)
                magnitude = magnitude / max(magnitude);
            end
            frequency = (0:halfLength-1)' * app.CurrentFs / nfft;
            maxFrequency = min(8000, app.CurrentFs / 2);
            keep = frequency <= maxFrequency;
            cla(app.SpectrumAxes);
            plot(app.SpectrumAxes, frequency(keep), magnitude(keep), ...
                'Color', [0.08 0.55 0.38]);
            xlim(app.SpectrumAxes, [0, maxFrequency]);
            ylim(app.SpectrumAxes, [0, 1.05]);
            grid(app.SpectrumAxes, 'on');
            title(app.SpectrumAxes, '当前播放频谱');
            xlabel(app.SpectrumAxes, '频率 / Hz');
            ylabel(app.SpectrumAxes, '归一化幅值');
        end
        function handlePlaybackFinished(app)
            % App 正在关闭时，不再执行自动切歌或重新播放。
            if app.IsClosing
                return;
            end

            % 播放已经自然结束，先停止进度定时器并释放旧播放器。
            stopCurrentPlayer(app, false);

            % 播放列表为空，或者当前歌曲索引无效时，直接退出。
            songCount = numel(app.PlaylistData);
            if songCount == 0 || app.CurrentIndex < 1 || ...
                    app.CurrentIndex > songCount
                return;
            end

            currentIndex = app.CurrentIndex;
            playMode = char(app.PlayModeDropDown.Value);

            switch playMode
                case '顺序播放'
                    if currentIndex < songCount
                        % 不是最后一首：正常进入下一首。
                        selectSong(app, currentIndex + 1, true);
                    else
                        % 最后一首播放结束：停留在最后一首，
                        % 同时把播放位置恢复到开头，便于再次按播放键。
                        resetProgress(app);
                        updateDynamicWaveform(app, 0);
                        updateDynamicSpectrum(app, 0);
                    end

                case '列表循环'
                    % 最后一首之后返回第一首，其余情况进入下一首。
                    nextIndex = mod(currentIndex, songCount) + 1;
                    selectSong(app, nextIndex, true);

                case '单曲循环'
                    % 重新选择当前歌曲，并从第一采样点开始播放。
                    selectSong(app, currentIndex, true);

                case '随机播放'
                    if songCount == 1
                        % 播放列表只有一首歌时，只能重新播放当前歌曲。
                        nextIndex = 1;
                    else
                        % 排除当前歌曲，避免“随机”后仍然播放同一首。
                        candidateIndices = [1:(currentIndex - 1), ...
                            (currentIndex + 1):songCount];
                        randomPosition = randi(numel(candidateIndices));
                        nextIndex = candidateIndices(randomPosition);
                    end
                    selectSong(app, nextIndex, true);

                otherwise
                    % 下拉框值异常时采用列表循环，防止播放器停在未知状态。
                    nextIndex = mod(currentIndex, songCount) + 1;
                    selectSong(app, nextIndex, true);
            end
        end
        function sample = getAbsoluteCurrentSample(app)
            sample = max(1, app.PausedSample);
            if ~isempty(app.Player)
                try
                    if isvalid(app.Player)
                        sample = app.PlaybackStartSample + app.Player.CurrentSample - 1;
                    end
                catch
                end
            elseif app.PendingSeekSample > 1
                sample = app.PendingSeekSample;
            end
            if ~isempty(app.CurrentAudio)
                sample = min(sample, size(app.CurrentAudio, 1));
            end
        end
        function value = sampleToTime(app, sample)
            if isempty(app.CurrentFs) || app.CurrentFs <= 0
                value = 0;
            else
                value = (max(1, sample) - 1) / app.CurrentFs;
            end
        end
        function duration = getCurrentDuration(app)
            if isempty(app.CurrentAudio) || isempty(app.CurrentFs) || app.CurrentFs <= 0
                duration = 0;
            else
                duration = size(app.CurrentAudio, 1) / app.CurrentFs;
            end
        end
        function tf = isPlayerPlaying(app)
            tf = false;
            if ~isempty(app.Player)
                try
                    tf = isvalid(app.Player) && isplaying(app.Player);
                catch
                end
            end
        end
        function seekToTime(app, targetTime, shouldPlay)
            if isempty(app.CurrentAudio)
                return;
            end
            targetTime = max(0, min(targetTime, getCurrentDuration(app)));
            targetSample = min(size(app.CurrentAudio, 1), ...
                max(1, round(targetTime * app.CurrentFs) + 1));
            stopCurrentPlayer(app, false);
            app.PausedSample = targetSample;
            app.PendingSeekSample = targetSample;
            app.PlaybackStartSample = targetSample;
            app.CurrentTimeLabel.Text = formatTime(app, targetTime);
            app.ProgressSlider.Value = targetTime;
            updateDynamicWaveform(app, targetTime);
            updateDynamicSpectrum(app, targetTime);
            if shouldPlay && targetSample < size(app.CurrentAudio, 1)
                playCurrentSong(app, targetSample);
            end
        end
        function clearCurrentSong(app)
            stopCurrentPlayer(app, false);
            app.CurrentIndex = 0;
            app.CurrentAudio = [];
            app.CurrentFs = [];
            app.ProcessedAudio = [];
            app.ProcessedFs = [];
            app.SongNameLabel.Text = '无';
            app.DurationLabel.Text = '00:00';
            app.TotalTimeLabel.Text = '00:00';
            resetProgress(app);
            cla(app.WaveformAxes);
            cla(app.SpectrumAxes);
        end
        function cleanupApp(app)
            app.IsClosing = true;
            childApp = app.DigitalReverbApp;
            app.DigitalReverbApp = [];
            if ~isempty(childApp)
                try
                    if isvalid(childApp) && isprop(childApp, 'UIFigure') && ...
                            ~isempty(childApp.UIFigure) && isvalid(childApp.UIFigure)
                        close(childApp.UIFigure);
                    elseif isvalid(childApp)
                        delete(childApp);
                    end
                catch
                end
            end
            stopCurrentPlayer(app, false);
            if ~isempty(app.ProgressTimer)
                try
                    if isvalid(app.ProgressTimer)
                        delete(app.ProgressTimer);
                    end
                catch
                end
            end
            app.ProgressTimer = [];
        end
    end
    methods (Access = public)
        function digitalReverbClosed(app, reverbApp)
            if isempty(app.DigitalReverbApp)
                return;
            end
            try
                if ~isvalid(app.DigitalReverbApp) || isequal(app.DigitalReverbApp, reverbApp)
                    app.DigitalReverbApp = [];
                end
            catch
                app.DigitalReverbApp = [];
            end
        end
        function graphicEqualizerClosed(app, equalizerApp)
            if isempty(app.GraphicEqualizerApp)
                return;
            end
            try
                if ~isvalid(app.GraphicEqualizerApp) || isequal(app.GraphicEqualizerApp, equalizerApp)
                    app.GraphicEqualizerApp = [];
                end
            catch
                app.GraphicEqualizerApp = [];
            end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.FigureDeleteListener = addlistener(app.UIFigure, 'ObjectBeingDestroyed', @(~, ~)cleanupApp(app));
            app.ChannelModeDropDown.Items = {'立体声', '左声道', '右声道', '单声道'};
            app.ChannelModeDropDown.ValueIndex = 1;
            app.PlaybackSpeedDropDown.Items = {'0.5x', '0.75x', '1.0x', '1.25x', '1.5x', '2.0x'};
            app.PlaybackSpeedDropDown.Value = '1.0x';
            app.VocalProcessDropDown.Items = {'关闭', '人声消除 (L-R)'};
            app.VocalProcessDropDown.ValueIndex = 1;
            loadDefaultSongs(app);
            if ~isempty(app.PlaylistData)
                selectSong(app, 1, false);
            else
                clearCurrentSong(app);
            end
        end

        % Button pushed function: OpenMusicButton
        function OpenMusicButtonPushed(app, event)
            [fileName, pathName] = uigetfile( ...
                {'*.wav;*.mp3;*.flac;*.m4a;*.ogg;*.aac;*.aif;*.aiff', '音频文件'; '*.*', '所有文件'}, ...
                '选择音频文件');
            if isequal(fileName, 0)
                return;
            end
            fullPath = fullfile(pathName, fileName);
            if ~isempty(app.PlaylistData) && any(strcmpi({app.PlaylistData.FilePath}, fullPath))
                uialert(app.UIFigure, '该音频已在播放列表中。', '重复导入', 'Icon', 'info');
                return;
            end
            try
                [audio, fs] = audioread(fullPath);
                if size(audio, 2) > 2
                    audio = mean(audio, 2);
                end
            catch ME
                uialert(app.UIFigure, ME.message, '音频读取失败', 'Icon', 'error');
                return;
            end
            [~, name, ext] = fileparts(fullPath);
            song = struct('Name', name, 'Type', upper(erase(ext, '.')), ...
                'Audio', audio, 'Fs', fs, 'FilePath', fullPath);
            app.PlaylistData(end + 1) = song;
            selectSong(app, numel(app.PlaylistData), false);
        end

        % Value changed function: PlaylistListBox
        function PlaylistListBoxValueChanged(app, event)
            if isempty(app.PlaylistData) || isempty(app.PlaylistListBox.Value)
                return;
            end
            index = find(strcmp({app.PlaylistData.Name}, app.PlaylistListBox.Value), 1);
            if ~isempty(index) && index ~= app.CurrentIndex
                selectSong(app, index, isPlayerPlaying(app));
            end
        end

        % Button pushed function: PreviousButton
        function PreviousButtonPushed(app, event)
            if isempty(app.PlaylistData)
                return;
            end
            index = app.CurrentIndex - 1;
            if index < 1
                index = numel(app.PlaylistData);
            end
            selectSong(app, index, true);
        end

        % Button pushed function: NextButton
        function NextButtonPushed(app, event)
            if isempty(app.PlaylistData)
                return;
            end
            index = mod(app.CurrentIndex, numel(app.PlaylistData)) + 1;
            selectSong(app, index, true);
        end

        % Button pushed function: PlayButton
        function PlayButtonPushed(app, event)
            if isempty(app.CurrentAudio)
                return;
            end
            if isPlayerPlaying(app)
                return;
            end
            if ~isempty(app.Player) && isvalid(app.Player) && ...
                    app.Player.CurrentSample > 1 && app.Player.CurrentSample < app.Player.TotalSamples
                resume(app.Player);
                startProgressTimer(app);
                return;
            end
            playCurrentSong(app, getAbsoluteCurrentSample(app));
        end

        % Button pushed function: PauseButton
        function PauseButtonPushed(app, event)
            if isPlayerPlaying(app)
                app.PausedSample = getAbsoluteCurrentSample(app);
                app.PendingSeekSample = app.PausedSample;
                pause(app.Player);
                stopProgressTimer(app);
                updatePlaybackDisplay(app, true);
            end
        end

        % Button pushed function: DeleteMusicButton
        function DeleteMusicButtonPushed(app, event)
            if isempty(app.PlaylistData) || app.CurrentIndex < 1
                return;
            end
            oldIndex = app.CurrentIndex;
            wasPlaying = isPlayerPlaying(app);
            stopCurrentPlayer(app, false);
            app.PlaylistData(oldIndex) = [];
            if isempty(app.PlaylistData)
                refreshPlaylist(app);
                clearCurrentSong(app);
            else
                selectSong(app, min(oldIndex, numel(app.PlaylistData)), wasPlaying);
            end
        end

        % Button pushed function: ClearPlaylistButton
        function ClearPlaylistButtonPushed(app, event)
            stopCurrentPlayer(app, false);
            app.PlaylistData = struct('Name', {}, 'Type', {}, 'Audio', {}, 'Fs', {}, 'FilePath', {});
            refreshPlaylist(app);
            clearCurrentSong(app);
        end

        % Button pushed function: SaveAudioButton
        function SaveAudioButtonPushed(app, event)
            if isempty(app.ProcessedAudio)
                uialert(app.UIFigure, '当前没有可保存的音频。', '无法保存', 'Icon', 'warning');
                return;
            end
            [fileName, pathName] = uiputfile('*.wav', '保存处理后的音频');
            if isequal(fileName, 0)
                return;
            end
            audiowrite(fullfile(pathName, fileName), app.ProcessedAudio, app.CurrentFs);
        end

        % Value changed function: VolumeSlider
        function VolumeSliderValueChanged(app, event)
            applyPlaybackSettings(app);
        end

        % Value changed function: PlaybackSpeedDropDown
        function PlaybackSpeedDropDownValueChanged(app, event)
            applyPlaybackSettings(app);
        end

        % Value changed function: ChannelModeDropDown
        function ChannelModeDropDownValueChanged(app, event)
            applyPlaybackSettings(app);
        end

        % Value changed function: VocalProcessDropDown
        function VocalProcessDropDownValueChanged(app, event)
            if app.VocalProcessDropDown.ValueIndex == 2 && size(app.CurrentAudio, 2) < 2
                uialert(app.UIFigure, '当前音频是单声道，无法执行 L-R 人声消除。', ...
                    '人声处理', 'Icon', 'info');
            end
            applyPlaybackSettings(app);
        end

        % Value changing function: ProgressSlider
        function ProgressSliderValueChanging(app, event)
            if isempty(app.CurrentAudio)
                return;
            end
            if ~app.IsSliderDragging
                app.WasPlayingBeforeSeek = isPlayerPlaying(app);
            end
            app.IsSliderDragging = true;
            targetTime = max(0, min(event.Value, getCurrentDuration(app)));
            app.PendingSeekSample = min(size(app.CurrentAudio, 1), ...
                max(1, round(targetTime * app.CurrentFs) + 1));
            app.CurrentTimeLabel.Text = formatTime(app, targetTime);
            updateDynamicWaveform(app, targetTime);
            updateDynamicSpectrum(app, targetTime);
        end

        % Value changed function: ProgressSlider
        function ProgressSliderValueChanged(app, event)
            if isempty(app.CurrentAudio)
                return;
            end
            shouldPlay = app.WasPlayingBeforeSeek || isPlayerPlaying(app);
            app.IsSliderDragging = false;
            seekToTime(app, app.ProgressSlider.Value, shouldPlay);
            app.WasPlayingBeforeSeek = false;
        end

        % Button pushed function: EqualizerButton
        function EqualizerButtonPushed(app, event)
            if isempty(app.CurrentAudio) || isempty(app.CurrentFs)
                uialert(app.UIFigure, '请先载入或选择一首歌曲。', ...
                    '无法打开图示均衡器', 'Icon', 'warning');
                return;
            end
            childApp = app.GraphicEqualizerApp;
            try
                if isempty(childApp) || ~isvalid(childApp)
                    childApp = GraphicEqualizer;
                    childApp.setMainApp(app);
                    app.GraphicEqualizerApp = childApp;
                end
                songName = '当前音频';
                sourcePath = '';
                if app.CurrentIndex >= 1 && app.CurrentIndex <= numel(app.PlaylistData)
                    songName = app.PlaylistData(app.CurrentIndex).Name;
                    sourcePath = app.PlaylistData(app.CurrentIndex).FilePath;
                end
                childApp.loadAudioFromMainApp(app.CurrentAudio, app.CurrentFs, ...
                    songName, app, sourcePath);
                childApp.show();
                app.UIFigure.Visible = 'off';
            catch ME
                try
                    if ~isempty(childApp) && isvalid(childApp)
                        close(childApp.UIFigure);
                    end
                catch
                end
                app.GraphicEqualizerApp = [];
                uialert(app.UIFigure, ME.message, '图示均衡器启动失败', 'Icon', 'error');
            end
        end

        % Button pushed function: ReverbButton
        function ReverbButtonPushed(app, event)
            if isempty(app.CurrentAudio) || isempty(app.CurrentFs)
                uialert(app.UIFigure, '请先载入或选择一首歌曲。', ...
                    '无法打开数字混响器', 'Icon', 'warning');
                return;
            end

            childApp = app.DigitalReverbApp;
            try
                if isempty(childApp) || ~isvalid(childApp)
                    childApp = DigitalReverb;
                    childApp.setMainApp(app);
                    app.DigitalReverbApp = childApp;
                end

                songName = '当前音频';
                if app.CurrentIndex >= 1 && app.CurrentIndex <= numel(app.PlaylistData)
                    songName = app.PlaylistData(app.CurrentIndex).Name;
                end
                childApp.loadAudioFromMainApp(app.CurrentAudio, app.CurrentFs, songName, app);
                childApp.show();
            catch ME
                try
                    if ~isempty(childApp) && isvalid(childApp)
                        close(childApp.UIFigure);
                    end
                catch
                end
                app.DigitalReverbApp = [];
                uialert(app.UIFigure, ME.message, '数字混响器启动失败', 'Icon', 'error');
            end
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            cleanupApp(app);
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.UIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 3x1 grid
                app.GridLayout.RowHeight = {675, 675, 675};
                app.GridLayout.ColumnWidth = {'1x'};
                app.CurrentSongPanel.Layout.Row = 1;
                app.CurrentSongPanel.Layout.Column = 1;
                app.PlaylistPanel.Layout.Row = 2;
                app.PlaylistPanel.Layout.Column = 1;
                app.PlaybackSettingsPanel.Layout.Row = 3;
                app.PlaybackSettingsPanel.Layout.Column = 1;
            elseif (currentFigureWidth > app.onePanelWidth && currentFigureWidth <= app.twoPanelWidth)
                % Change to a 2x2 grid
                app.GridLayout.RowHeight = {675, 675};
                app.GridLayout.ColumnWidth = {'1x', '1x'};
                app.CurrentSongPanel.Layout.Row = 1;
                app.CurrentSongPanel.Layout.Column = [1,2];
                app.PlaylistPanel.Layout.Row = 2;
                app.PlaylistPanel.Layout.Column = 1;
                app.PlaybackSettingsPanel.Layout.Row = 2;
                app.PlaybackSettingsPanel.Layout.Column = 2;
            else
                % Change to a 1x3 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {171, '1x', 258};
                app.PlaylistPanel.Layout.Row = 1;
                app.PlaylistPanel.Layout.Column = 1;
                app.CurrentSongPanel.Layout.Row = 1;
                app.CurrentSongPanel.Layout.Column = 2;
                app.PlaybackSettingsPanel.Layout.Row = 1;
                app.PlaybackSettingsPanel.Layout.Column = 3;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Color = [0.7294 0.749 0.9098];
            colormap(app.UIFigure, 'sky');
            app.UIFigure.Position = [100 100 1050 675];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Theme = 'light';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);
            app.UIFigure.Pointer = 'botr';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {171, '1x', 258};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create PlaylistPanel
            app.PlaylistPanel = uipanel(app.GridLayout);
            app.PlaylistPanel.BackgroundColor = [0.6784 0.7804 0.8588];
            app.PlaylistPanel.Layout.Row = 1;
            app.PlaylistPanel.Layout.Column = 1;

            % Create PlaylistGrid
            app.PlaylistGrid = uigridlayout(app.PlaylistPanel);
            app.PlaylistGrid.ColumnWidth = {'5x'};
            app.PlaylistGrid.RowHeight = {48, '1x', '5x', 48, 48, 48};
            app.PlaylistGrid.BackgroundColor = [0.7725 0.8627 0.9412];

            % Create OpenMusicButton
            app.OpenMusicButton = uibutton(app.PlaylistGrid, 'push');
            app.OpenMusicButton.ButtonPushedFcn = createCallbackFcn(app, @OpenMusicButtonPushed, true);
            app.OpenMusicButton.FontSize = 16;
            app.OpenMusicButton.Layout.Row = 4;
            app.OpenMusicButton.Layout.Column = 1;
            app.OpenMusicButton.Text = '打开本地音乐';

            % Create DeleteMusicButton
            app.DeleteMusicButton = uibutton(app.PlaylistGrid, 'push');
            app.DeleteMusicButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteMusicButtonPushed, true);
            app.DeleteMusicButton.FontSize = 16;
            app.DeleteMusicButton.Layout.Row = 5;
            app.DeleteMusicButton.Layout.Column = 1;
            app.DeleteMusicButton.Text = '删除选中';

            % Create ClearPlaylistButton
            app.ClearPlaylistButton = uibutton(app.PlaylistGrid, 'push');
            app.ClearPlaylistButton.ButtonPushedFcn = createCallbackFcn(app, @ClearPlaylistButtonPushed, true);
            app.ClearPlaylistButton.FontSize = 16;
            app.ClearPlaylistButton.Layout.Row = 6;
            app.ClearPlaylistButton.Layout.Column = 1;
            app.ClearPlaylistButton.Text = '清空播放列表';

            % Create PlaylistListBoxLabel
            app.PlaylistListBoxLabel = uilabel(app.PlaylistGrid);
            app.PlaylistListBoxLabel.HorizontalAlignment = 'center';
            app.PlaylistListBoxLabel.VerticalAlignment = 'bottom';
            app.PlaylistListBoxLabel.FontName = 'Artifakt Element Book';
            app.PlaylistListBoxLabel.FontSize = 20;
            app.PlaylistListBoxLabel.Layout.Row = 1;
            app.PlaylistListBoxLabel.Layout.Column = 1;
            app.PlaylistListBoxLabel.Text = '播放列表';

            % Create PlaylistListBox
            app.PlaylistListBox = uilistbox(app.PlaylistGrid);
            app.PlaylistListBox.Items = {'鸟之诗-小提琴版', '鸟之诗-基础版'};
            app.PlaylistListBox.ValueChangedFcn = createCallbackFcn(app, @PlaylistListBoxValueChanged, true);
            app.PlaylistListBox.FontName = 'Artifakt Element Book';
            app.PlaylistListBox.FontSize = 14;
            app.PlaylistListBox.Layout.Row = [2 3];
            app.PlaylistListBox.Layout.Column = 1;
            app.PlaylistListBox.Value = '鸟之诗-小提琴版';

            % Create CurrentSongPanel
            app.CurrentSongPanel = uipanel(app.GridLayout);
            app.CurrentSongPanel.TitlePosition = 'centertop';
            app.CurrentSongPanel.Title = 'DSP电子音乐工作站';
            app.CurrentSongPanel.BackgroundColor = [0.7137 0.8 0.8706];
            app.CurrentSongPanel.Layout.Row = 1;
            app.CurrentSongPanel.Layout.Column = 2;
            app.CurrentSongPanel.FontWeight = 'bold';
            app.CurrentSongPanel.FontSize = 28;

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.CurrentSongPanel);
            app.GridLayout3.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            app.GridLayout3.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', 48};
            app.GridLayout3.BackgroundColor = [0.7725 0.8627 0.9412];

            % Create WaveformAxes
            app.WaveformAxes = uiaxes(app.GridLayout3);
            title(app.WaveformAxes, '当前歌曲波形（时域）')
            xlabel(app.WaveformAxes, '时间 / s')
            ylabel(app.WaveformAxes, '幅值')
            zlabel(app.WaveformAxes, 'Z')
            app.WaveformAxes.Layout.Row = [1 3];
            app.WaveformAxes.Layout.Column = [1 5];

            % Create SpectrumAxes
            app.SpectrumAxes = uiaxes(app.GridLayout3);
            title(app.SpectrumAxes, '当前歌曲频谱（FFT）')
            xlabel(app.SpectrumAxes, '频率 / Hz')
            ylabel(app.SpectrumAxes, '归一化幅值')
            zlabel(app.SpectrumAxes, 'Z')
            app.SpectrumAxes.Layout.Row = [4 6];
            app.SpectrumAxes.Layout.Column = [1 5];

            % Create PreviousButton
            app.PreviousButton = uibutton(app.GridLayout3, 'push');
            app.PreviousButton.ButtonPushedFcn = createCallbackFcn(app, @PreviousButtonPushed, true);
            app.PreviousButton.FontSize = 16;
            app.PreviousButton.Layout.Row = 9;
            app.PreviousButton.Layout.Column = 1;
            app.PreviousButton.Text = '上一首';

            % Create NextButton
            app.NextButton = uibutton(app.GridLayout3, 'push');
            app.NextButton.ButtonPushedFcn = createCallbackFcn(app, @NextButtonPushed, true);
            app.NextButton.FontSize = 16;
            app.NextButton.Layout.Row = 9;
            app.NextButton.Layout.Column = 2;
            app.NextButton.Text = '下一首';

            % Create PlayButton
            app.PlayButton = uibutton(app.GridLayout3, 'push');
            app.PlayButton.ButtonPushedFcn = createCallbackFcn(app, @PlayButtonPushed, true);
            app.PlayButton.FontSize = 16;
            app.PlayButton.Layout.Row = 9;
            app.PlayButton.Layout.Column = 3;
            app.PlayButton.Text = '播放';

            % Create PauseButton
            app.PauseButton = uibutton(app.GridLayout3, 'push');
            app.PauseButton.ButtonPushedFcn = createCallbackFcn(app, @PauseButtonPushed, true);
            app.PauseButton.FontSize = 16;
            app.PauseButton.Layout.Row = 9;
            app.PauseButton.Layout.Column = 4;
            app.PauseButton.Text = '暂停';

            % Create SaveAudioButton
            app.SaveAudioButton = uibutton(app.GridLayout3, 'push');
            app.SaveAudioButton.ButtonPushedFcn = createCallbackFcn(app, @SaveAudioButtonPushed, true);
            app.SaveAudioButton.FontSize = 16;
            app.SaveAudioButton.Layout.Row = 9;
            app.SaveAudioButton.Layout.Column = 5;
            app.SaveAudioButton.Text = '保存当前音频';

            % Create GridLayout5
            app.GridLayout5 = uigridlayout(app.GridLayout3);
            app.GridLayout5.ColumnWidth = {'1x', '12x', '1x'};
            app.GridLayout5.RowHeight = {'1x'};
            app.GridLayout5.Layout.Row = 8;
            app.GridLayout5.Layout.Column = [1 5];

            % Create ProgressSlider
            app.ProgressSlider = uislider(app.GridLayout5);
            app.ProgressSlider.MajorTicks = [];
            app.ProgressSlider.ValueChangedFcn = createCallbackFcn(app, @ProgressSliderValueChanged, true);
            app.ProgressSlider.ValueChangingFcn = createCallbackFcn(app, @ProgressSliderValueChanging, true);
            app.ProgressSlider.MinorTicksMode = 'manual';
            app.ProgressSlider.Layout.Row = 1;
            app.ProgressSlider.Layout.Column = 2;

            % Create TotalTimeLabel
            app.TotalTimeLabel = uilabel(app.GridLayout5);
            app.TotalTimeLabel.Layout.Row = 1;
            app.TotalTimeLabel.Layout.Column = 3;
            app.TotalTimeLabel.Text = '01:36';

            % Create CurrentTimeLabel
            app.CurrentTimeLabel = uilabel(app.GridLayout5);
            app.CurrentTimeLabel.HorizontalAlignment = 'right';
            app.CurrentTimeLabel.Layout.Row = 1;
            app.CurrentTimeLabel.Layout.Column = 1;
            app.CurrentTimeLabel.Text = '00:00';

            % Create SongNameTitleLabel
            app.SongNameTitleLabel = uilabel(app.GridLayout3);
            app.SongNameTitleLabel.FontSize = 16;
            app.SongNameTitleLabel.Layout.Row = 7;
            app.SongNameTitleLabel.Layout.Column = 1;
            app.SongNameTitleLabel.Text = '当前歌名：';

            % Create DurationTitleLabel
            app.DurationTitleLabel = uilabel(app.GridLayout3);
            app.DurationTitleLabel.FontSize = 16;
            app.DurationTitleLabel.Layout.Row = 7;
            app.DurationTitleLabel.Layout.Column = 4;
            app.DurationTitleLabel.Text = '时长：';

            % Create SongNameLabel
            app.SongNameLabel = uilabel(app.GridLayout3);
            app.SongNameLabel.FontSize = 16;
            app.SongNameLabel.Layout.Row = 7;
            app.SongNameLabel.Layout.Column = [2 3];
            app.SongNameLabel.Text = '鸟之诗-小提琴版';

            % Create DurationLabel
            app.DurationLabel = uilabel(app.GridLayout3);
            app.DurationLabel.FontSize = 16;
            app.DurationLabel.Layout.Row = 7;
            app.DurationLabel.Layout.Column = 5;
            app.DurationLabel.Text = '01:36';

            % Create PlaybackSettingsPanel
            app.PlaybackSettingsPanel = uipanel(app.GridLayout);
            app.PlaybackSettingsPanel.BackgroundColor = [0.6784 0.7804 0.8588];
            app.PlaybackSettingsPanel.Layout.Row = 1;
            app.PlaybackSettingsPanel.Layout.Column = 3;

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.PlaybackSettingsPanel);
            app.GridLayout4.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout4.BackgroundColor = [0.7725 0.8627 0.9412];

            % Create EqualizerButton
            app.EqualizerButton = uibutton(app.GridLayout4, 'push');
            app.EqualizerButton.ButtonPushedFcn = createCallbackFcn(app, @EqualizerButtonPushed, true);
            app.EqualizerButton.FontSize = 18;
            app.EqualizerButton.Layout.Row = 8;
            app.EqualizerButton.Layout.Column = [1 2];
            app.EqualizerButton.Text = '9段均衡器';

            % Create ReverbButton
            app.ReverbButton = uibutton(app.GridLayout4, 'push');
            app.ReverbButton.ButtonPushedFcn = createCallbackFcn(app, @ReverbButtonPushed, true);
            app.ReverbButton.FontSize = 18;
            app.ReverbButton.Layout.Row = 7;
            app.ReverbButton.Layout.Column = [1 2];
            app.ReverbButton.Text = '数字混响器';

            % Create Label_5
            app.Label_5 = uilabel(app.GridLayout4);
            app.Label_5.HorizontalAlignment = 'right';
            app.Label_5.FontSize = 16;
            app.Label_5.Layout.Row = 5;
            app.Label_5.Layout.Column = 1;
            app.Label_5.Text = '声道模式:';

            % Create ChannelModeDropDown
            app.ChannelModeDropDown = uidropdown(app.GridLayout4);
            app.ChannelModeDropDown.Items = {'保持原声', '单声道', '双声道'};
            app.ChannelModeDropDown.ValueChangedFcn = createCallbackFcn(app, @ChannelModeDropDownValueChanged, true);
            app.ChannelModeDropDown.FontSize = 16;
            app.ChannelModeDropDown.Layout.Row = 5;
            app.ChannelModeDropDown.Layout.Column = 2;
            app.ChannelModeDropDown.Value = '保持原声';

            % Create Label_9
            app.Label_9 = uilabel(app.GridLayout4);
            app.Label_9.HorizontalAlignment = 'right';
            app.Label_9.FontSize = 16;
            app.Label_9.Layout.Row = 4;
            app.Label_9.Layout.Column = 1;
            app.Label_9.Text = '播放模式:';

            % Create PlayModeDropDown
            app.PlayModeDropDown = uidropdown(app.GridLayout4);
            app.PlayModeDropDown.Items = {'顺序播放', '列表循环', '单曲循环', '随机播放'};
            app.PlayModeDropDown.FontSize = 16;
            app.PlayModeDropDown.Layout.Row = 4;
            app.PlayModeDropDown.Layout.Column = 2;
            app.PlayModeDropDown.Value = '列表循环';

            % Create Label_8
            app.Label_8 = uilabel(app.GridLayout4);
            app.Label_8.HorizontalAlignment = 'right';
            app.Label_8.FontSize = 16;
            app.Label_8.Layout.Row = 3;
            app.Label_8.Layout.Column = 1;
            app.Label_8.Text = '播放速度:';

            % Create PlaybackSpeedDropDown
            app.PlaybackSpeedDropDown = uidropdown(app.GridLayout4);
            app.PlaybackSpeedDropDown.Items = {'0.5×', '0.75×', '1.0×', '1.25×', '1.5×', '2.0×'};
            app.PlaybackSpeedDropDown.ValueChangedFcn = createCallbackFcn(app, @PlaybackSpeedDropDownValueChanged, true);
            app.PlaybackSpeedDropDown.FontSize = 16;
            app.PlaybackSpeedDropDown.Layout.Row = 3;
            app.PlaybackSpeedDropDown.Layout.Column = 2;
            app.PlaybackSpeedDropDown.Value = '1.0×';

            % Create Label_4
            app.Label_4 = uilabel(app.GridLayout4);
            app.Label_4.HorizontalAlignment = 'right';
            app.Label_4.FontSize = 16;
            app.Label_4.Layout.Row = 2;
            app.Label_4.Layout.Column = 1;
            app.Label_4.Text = '音量:';

            % Create VolumeSlider
            app.VolumeSlider = uislider(app.GridLayout4);
            app.VolumeSlider.ValueChangedFcn = createCallbackFcn(app, @VolumeSliderValueChanged, true);
            app.VolumeSlider.MinorTicksMode = 'manual';
            app.VolumeSlider.Layout.Row = 2;
            app.VolumeSlider.Layout.Column = 2;
            app.VolumeSlider.Value = 80;

            % Create Label_10
            app.Label_10 = uilabel(app.GridLayout4);
            app.Label_10.HorizontalAlignment = 'right';
            app.Label_10.FontSize = 16;
            app.Label_10.Layout.Row = 6;
            app.Label_10.Layout.Column = 1;
            app.Label_10.Text = '人声处理:';

            % Create VocalProcessDropDown
            app.VocalProcessDropDown = uidropdown(app.GridLayout4);
            app.VocalProcessDropDown.Items = {'关闭', '去人声'};
            app.VocalProcessDropDown.ValueChangedFcn = createCallbackFcn(app, @VocalProcessDropDownValueChanged, true);
            app.VocalProcessDropDown.FontSize = 16;
            app.VocalProcessDropDown.Layout.Row = 6;
            app.VocalProcessDropDown.Layout.Column = 2;
            app.VocalProcessDropDown.Value = '关闭';

            % Create DSPLabel
            app.DSPLabel = uilabel(app.GridLayout4);
            app.DSPLabel.HorizontalAlignment = 'center';
            app.DSPLabel.FontSize = 20;
            app.DSPLabel.Layout.Row = 1;
            app.DSPLabel.Layout.Column = [1 2];
            app.DSPLabel.Text = '播放与DSP设置';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MusicPlayer

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