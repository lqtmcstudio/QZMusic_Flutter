import 'dart:io';
import '../providers/storage_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/music_model.dart';
import 'package:flutter_js/flutter_js.dart';
enum PlayMode { sequence, single, random }

class PlayerProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Music> _playlist = [];
  int? _currentIndex;
  PlayMode _playMode = PlayMode.sequence;
  bool _isPlaying = false;
  double _progress = 0.0;
  AudioQuality _audioQuality = AudioQuality.standard;
  MusicSource _musicSource = MusicSource.source1;
  bool _showPlaylist = false;
  String? _lyrics;
  bool _isSwitching = false;
  List<Music> get playlist => _playlist;
  Music? get currentMusic => _currentIndex != null && _currentIndex! < _playlist.length
      ? _playlist[_currentIndex!]
      : null;
  String? get lyrics => _lyrics;
  PlayMode get playMode => _playMode;
  bool get isPlaying => _isPlaying;
  double get progress => _progress;
  AudioPlayer get audioPlayer => _audioPlayer;
  bool get showPlaylist => _showPlaylist;
  AudioQuality get audioQuality => _audioQuality;
  MusicSource get musicSource => _musicSource;
  int? get currentIndex => _currentIndex;
  PlayerProvider() {
    _setupListeners();
  }


  void _setupListeners(){
    // 监听播放状态
    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      if (_isPlaying != isPlaying) {
        _isPlaying = isPlaying;
        notifyListeners();
      }

      // 只在处理状态为 Completed 时触发下一首逻辑
      if (processingState == ProcessingState.completed) {
        print('处理状态: COMPLETED');
        _handlePlaybackComplete();
      }
    });

    // 监听播放位置和进度
    _audioPlayer.positionStream.listen((position) {
      final duration = _audioPlayer.duration;
      if (duration != null && duration.inMilliseconds > 0) {
        double newProgress = position.inMilliseconds / duration.inMilliseconds;
        _progress = newProgress.clamp(0.0, 1.0);
        notifyListeners();
      } else {
        _progress = 0.0;
        notifyListeners();
      }
    });
  }
// PlayerProvider
  void _handlePlaybackComplete(){
    // 使用标志位防止重复调用 nextMusic/playFromPlaylist
    if (_isSwitching) {
      return;
    }

    // 仅在需要手动切换的模式下执行
    if (_playMode == PlayMode.sequence || _playMode == PlayMode.random) {
      // 设置标志位，开始切换
      _isSwitching = true;

      switch (_playMode) {
        case PlayMode.sequence:
        // 确保不是在单曲循环模式下
          if (_audioPlayer.loopMode == LoopMode.off) {
            // 传递标志位
            nextMusic(isAutoSwitch: true);
          }
          break;
        case PlayMode.single:
          break;
        case PlayMode.random:
          if (_audioPlayer.loopMode == LoopMode.off) {
            // 传递标志位
            playFromPlaylist(_getRandomIndex(currentIndex??0), isAutoSwitch: true);
          }
          break;
      }
    }
  }
  // ---- 歌词 ---
  void setLyrics(String? newLyrics){
    _lyrics = newLyrics;
    notifyListeners();
  }
  // ==== 保存歌单 ====
  void saveList() async{
    final List<Map<String,dynamic>> jsonList = _playlist.map((music)=>music.toJson()).toList();
    final String jsonString = jsonEncode(jsonList);
    final file = File(await storage.getPriFilePath('playlist/current.json'));
    file.writeAsString(jsonString);
    debugPrint('已存储');
  }
  // 播放单个音乐 - 确保先添加到播放
  Future<void> playMusic(Music music) async {
    try {
      int cur = -1;
      for(var i in _playlist){
        cur++;
        if (i.source==music.source&&i.id==music.id){
          debugPrint('试图添加已存在歌曲');
          playFromPlaylist(cur);
          return;
        }
      }
      _audioPlayer.stop();
      _playlist.add(music);
      saveList();
      _currentIndex = _playlist.length - 1;
      final audioUrl = await _getAudioUrl(music,playlist.length-1);
      await _audioPlayer.setAudioSource(AudioSource.uri(
          Uri.parse(audioUrl),
          tag: MediaItem(
              id: audioUrl,
              title: music.name,
              artist: music.artist,
              artUri: Uri.parse(music.pic)
          )
      ));
      await _audioPlayer.play();
      _isPlaying = true;

      notifyListeners();
    } catch (e) {
      print('播放错误: $e');
    }
  }

  // 从播放列表的指定索引播放
  Future<void> playFromPlaylist(int index, {bool isAutoSwitch = false,bool play=true}) async {
    print('播放$index');

    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      final music = _playlist[index];
      try {
        final audioUrl = await _getAudioUrl(music,index);
        print(audioUrl);
        await _audioPlayer.setAudioSource(AudioSource.uri(
            Uri.parse(audioUrl),
            tag: MediaItem(
              id: audioUrl,
              title: music.name,
              artUri: Uri.parse(music.pic),
              artist: music.artist,
            )
        ));
        await _audioPlayer.seek(Duration.zero);
        if(play){
        await _audioPlayer.play();
        _isPlaying = true;
        }
        if (isAutoSwitch) {
          _isSwitching = false;
        }

        notifyListeners();
      } catch (e) {
        print('播放错误: $e');
        if (isAutoSwitch) {
          _isSwitching = false;
        }
      }
    } else {
      if (isAutoSwitch) {
        _isSwitching = false;
      }
    }
  }

  Future<void> setPlaylist(List<Music> newPlaylist, {int initialIndex = 0}) async {
    _playlist = newPlaylist;
    _currentIndex = newPlaylist.isNotEmpty ? initialIndex : null;

    if (newPlaylist.isNotEmpty && initialIndex < newPlaylist.length) {
      await playFromPlaylist(initialIndex,play: false);
    }

    notifyListeners();
  }

  void togglePlaylist() {
    _showPlaylist = !_showPlaylist;
    notifyListeners();
  }

  void hidePlaylist() {
    _showPlaylist = false;
    notifyListeners();
  }
  
  void removeFromPlaylist(int index) {
    if (index >= 0 && index < _playlist.length) {
      final isRemovingCurrent = _currentIndex == index;

      _playlist.removeAt(index);

      if (isRemovingCurrent) {
        _currentIndex = null;
        _isPlaying = false;
        _audioPlayer.stop();

        if (_playlist.isNotEmpty) {
          if (index < _playlist.length) {
            playFromPlaylist(index);
          } else if (_playlist.isNotEmpty) {
            playFromPlaylist(_playlist.length - 1);
          }
        }
      } else if (_currentIndex != null && _currentIndex! > index) {
        // 如果删除的歌曲在当前播放歌曲之前，调整当前索引
        _currentIndex = _currentIndex! - 1;
      }

      notifyListeners();
    }
  }

  // Setters
  void setPlayMode(PlayMode mode) {
    _playMode = mode;

    // 设置 just_audio 的循环模式
    switch (mode) {
      case PlayMode.sequence:
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
      case PlayMode.single:
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
      case PlayMode.random:
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
    }

    notifyListeners();
  }

  void setIsPlaying(bool playing) async {
    if (playing) {
      await _audioPlayer.play();
    } else {
      await _audioPlayer.pause();
    }
    _isPlaying = playing;
    notifyListeners();
  }

  void setProgress(double progress) async {
    double safeProgress = progress.clamp(0.0, 1.0);
    _progress = safeProgress;

    final duration = _audioPlayer.duration;
    if (duration != null) {
      final position = duration * safeProgress;
      await _audioPlayer.seek(position);
    }
    notifyListeners();
  }

  // 设置音质 
  void setAudioQuality(AudioQuality quality) {
    _audioQuality = quality;
    notifyListeners();
  }

  // 设置音源 
  void setMusicSource(MusicSource source) {
    _musicSource = source;
    notifyListeners();
  }

  // 添加到播放列表但不播放 
  void addToPlaylist(Music music) {
    for(var i in _playlist){
      if (i.source==music.source&&i.id==music.id){
        debugPrint('试图添加已存在歌曲');
        return;
      }
    }
    _playlist.add(music);
    saveList();
    notifyListeners();
  }

  // 下一首 - 添加可选参数，供自动切换逻辑调用
  void nextMusic({bool isAutoSwitch = false}) {
    print('下一首111111111');
    if (_playlist.isEmpty || _currentIndex == null) {
      if (isAutoSwitch) _isSwitching = false; // 如果列表为空，自动切换标志重置
      return;
    }
    if (_playMode == PlayMode.random) {
      playFromPlaylist(_getRandomIndex(currentIndex??0), isAutoSwitch: true);
      return;
    }
    int nextIndex = (_currentIndex! + 1) % _playlist.length;
    playFromPlaylist(nextIndex, isAutoSwitch: isAutoSwitch);
  }

  // 上一首 - 使用索引指针 
  void previousMusic() {
    if (_playlist.isEmpty || _currentIndex == null) return;

    int prevIndex = _currentIndex!;

    switch (_playMode) {
      case PlayMode.sequence:
        prevIndex = (_currentIndex! - 1) % _playlist.length;
        if (prevIndex < 0) prevIndex = _playlist.length - 1;
        break;
      case PlayMode.single:
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.play();
        return;
      case PlayMode.random:
        prevIndex = _getRandomIndex(_currentIndex!);
        break;
    }

    _progress = 0.0;
    // 手动操作，不需要 isAutoSwitch: true
    playFromPlaylist(prevIndex);
  }

  int _getRandomIndex(int currentIndex) {
    if (_playlist.length <= 1) return 0;

    int randomIndex;
    do {
      randomIndex = DateTime.now().millisecond % _playlist.length;
    } while (randomIndex == currentIndex);
    return randomIndex;
  }

  // 获取音频URL的方法 
  Future<String> _getAudioUrl(Music music,int index) async {
    try {
      // 根据当前音质和音乐的音源设置构建请求参数
      final qualityCode = AudioQualityConfig.getCode(_audioQuality);

      // 使用音乐本身的source而不是全局source
      final musicSource = music.source ?? MusicSourceConfig.getCode(_musicSource);

      debugPrint('正在从$musicSource获取音质为${AudioQualityConfig.getName(_audioQuality)}的音频 URL - 歌曲: ${music.name}');


      return await _getMusicUrlFromPlugin(music, qualityCode);

    } catch (e) {
      print('获取音频URL错误: $e');
      // 临时示例 - 需要替换为实际的URL获取逻辑
      return "https://example.com/fallback-audio.mp3";
    }
  }

  Future<String> _getMusicUrlFromPlugin(Music music, String qualityCode) async {
    //try {
      //检查是否有已启用的插件
      JavascriptRuntime? runtime;
      final depends = r"""async function customFetch(url, options = {}) {
    const method = options.method || 'GET';
    const headers = options.headers || {};
    return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open(method, url);
        for (let key in headers) {
            if (Object.prototype.hasOwnProperty.call(headers, key)) {
                xhr.setRequestHeader(key, headers[key]);
            }
        }
        xhr.onload = () => {
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    const fixed = xhr.responseText
                                  .replace(/\n/g, '\\n')
                                  .replace(/\r/g, '\\r');
                    const data = JSON.parse(fixed);
                    resolve(JSON.stringify(data));
                } catch (e) {
                    reject(new Error('JSON解析错误: ' + e.message));
                }
            } else {
                reject(new Error('HTTP error! status: ' + xhr.status));
            }
        };
        xhr.onerror = () => reject(new Error('Network error'));
        xhr.send(options.body || null);
    });
}""";
      final pluginConfig = File(await storage.getPriFilePath('plugins/index.json'));
      if (!await pluginConfig.exists()) {
        debugPrint('不存在Plugin配置!');
        return 'xxx';
      }
      //json.decode(await pluginConfig.readAsString()
      final pluginConfigString = await pluginConfig.readAsString();
      debugPrint('???1');
      final List indexData = json.decode(pluginConfigString) as List;
      var index=-1,num=-1;
      for (var i in indexData) {
        num ++;
        if (i['enabled'] == true){
          debugPrint(i['name']);
          index = num;
          break;
        }
      }
      if (index==-1) {
        debugPrint('未找到插件,默认第一个');
        index = 0;
      }
      debugPrint('${_audioPlayer.androidAudioSessionId}');
      //debugPrint('222');
      final pluginCode = await File(await storage.getPriFilePath('plugins/${indexData[index]['uid']}.js')).readAsString();
      //debugPrint(pluginCode);
      runtime = getJavascriptRuntime(forceJavascriptCoreOnAndroid: false);
      runtime.evaluate(depends);
      runtime.evaluate(pluginCode);
      debugPrint(json.decode(runtime.evaluate('MusicPlugin.info').stringResult)['uid']);
      final pluginKey = File(await storage.getPriFilePath('plugins/${indexData[index]['uid']}.js.key'));
      String key = '';
      if(await pluginKey.exists()) {
        key = await pluginKey.readAsString();
        debugPrint('111$key');
      }
      debugPrint(music.id);
      final String callCode = 'MusicPlugin.getMusicUrl("${music.source}","${music.id}","$qualityCode","$key")';
      JsEvalResult jsResult = await runtime.evaluateAsync(callCode);
      runtime.executePendingJob();
      JsEvalResult asyncResult = await runtime.handlePromise(jsResult);
      debugPrint('获取成功:${asyncResult.stringResult}');
      //final test = runtime.evaluate('MusicPlugin.getLyric()').stringResult;
      //setLyrics(test);
      //获取歌词
      getAndSetLyrics(music.source,music.id);
      //await File(await storage.getPriFilePath('1.txt')).writeAsString(asyncResult.stringResult);
      return asyncResult.stringResult;
    }
  //}
  // 清理资源 
  Future<void> getAndSetLyrics(source,id) async {
    try {
      switch (source) {
        case 'wy':
          final resp = await http.get(Uri.parse(
          final data = json.decode(resp.body);
          final lrc = data['lrc']['lyric'];
          setLyrics(lrc);
          //debugPrint('获取成功');
          break;
        case 'kw':
          final resp = await http.get(Uri.parse(
          debugPrint(resp.body.trim());
          final lrc = kuwoParse(resp.body.trim());
          debugPrint(lrc);
          setLyrics(lrc);
          break;
        case 'tx':
          final resp = await http.get(Uri.parse
          ),
          if (resp.statusCode == 200) {
            final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
            debugPrint(jsonMap['lyric']);
            setLyrics(jsonMap['lyric']);
          } else {
            setLyrics('');
            throw Exception('Failed to fetch lyric: ${resp.statusCode}');
          }
          break;
        case 'kg':
          final resp = await http.get(Uri.parse(
          if (resp.statusCode == 200) {
            final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
            //debugPrint(jsonMap['lyric']);
            setLyrics(jsonMap['data']['encode']['context']);
          } else {
            setLyrics('');
            throw Exception('Failed to fetch lyric: ${resp.statusCode}');
          }
          break;
        default:
          setLyrics('');
          break;
      }
    } catch(_) {
      setLyrics('');
    }
  }
  String kuwoParse(String jsonStr) {
    final list = jsonDecode(jsonStr)['data']['lrclist'];

    final buffer = StringBuffer();
    for (final item in list) {
      final second = double.parse(item['time'].toString());
      final lyric  = item['lineLyric'].toString();

      // 秒 → 分:秒.百分
      final totalCent = (second * 100).round();
      final min       = (totalCent ~/ 6000).toString().padLeft(2, '0');
      final sec       = ((totalCent % 6000) ~/ 100).toString().padLeft(2, '0');
      final cent      = (totalCent % 100).toString().padLeft(2, '0');

      buffer.writeln('[$min:$sec.$cent]$lyric');
    }
    return buffer.toString();
  }
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
