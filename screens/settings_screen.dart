import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/player_provider.dart';
import '../models/music_model.dart';
import '../providers/storage_provider.dart';
import '../widgets/overlay.dart';
import 'plugin_manager_screen.dart';
bool isDark(){
  final context = globalNavigatorKey.currentContext;
  final themeProvider = context?.read<ThemeProvider>();
  return themeProvider?.isDarkMode??false;
}
String getSource(){
  final context = globalNavigatorKey.currentContext;
  final playerProvider = context!.read<PlayerProvider>();
  return MusicSourceConfig.getCode(playerProvider.musicSource);
}
String getQuality() {
  final context = globalNavigatorKey.currentContext;
  final playerProvider = context!.read<PlayerProvider>();
  return AudioQualityConfig.getCode(playerProvider.audioQuality);
}
Future<void> saveConfig() async{
  final globalConfigFile = File(await storage.getPriFilePath('config/global.json'));
  final Map<String,dynamic> saving_data = {
    'theme': isDark()?'dark':'light',
    'quality': getQuality(),
    'source': getSource(),
  };
  final encodedJson = json.encode(saving_data);
  await globalConfigFile.writeAsString(encodedJson);
  debugPrint('保存配置成功!');
}
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentMusic = playerProvider.currentMusic;
    final theme = Theme.of(context);

    //final bottomMargin = currentMusic != null ? 70.0 : 0.0;

    return PopScope(
        onPopInvokedWithResult: (bool didPop,details){
          if(didPop){
            debugPrint('111');
            saveConfig();
          }
          debugPrint('222');
        },
        child:Scaffold(
          appBar: AppBar(
            title: Text('设置'),
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                // 主题切换
                Card(
                  child: ListTile(
                    leading: Icon(
                      themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: themeProvider.isDarkMode ? Colors.amber : Colors.blue,
                    ),
                    title: Text(
                      '主题模式',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      themeProvider.isDarkMode ? '暗色主题' : '浅色主题',
                    ),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                      activeColor: Colors.blue,
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 音质设置
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.audiotrack,
                      color: Colors.green,
                    ),
                    title: Text(
                      '播放音质',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '当前: ${AudioQualityConfig.getName(playerProvider.audioQuality)}',
                    ),
                    trailing: DropdownButton<AudioQuality>(
                      value: playerProvider.audioQuality,
                      onChanged: (AudioQuality? newValue) {
                        if (newValue != null) {
                          playerProvider.setAudioQuality(newValue);

                          if (playerProvider.currentMusic != null && playerProvider.isPlaying) {
                            final currentMusic = playerProvider.currentMusic!;
                            playerProvider.playMusic(currentMusic);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已切换至${AudioQualityConfig.getName(newValue)}音质，正在重新加载'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                      dropdownColor: theme.cardColor, // 现在可以使用 theme 变量了
                      borderRadius: BorderRadius.circular(12), // 下拉菜单圆角
                      items: AudioQualityConfig.qualities.map<DropdownMenuItem<AudioQuality>>((AudioQuality quality) {
                        return DropdownMenuItem<AudioQuality>(
                          value: quality,
                          child: Text(AudioQualityConfig.getName(quality)),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 音源设置
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.music_note,
                      color: Colors.purple,
                    ),
                    title: Text(
                      '默认搜索',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '当前: ${MusicSourceConfig.getName(playerProvider.musicSource)}',
                    ),
                    trailing: DropdownButton<MusicSource>(
                      value: playerProvider.musicSource,
                      onChanged: (MusicSource? newValue) {
                        if (newValue != null) {
                          playerProvider.setMusicSource(newValue);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已切换至${MusicSourceConfig.getName(newValue)}，正在重新加载'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      dropdownColor: theme.cardColor,
                      borderRadius: BorderRadius.circular(12), // 下拉菜单圆角
                      items: MusicSourceConfig.sources.map<DropdownMenuItem<MusicSource>>((MusicSource source) {
                        return DropdownMenuItem<MusicSource>(
                          value: source,
                          child: Text(MusicSourceConfig.getName(source)),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 插件管理入口 (新添加的部分)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.extension),
                    title: Text('插件管理'),
                    subtitle: Text('管理已安装的扩展功能'),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // 使用 Navigator.push 导航到插件管理页面，实现流畅动画
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PluginManagerScreen()),
                      );
                    },
                  ),
                ),

                SizedBox(height: 16),

                // 音质说明
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '音质说明',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• 标准: 96kbps，适合普通网络\n'
                              '• 高品: 192kbps，提供更好音质\n'
                              '• 无损: FLAC格式，最佳音质体验',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 音源说明
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '音源说明',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• 搜索接口不过多赘述',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // 其他设置项
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('关于'),
                        subtitle: Text('QZ Music-1.3.1'),
                        onTap: () {
                          _showAboutDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
// 清泽音乐
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('关于'),
        content: Text('QZ Music-1.3.1\n\n作者: -蜻蜓T-T(B站)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
}