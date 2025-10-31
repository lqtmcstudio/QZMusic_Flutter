import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import '../providers/player_provider.dart';
import '../providers/storage_provider.dart';
import 'playinglist_screen.dart';
import 'dart:async';

// ===================== 歌词解析模型 =====================
class LyricLine {
  final Duration time;
  final String text;
  LyricLine(this.time, this.text);
}

List<LyricLine> parseLyrics(String lyrics) {
  final RegExp regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
  final lines = <LyricLine>[];
  for (var line in lyrics.split('\n')) {
    final match = regex.firstMatch(line);
    if (match != null) {
      final minute = int.parse(match.group(1)!);
      final second = int.parse(match.group(2)!);
      final milliStr = match.group(3)!;
      final millisecond = milliStr.length == 3
          ? int.parse(milliStr)
          : int.parse(milliStr) * 10;
      final text = match.group(4)!.trim();
      if (text != "") {
        lines.add(LyricLine(Duration(
            minutes: minute, seconds: second, milliseconds: millisecond),
            text));
      }
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

// ===================== 自定义滑块 =====================
class VerticalRectSliderThumbShape extends SliderComponentShape {
  final double thumbSize;
  final double enabledThumbRadius;
  const VerticalRectSliderThumbShape({
    this.thumbSize = 24.0,
    this.enabledThumbRadius = 10.0,
  });
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(thumbSize, thumbSize);
  @override
  void paint(
      PaintingContext context,
      Offset center, {
        required Animation<double> activationAnimation,
        required Animation<double> enableAnimation,
        required bool isDiscrete,
        required TextPainter labelPainter,
        required RenderBox parentBox,
        required SliderThemeData sliderTheme,
        required TextDirection textDirection,
        required double value,
        required double textScaleFactor,
        required Size sizeWithOverflow,
      }) {
    final canvas = context.canvas;
    final Color color = ColorTween(
      begin: sliderTheme.disabledThumbColor,
      end: sliderTheme.thumbColor,
    ).evaluate(enableAnimation)!;

    final Rect thumbRect = Rect.fromCenter(center: center, width: 8.0, height: thumbSize);
    final RRect thumbRRect = RRect.fromRectAndRadius(thumbRect, Radius.circular(2.0));

    final Paint paint = Paint()..color = color..style = PaintingStyle.fill;
    final Paint border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0;

    canvas.drawRRect(thumbRRect, paint);
    canvas.drawRRect(thumbRRect, border);
  }
}

// ===================== 主界面 =====================
class PlayerScreen extends StatefulWidget {
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool showLyrics = false;
  ScrollController _scrollController = ScrollController();
  int currentLine = 0;
  Timer? _scrollTimer;
  List<LyricLine> _parsedLyrics = [];

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScrollToCurrentLine() {
    if (_parsedLyrics.isEmpty) return;

    // 计算目标滚动位置，让当前歌词居中
    final double itemHeight = 70.0; // 增加每行歌词的高度
    final double viewportHeight = _scrollController.position.viewportDimension;
    final double targetOffset = currentLine * itemHeight - viewportHeight / 2 + itemHeight / 2;

    // 限制滚动范围，确保第一句和最后一句都能居中
    final double minScroll = 0;
    final double maxScroll = (_parsedLyrics.length * itemHeight - viewportHeight).clamp(0, double.infinity);
    final double clampedOffset = targetOffset.clamp(minScroll, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: Duration(milliseconds: 800), // 增加动画时间使滚动更平滑
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final theme = Theme.of(context);
    final currentMusic = playerProvider.currentMusic;
    final lyricsText = playerProvider.lyrics??'';
    if (currentMusic == null) {
      return Scaffold(
        appBar: AppBar(title: Text('播放')),
        body: Center(child: Text('暂无播放内容')),
      );
    }

    // 解析歌词
    _parsedLyrics = lyricsText.isNotEmpty
        ? parseLyrics(lyricsText)
        : [LyricLine(Duration.zero, "无法获取歌词")];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            Container(
              height: 56, // 调整高度以适配标准 AppBar 高度
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左侧：返回按钮
                  IconButton(
                    icon: Icon(Icons.arrow_downward, color: theme.iconTheme.color),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // 右侧：三个点菜单 (PopupMenuButton)
                  _buildMoreOptionsButton(context, playerProvider, theme),
                ],
              ),
            ),

            // 封面 or 歌词切换区域
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => setState(() => showLyrics = !showLyrics),
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 500),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: showLyrics
                      ? _buildLyricsView(playerProvider, theme)
                      : _buildCover(currentMusic.pic),
                ),
              ),
            ),

            // 下半部信息与控制
            Expanded(
              flex: 2,
              child: _buildControlSection(context, playerProvider, theme),
            ),
          ]),
        ]),
      ),
    );
  }

  // ===================== 封面 =====================
  Widget _buildCover(String imageUrl) {
    return Container(
      key: ValueKey('cover'),
      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Center(
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(children: [
              Image.network(imageUrl, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
  // ===================== 更多 =====================
  Widget _buildMoreOptionsButton(BuildContext context, PlayerProvider provider, ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
      onSelected: (String result) {
        // 点击菜单项后，根据选择结果执行操作
        switch (result) {
          case 'download':
          // 假设 PlayerProvider 中有 downloadCurrentMusic 方法
            //provider.downloadCurrentMusic();
            debugPrint('下载');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('正在下载：${provider.currentMusic?.name ?? "音乐"}')),
            );
            break;
          case 'share':
          // 假设 PlayerProvider 中有 shareCurrentMusic 方法
            //provider.shareCurrentMusic();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('准备分享：${provider.currentMusic?.name ?? "音乐"}')),
            );
            break;
          case 'save':
            _showSaveToPlaylistDialog(context,provider);
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.download_rounded, color: theme.iconTheme.color),
              SizedBox(width: 8),
              Text('下载'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, color: theme.iconTheme.color),
              SizedBox(width: 8),
              Text('分享'),
            ],
          ),
        ),
        // 3. 【新增】保存歌单按钮
        PopupMenuItem<String>(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.save, color: theme.iconTheme.color),
              SizedBox(width: 8),
              Text('保存到歌单'),
            ],
          ),
        ),
      ],
      // 设置弹出菜单的背景颜色等样式
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
  // ===================== 添加到歌单 ================
  Future<void> _showSaveToPlaylistDialog(BuildContext context, PlayerProvider provider) async {
    //final storage = Provider.of<StorageProvider>(context, listen: false);
    final playlistIndexFile = File(await storage.getPriFilePath('playlist/index.json'));
    final music = provider.currentMusic;

    if (music == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有播放的音乐')),
      );
      return;
    }

    // 如果没有歌单索引文件，提示创建
    if (!await playlistIndexFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无歌单，请先创建歌单')),
      );
      return;
    }

    // 读取 index.json
    final indexString = await playlistIndexFile.readAsString();
    final List<dynamic> playlists = json.decode(indexString);

    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无歌单，请先创建歌单')),
      );
      return;
    }

    // 弹出选择框
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择要保存到的歌单'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  title: Text(playlist['name'] ?? '未命名歌单'),
                  onTap: () => Navigator.pop(context, playlist),
                );
              },
            ),
          ),
        );
      },
    );

    // 用户未选择则退出
    if (selected == null) return;

    final playlistId = selected['id'];
    final playlistFile = File(await storage.getPriFilePath('playlist/$playlistId.json'));

    List<dynamic> currentList = [];
    if (await playlistFile.exists()) {
      currentList = json.decode(await playlistFile.readAsString());
    }

    // 检查是否重复（id + source）
    bool exists = currentList.any((item) =>
    item['id'] == music.id && item['source'] == music.source,
    );

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('该歌曲已存在于歌单 "${selected['name']}"')),
      );
      return;
    }

    // 追加歌曲
    currentList.add(music.toJson());
    await playlistFile.writeAsString(json.encode(currentList));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加到歌单 "${selected['name']}"')),
    );
  }
  // ===================== 歌词 =====================
  Widget _buildLyricsView(PlayerProvider provider, ThemeData theme) {

    return StreamBuilder<Duration>(
      stream: provider.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        for (int i = 0; i < _parsedLyrics.length; i++) {
          if (i < _parsedLyrics.length - 1 &&
              position >= _parsedLyrics[i].time &&
              position < _parsedLyrics[i + 1].time) {
            if (currentLine != i) {
              currentLine = i;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _autoScrollToCurrentLine();
              });
            }
          }
        }

        return Container(
          key: ValueKey('lyrics'),
          child: Stack(
            children: [
              // 歌词列表
              ListView.builder(
                controller: _scrollController,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _parsedLyrics.length,
                itemBuilder: (context, index) {
                  final line = _parsedLyrics[index];
                  final isCurrent = index == currentLine;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 70, // 增加每行歌词的高度
                      alignment: Alignment.center,
                      child: AnimatedDefaultTextStyle(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          fontSize: isCurrent ? 22 : 18,
                          color: isCurrent ? theme.primaryColor : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          height: 1.0,
                          shadows: isCurrent
                              ? [
                            Shadow(
                              color: theme.primaryColor.withOpacity(0.7),
                              blurRadius: 3,
                              offset: Offset(0, 0),
                            ),
                            Shadow(
                              color: theme.primaryColor.withOpacity(0.5),
                              blurRadius: 8,
                              offset: Offset(0, 0),
                            ),
                          ]
                              : null,
                        ),
                        child: Text(
                          line.text,
                          textAlign: TextAlign.center,
                          maxLines: 1, // 允许歌词换行
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  );
                },
              ),

              // // 顶部渐变遮罩
              // IgnorePointer(
              //   child: Container(
              //     height: 100,
              //     decoration: BoxDecoration(
              //       gradient: LinearGradient(
              //         begin: Alignment.topCenter,
              //         end: Alignment.bottomCenter,
              //         colors: [
              //           theme.scaffoldBackgroundColor,
              //           theme.scaffoldBackgroundColor.withOpacity(0.8),
              //           Colors.transparent,
              //         ],
              //         stops: [0.0, 0.3, 1.0],
              //       ),
              //     ),
              //   ),
              // ),
              //
              // // 底部渐变遮罩
              // Align(
              //   alignment: Alignment.bottomCenter,
              //   child: IgnorePointer(
              //     child: Container(
              //       height: 100,
              //       decoration: BoxDecoration(
              //         gradient: LinearGradient(
              //           begin: Alignment.topCenter,
              //           end: Alignment.bottomCenter,
              //           colors: [
              //             Colors.transparent,
              //             theme.scaffoldBackgroundColor.withOpacity(0.8),
              //             theme.scaffoldBackgroundColor,
              //           ],
              //           stops: [0.0, 0.7, 1.0],
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        );
      },
    );
  }

  // ===================== 控制区（完全保留原逻辑） =====================
  Widget _buildControlSection(BuildContext context, PlayerProvider playerProvider, ThemeData theme) {
    final currentMusic = playerProvider.currentMusic!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(children: [
            Text(
              currentMusic.name,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            SizedBox(height: 6),
            Text(
              currentMusic.artist,
              style: TextStyle(fontSize: 16, color: theme.textTheme.bodySmall?.color),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ]),

          // 进度条
          StreamBuilder<Duration?>(
            stream: playerProvider.audioPlayer.durationStream,
            builder: (context, durationSnapshot) {
              final duration = durationSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: playerProvider.audioPlayer.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0;

                  return Column(children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: VerticalRectSliderThumbShape(thumbSize: 20.0, enabledThumbRadius: 8.0),
                        trackShape: RoundedRectSliderTrackShape(),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 16.0),
                        thumbColor: theme.primaryColor,
                        activeTrackColor: theme.primaryColor,
                        inactiveTrackColor: Colors.grey[400],
                        overlayColor: theme.primaryColor.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (value) => playerProvider.setProgress(value),
                        onChangeEnd: (value) => playerProvider.audioPlayer.seek(duration * value),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position),
                              style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                          Text(_formatDuration(duration),
                              style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                        ],
                      ),
                    ),
                  ]);
                },
              );
            },
          ),

          // 主控制按钮（保持原样）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIconButton(theme, _getPlayModeIcon(playerProvider.playMode), () => _togglePlayMode(playerProvider)),
              _buildIconButton(theme, Icon(Icons.skip_previous, size: 26), playerProvider.previousMusic),
              Container(
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: IconButton(
                  icon: Icon(
                    playerProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => playerProvider.setIsPlaying(!playerProvider.isPlaying),
                ),
              ),
              _buildIconButton(theme, Icon(Icons.skip_next, size: 26), playerProvider.nextMusic),
              _buildIconButton(
                theme,
                const Icon(Icons.playlist_play, size: 22),
                    () => Navigator.of(context).push(PageRouteBuilder<PlayingListScreen>(
                  pageBuilder: (_, __, ___) => const PlayingListScreen(),
                  transitionsBuilder: (_, anim, __, child) => SharedAxisTransition(
                    animation: anim,
                    secondaryAnimation: __,
                    transitionType: SharedAxisTransitionType.scaled,
                    child: child,
                  ),
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(ThemeData theme, Icon icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: IconButton(icon: icon, color: theme.iconTheme.color, onPressed: onPressed),
    );
  }

  Icon _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icon(Icons.repeat);
      case PlayMode.single:
        return Icon(Icons.repeat_one);
      case PlayMode.random:
        return Icon(Icons.shuffle);
    }
  }

  void _togglePlayMode(PlayerProvider provider) {
    switch (provider.playMode) {
      case PlayMode.sequence:
        provider.setPlayMode(PlayMode.single);
        break;
      case PlayMode.single:
        provider.setPlayMode(PlayMode.random);
        break;
      case PlayMode.random:
        provider.setPlayMode(PlayMode.sequence);
        break;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }
}