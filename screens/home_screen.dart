import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'my_screen.dart';
import 'playlist_screen.dart';
import 'search_screen.dart';
import '../widgets/now_playing_bar.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../models/music_model.dart';
import '../providers/player_provider.dart';
import '../models/daily_recommend_music.dart';
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomePage(),
    PlaylistScreen(),
    MyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentMusic = playerProvider.currentMusic;

    // 计算底部边距：如果正在播放音乐，需要为NowPlayingBar留出空间
    final bottomMargin = currentMusic != null ? 70.0 : 0.0;

    return Scaffold(
      body: SafeArea( // 添加SafeArea避开顶部系统状态栏
        child: Stack(
          children: [
            // 主要内容区域 - 添加底部边距避免被遮挡
            Padding(
              padding: EdgeInsets.only(bottom: bottomMargin),
              child: _screens[_currentIndex],
            ),
            // 底部播放栏
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: NowPlayingBar(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

// 主页页面 - 重构布局
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DailyRecommendMusic> _dailyRecommendations = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDailyRecommendations();
  }

  Future<void> _fetchDailyRecommendations() async {
    try {
      final response = await http.get(
        Uri.parse(''),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        setState(() {
          _dailyRecommendations =
              list.map((e) => DailyRecommendMusic.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        throw '网络异常 ${response.statusCode}';
      }
    } catch (e) {
      setState(() {
        _errorMessage = '获取失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏 - 移到顶部
            Container(
              padding: EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchScreen()),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: theme.textTheme.bodySmall?.color),
                      SizedBox(width: 8),
                      Text(
                        '搜索歌曲',
                        style: TextStyle(color: theme.textTheme.bodySmall?.color),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 每日推荐标题
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '每日推荐',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Spacer(),
                  if (!_isLoading && _dailyRecommendations.isNotEmpty)
                    Text(
                      '由迟言Api提供支持',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // 每日推荐列表
            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '加载每日推荐...',
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              )
                  : _errorMessage.isNotEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchDailyRecommendations,
                      child: Text('重试'),
                    ),
                  ],
                ),
              )
                  : _dailyRecommendations.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '暂无推荐歌曲',
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _dailyRecommendations.length,
                itemBuilder: (context, index) {
                  final m = _dailyRecommendations[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: theme.cardColor,
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          m.cover,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.music_note, size: 40),
                        ),
                      ),
                      title: Text(
                        m.songName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        m.songerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text('${index + 1}'),
                      onTap: () => _playDailyRecommendation(m, context),
                    ),
                  );
                },
              )
            ),
          ],
        ),
      ),
    );
  }


  void _playDailyRecommendation(DailyRecommendMusic dr, BuildContext context) {
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final music = Music.fromDailyRecommend(dr);
    player.playMusic(music);   // 内部已处理加入列表并播放
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在播放: ${music.name}')),
    );
  }
}

