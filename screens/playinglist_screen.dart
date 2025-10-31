import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
// import 'dart:convert';
// import '../providers/storage_provider.dart';
class PlayingListScreen extends StatelessWidget {
  const PlayingListScreen({super.key});

  static Route<dynamic> route() {
    return PageRouteBuilder<dynamic>(
      pageBuilder: (_, __, ___) => const PlayingListScreen(),
      transitionsBuilder: (_, animation, __, child) {
        const curve = Curves.easeOutCubic;
        final tween = Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: curve));
        final fade = animation.drive(CurveTween(curve: Curves.easeInOut));
        final scale = animation.drive(tween);

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('播放列表'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Consumer<PlayerProvider>(
        builder: (_, player, __) {
          if (player.playlist.isEmpty) return const _Empty();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: player.playlist.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final music = player.playlist[index];
              final current = player.currentIndex == index;

              return _MusicTile(
                music: music,
                index: index,
                current: current,
                onTap: () {
                  player.playFromPlaylist(index);
                  Navigator.pop(context); // 播放后返回
                },
                onDelete: () => player.removeFromPlaylist(index),
              );
            },
          );
        },
      ),
    );
  }
}

/* ---------------- 私有组件 ---------------- */

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music, size: 120, color: scheme.primary),
          const SizedBox(height: 16),
          Text('列表是空的', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _MusicTile extends StatelessWidget {
  final music;
  final int index;
  final bool current;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MusicTile({
    required this.music,
    required this.index,
    required this.current,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: current
          ? scheme.primaryContainer
          : scheme.surfaceVariant.withOpacity(0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 序号或正在播放图标
              SizedBox(
                width: 32,
                child: current
                    ? Icon(Icons.equalizer, color: scheme.primary, size: 20)
                    : Text('${index + 1}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(width: 12),

              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(music.pic, width: 48, height: 48, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),

              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(music.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight:
                            current ? FontWeight.bold : FontWeight.normal)),
                    Text(music.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),

              // 删除
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}