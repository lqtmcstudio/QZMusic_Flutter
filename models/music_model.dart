import 'daily_recommend_music.dart';
class Music {
  final String name;
  final String artist;
  String pic;
  final String id;
  final String? source;
  static const String defaultIconUrl = 'https://placehold.co/200x200';

  Music({
    required this.name,
    required this.artist,
    required this.pic,
    required this.id,
    this.source,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      name: json['name'],
      artist: json['artist'] ?? '',
      pic: json['pic'] ?? defaultIconUrl,
      id: json['id'] ?? '',
      source: json['source'] ?? ''
    );
  }
  factory Music.fromDailyRecommend(DailyRecommendMusic dr) => Music(
    name: dr.songName,
    artist: dr.songerName,
    pic: dr.cover.isEmpty ? defaultIconUrl : dr.cover,
    id: dr.songMid,
    source: 'tx'
  );
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'artist': artist,
      'pic': pic,
      'id': id,
      'source': source
    };
  }

  bool get hasValidPic {
    return pic.isNotEmpty && pic != defaultIconUrl;
  }
}

enum AudioQuality {
  standard,
  high,
  lossless,
  lossless24bit,
  hires,
  atmos,
  master
}

class AudioQualityConfig {
  static const Map<AudioQuality, String> qualityNames = {
    AudioQuality.standard: '标准',
    AudioQuality.high: '高品',
    AudioQuality.lossless: '无损',
    AudioQuality.lossless24bit: '无损24bit',
    AudioQuality.hires: 'Hi-Res',
    AudioQuality.atmos: '杜比全景声',
    AudioQuality.master: '母带'
  };

  static const Map<AudioQuality, String> qualityCodes = {
    AudioQuality.standard: 'standard',
    AudioQuality.high: 'exhigh',
    AudioQuality.lossless: 'lossless',
    AudioQuality.lossless24bit: 'lossless+',
    AudioQuality.hires: 'hires',
    AudioQuality.atmos: 'atmos',
    AudioQuality.master: 'master'
  };

  static String getName(AudioQuality quality) {
    return qualityNames[quality] ?? '标准';
  }

  static String getCode(AudioQuality quality) {
    return qualityCodes[quality] ?? 'standard';
  }

  static List<AudioQuality> get qualities => AudioQuality.values;
}

enum MusicSource {
  source1,
  source2,
  source3,
  source4,
  source5
}

class MusicSourceConfig {
  static const Map<MusicSource, String> sourceNames = {
    MusicSource.source1: '酷我音乐',
    MusicSource.source2: '网易云音乐',
    MusicSource.source3: 'QQ音乐',
    MusicSource.source4: '咪咕音乐',
    MusicSource.source5: '酷狗音乐',
  };
  static const Map<MusicSource, String> sourceCodes = {
    MusicSource.source1: 'kw',
    MusicSource.source2: 'wy',
    MusicSource.source3: 'tx',
    MusicSource.source4: 'mg',
    MusicSource.source5: 'kg',
  };
  static String getName(MusicSource source) {
    return sourceNames[source] ?? '音源一';
  }
  static String getCode(MusicSource source) {
    return sourceCodes[source] ?? 'kw';
  }
  static List<MusicSource> get sources => MusicSource.values;
}
