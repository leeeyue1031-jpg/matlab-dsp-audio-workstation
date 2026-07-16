# MATLAB DSP Audio Workstation

一个基于 MATLAB App Designer 开发的桌面音频处理工作站，包含音乐播放、九段图形均衡器和数字混响三个应用。

## 功能

- **MusicPlayer**：导入和管理播放列表，支持播放控制、进度显示、动态波形与频谱显示。
- **GraphicEqualizer**：提供 62 Hz、125 Hz、250 Hz、500 Hz、1 kHz、2 kHz、4 kHz、8 kHz 和 16 kHz 九个频段的增益调节。
- **DigitalReverb**：提供数字混响处理，可调混响时间、干湿比、预延迟、反馈、高频阻尼和输出增益等参数。
- 三个应用可配合使用，形成“播放—均衡—混响”的音频处理流程。

## 仓库内容

```text
.
├── MusicPlayer.mlapp            # 音乐播放器
├── GraphicEqualizer.mlapp       # 九段图形均衡器
├── DigitalReverb.mlapp          # 数字混响处理器
├── bird_song.m                  # 基础版歌曲合成脚本
├── makeNote.m                   # 基础版单音生成函数
├── bird_song_violin.m           # 小提琴版歌曲合成脚本
├── makeNote_violin.m            # 小提琴音色建模函数
├── 鸟之诗-基础版.wav             # 默认测试音频
└── 鸟之诗-小提琴版.wav           # 默认测试音频
```

## 使用方法

1. 安装 MATLAB，并确保 App Designer 可用。
2. 下载或克隆本仓库。
3. 在 MATLAB 中打开 `MusicPlayer.mlapp`，点击 **Run** 运行。
4. 在播放器中载入仓库内的默认 WAV 音频，或选择自己的音频文件。
5. 根据需要打开图形均衡器或数字混响应用进行处理。

部分滤波和音频处理功能可能需要 Signal Processing Toolbox 或 Audio Toolbox，具体取决于本机 MATLAB 版本。

## 音频合成源码

- 运行 `bird_song.m` 可使用 `makeNote.m` 合成基础版音频。
- 运行 `bird_song_violin.m` 可使用 `makeNote_violin.m` 合成小提琴版音频。
- 小提琴版本使用多谐波加法合成、包络、揉弦、弓压变化、弓毛噪声和简化琴体共振等 DSP 建模方法，不使用真实乐器采样。

运行歌曲脚本前，请确保对应的 `makeNote` 函数与脚本位于同一目录，并将 MATLAB 当前文件夹切换到仓库根目录。

## 默认音频说明

仓库中的 WAV 文件用于应用演示与功能测试。公开使用或再分发前，请确认你拥有相应音频的使用和传播授权；也可以替换为自有或开放许可的测试音频。

## 开发环境

- MATLAB
- App Designer
