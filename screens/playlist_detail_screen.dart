import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../models/music_model.dart';
class PlaylistDetailScreen extends StatelessWidget {
  final String playlistName;
  final String description;
  final String? coverUrl;
  final List<Music> songs;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistName,
    required this.description,
    this.coverUrl,
    required this.songs,
  });

  static Route<dynamic> route({
    required String name,
    required String desc,
    String? cover,
    required List<Music> songs,
  }) {
    return PageRouteBuilder<dynamic>(
      pageBuilder: (_, __, ___) => PlaylistDetailScreen(
        playlistName: name,
        description: desc,
        coverUrl: cover,
        songs: songs,
      ),
      transitionsBuilder: (_, animation, __, child) {
        const curve = Curves.easeOutCubic;
        final tween =
        Tween<double>(begin: 0.9, end: 1.0).chain(CurveTween(curve: curve));
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
    final scheme = theme.colorScheme;

    final resolvedCover = (songs.isNotEmpty && (songs.first.pic.isNotEmpty ?? false)
        ? songs.first.pic
        : null);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(playlistName),
      ),
      body: songs.isEmpty
          ? const _Empty()
          : SingleChildScrollView(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 歌单封面与信息 =====
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(resolvedCover, scheme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlistName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          final player = Provider.of<PlayerProvider>(
                              context,
                              listen: false);
                          _showSnackbar(context, '正在播放歌单$playlistName');
                          player.setPlaylist(songs);
                          player.playFromPlaylist(0);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("全部播放"),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            // ===== 歌曲列表 =====
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final song = songs[index];
                return _SongTile(songs: songs, index: index,song: song);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(String? cover, ColorScheme scheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: cover == null || cover.isEmpty
          ? Container(
        width: 120,
        height: 120,
        color: scheme.surfaceVariant.withOpacity(0.5),
        child: Icon(Icons.music_note, size: 64, color: scheme.primary),
      )
          : Image.network(
        cover,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 120,
          height: 120,
          color: scheme.surfaceVariant.withOpacity(0.5),
          child:
          Icon(Icons.music_note, size: 64, color: scheme.primary),
        ),
      ),
    );
  }
}

/* ---------------- 私有组件 ---------------- */
void _showSnackbar(BuildContext context,String str){
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(str),
      duration: Duration(seconds: 1),
    ),
  );
}
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 120, color: scheme.primary),
          const SizedBox(height: 16),
          Text('这个歌单是空的', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final List<Music> songs;
  final int index;
  final Music song;

  const _SongTile({required this.songs, required this.index, required this.song});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = Provider.of<PlayerProvider>(context, listen: false);

    return Material(
      color: scheme.surfaceVariant.withOpacity(0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await player.setPlaylist(songs);
          await player.playFromPlaylist(index);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 序号
              SizedBox(
                width: 32,
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: song.pic == null || song.pic.isEmpty
                    ? Container(
                  width: 48,
                  height: 48,
                  color: scheme.surfaceVariant.withOpacity(0.5),
                  child: Icon(Icons.music_note,
                      size: 28, color: scheme.primary),
                )
                    : Image.network(
                  song.pic,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: scheme.surfaceVariant.withOpacity(0.5),
                    child: Icon(Icons.music_note,
                        size: 28, color: scheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.name ?? '未知歌曲',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(song.artist ?? '未知歌手',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => player.addToPlaylist(song),
              ),
            ],
          ),
        ),
      ),
    );
  }
}