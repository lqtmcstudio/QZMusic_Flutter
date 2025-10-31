class DailyRecommendMusic {
  final String songName;
  final String songerName;
  final String cover;
  final String songMid;

  DailyRecommendMusic({
    required this.songName,
    required this.songerName,
    required this.cover,
    required this.songMid,
  });

  factory DailyRecommendMusic.fromJson(Map<String, dynamic> json) =>
      DailyRecommendMusic(
        songName: json['song_name'] ?? '',
        songerName: json['songer_name'] ?? '',
        cover: json['cover'] ?? '',
        songMid: json['song_mid'] ?? '',
      );

  Map<String, dynamic> toJson() => {
    'song_name': songName,
    'songer_name': songerName,
    'cover': cover,
    'song_mid': songMid,
  };
}
