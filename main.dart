import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/music_model.dart';
import 'models/user_model.dart';
import 'providers/player_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'dart:io';
import 'package:flutter_protector/flutter_protector.dart';
import 'widgets/overlay.dart';
import 'providers/storage_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_package_installer/android_package_installer.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
        androidNotificationChannelId:"love.lqt.music.channel",
        androidNotificationChannelName: "QZ Music",
        androidNotificationOngoing: false,
        androidShowNotificationBadge: false
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  checkSecurityEnvironment();
  runApp(MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) async{
    await applyLocalSettings();
    await checkUpdate();
  });
}
void checkSecurityEnvironment() async{
  debugPrint('检查安全信息');
  final flutterProtector = FlutterProtector();
  bool isVpn = await flutterProtector.isVpnConnected()??true;
  bool isRoot = await flutterProtector.isDeviceRooted()??true;
  bool isBluestack = await flutterProtector.isBlueStacks()??true;
  if(isVpn||isRoot||isBluestack){
    _exitApp();
  }
}
//123盘解析param
String? queryParam(String url, String key) {
  // 1. 找到 query 起点
  final q = url.indexOf('?');
  if (q == -1) return null;
  final query = url.substring(q + 1); // 去掉 '?'

  // 2. 按 & 拆分
  for (final kv in query.split('&')) {
    final pos = kv.indexOf('=');
    if (pos == -1) continue;
    final k = kv.substring(0, pos);
    final v = kv.substring(pos + 1);
    if (k == key) return v; // 找到即返回
  }
  return null;
}

void _exitApp() {
  SystemNavigator.pop(animated: true);
  exit(0);
}
Future<void> applyLocalSettings() async{
  try {
    final context = globalNavigatorKey.currentContext;
    final themeProvider = context!.read<ThemeProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final userModel = context.read<UserModel>();
    final globalConfigFile = File(await storage.getPriFilePath('config/global.json'));
    final currentPlaylist = File(await storage.getPriFilePath('playlist/current.json'));
    final authFile = File(await storage.getPriFilePath('auth'));
    if (!await globalConfigFile.exists()) {
      debugPrint('不存在全局配置,Skipping...');
    } else {
      String globalConfigJson = await globalConfigFile.readAsString();
      final tempData = json.decode(globalConfigJson);
      if(tempData['source']!=null && tempData['theme']!=null){
        switch(tempData['source']){
          case 'kw':
            playerProvider.setMusicSource(MusicSource.source1);
          case 'wy':
            playerProvider.setMusicSource(MusicSource.source2);
          case 'tx':
            playerProvider.setMusicSource(MusicSource.source3);
          case 'mg':
            playerProvider.setMusicSource(MusicSource.source4);
          case 'kg':
          default:
            playerProvider.setMusicSource(MusicSource.source5);
        }
        if (tempData['theme'] == 'dark'){
          themeProvider.setThemeMode(ThemeMode.dark);
        }
        if (tempData['quality']!=null) {
          final q = tempData['quality'];
          switch(q) {
          case 'standard':
            playerProvider.setAudioQuality(AudioQuality.standard);
          case 'exhigh':
            playerProvider.setAudioQuality(AudioQuality.high);
          case 'lossless':
            playerProvider.setAudioQuality(AudioQuality.lossless);
          case 'lossless+':
            playerProvider.setAudioQuality(AudioQuality.lossless24bit);
          case 'hires':
            playerProvider.setAudioQuality(AudioQuality.hires);
          case 'atmos':
            playerProvider.setAudioQuality(AudioQuality.atmos);
          case 'master':
          default:
            playerProvider.setAudioQuality(AudioQuality.master);
          }
        }
      } else {
        debugPrint(json.encode(tempData));
      }
    }
    if (await currentPlaylist.exists()) {
      final dataString = await currentPlaylist.readAsString();
      final List<dynamic> docodedCurrentList = jsonDecode(dataString);
      final List<Music> currentList = docodedCurrentList.map((jsonItem){
        return Music.fromJson(jsonItem as Map<String,dynamic>);
      }).toList();
      playerProvider.setPlaylist(currentList);
    }
    if (await authFile.exists()) {
      final authString = await authFile.readAsString();
      final keyString = await File(await storage.getPriFilePath('key')).readAsString();
      userModel.loginSuccess(uin: authString,key: keyString);
    }
    //测试JS Runtime
  } catch(e) {
    debugPrint('$e');
  }
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PlayerProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserModel()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'QZ Music',
            navigatorKey: globalNavigatorKey,
            theme: ThemeData  (
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.white,
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: Colors.black87),
                bodyMedium: TextStyle(color: Colors.black87),
                bodySmall: TextStyle(color: Colors.grey[600]),
                titleLarge: TextStyle(color: Colors.black87),
                titleMedium: TextStyle(color: Colors.black87),
                titleSmall: TextStyle(color: Colors.black87),
                labelLarge: TextStyle(color: Colors.black87),
                labelMedium: TextStyle(color: Colors.black87),
                labelSmall: TextStyle(color: Colors.grey[600]),
              ),
            ),
            darkTheme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.grey[900],
              cardTheme: CardThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.grey[800],
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.grey[900],
                elevation: 0,
              ),
              listTileTheme: ListTileThemeData(
                tileColor: Colors.grey[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              dialogBackgroundColor: Colors.grey[800],
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white),
                bodySmall: TextStyle(color: Colors.grey[400]),
                titleLarge: TextStyle(color: Colors.white),
                titleMedium: TextStyle(color: Colors.white),
                titleSmall: TextStyle(color: Colors.white),
                labelLarge: TextStyle(color: Colors.white),
                labelMedium: TextStyle(color: Colors.white),
                labelSmall: TextStyle(color: Colors.grey[400]),
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: HomeScreen(),
          );
        },
      ),
    );
  }
}