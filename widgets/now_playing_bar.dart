import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';

class NowPlayingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentMusic = playerProvider.currentMusic;
    final theme = Theme.of(context);

    if (currentMusic == null) {
      return SizedBox.shrink();
    }

    return Column(
      children: [
        if (playerProvider.showPlaylist) _buildPlaylistOverlay(context),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PlayerScreen()),
            );
          },
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Hero(
                    tag: 'album_${currentMusic.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        currentMusic.pic,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: Icon(Icons.music_note),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentMusic.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: 4),
                      Text(
                        currentMusic.artist,
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: 4),
                      StreamBuilder<Duration?>(
                        stream: playerProvider.audioPlayer.durationStream,
                        builder: (context, durationSnapshot) {
                          final duration = durationSnapshot.data ??
                              Duration.zero;

                          return StreamBuilder<Duration>(
                            stream: playerProvider.audioPlayer.positionStream,
                            builder: (context, positionSnapshot) {
                              final position = positionSnapshot.data ??
                                  Duration.zero;
                              final progress = duration.inMilliseconds > 0
                                  ? (position.inMilliseconds /
                                  duration.inMilliseconds).clamp(0.0, 1.0)
                                  : 0.0;

                              return LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    StreamBuilder<bool>(
                      stream: playerProvider.audioPlayer.playingStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 24,
                            color: theme.iconTheme.color,
                          ),
                          onPressed: () {
                            playerProvider.setIsPlaying(!isPlaying);
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.playlist_play, size: 24,
                          color: theme.iconTheme.color),
                      onPressed: () {
                        playerProvider.togglePlaylist();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistOverlay(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final theme = Theme.of(context);

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Text(
                  '播放列表 (${playerProvider.playlist.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(
                      Icons.close, size: 20, color: theme.iconTheme.color),
                  onPressed: () {
                    playerProvider.hidePlaylist();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: playerProvider.playlist.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music, size: 60, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text(
                    '播放列表为空',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: playerProvider.playlist.length,
              itemBuilder: (context, index) {
                final music = playerProvider.playlist[index];
                final isCurrent = playerProvider.currentIndex == index;

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCurrent ? Colors.blue.withOpacity(0.1) : Colors
                        .transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? Colors.blue : theme.textTheme
                              .bodySmall?.color,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight
                              .normal,
                        ),
                      ),
                    ),
                    title: Text(
                      music.name,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight
                            .normal,
                        color: isCurrent ? Colors.blue : theme.textTheme
                            .bodyLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      music.artist,
                      style: TextStyle(
                        color: isCurrent ? Colors.blue : theme.textTheme.bodySmall
                            ?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCurrent)
                          Icon(Icons.equalizer, color: Colors.blue, size: 16)
                        else
                          SizedBox.shrink(),
                        SizedBox(width: 8),
                        // 删除按钮
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          onPressed: () {
                            playerProvider.removeFromPlaylist(index);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      playerProvider.playFromPlaylist(index);
                      playerProvider.hidePlaylist();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
