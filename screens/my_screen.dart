import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import 'settings_screen.dart';
import '../providers/storage_provider.dart';
import 'package:http/http.dart' as http;
import '../widgets/overlay.dart';
import 'dart:convert';

Future<void> login(BuildContext context) async {
  // 添加确认弹窗
  final bool confirm = await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('提示'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. 登录功能需要跳转到QQ进行授权'),
            Text('2. 请确保已安装QQ客户端'),
            Text('3. 首次登录需要设置登录密钥'),
            Text('4. 我们会获取您的QQ号(用于验证)昵称+头像(用于显示)'),
            Text('5. 我们不会也无法获取您的任何额外信息'),
            SizedBox(height: 8),
            Text('是否继续登录?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );

  // 如果用户取消，直接返回
  if (confirm != true) {
    return;
  }

  GlobalLoadingOverlay.show(text: "正在获取登录信息");

  final codeString = await http.get(Uri.parse(
      'https://q.qq.com/ide/devtoolAuth/GetLoginCode'));
  GlobalLoadingOverlay.updateText!("打开授权中");
  final codeData = json.decode(codeString.body);
  final code = codeData['data']['code'];
  final loginUrl = "https://h5.qzone.qq.com/qqq/code/$code?_proxy=1&from=ide";
  final b64Url = base64.encode(utf8.encode(loginUrl));
  debugPrint(b64Url);
  debugPrint(loginUrl);
  final qqUrl = Uri.parse(
      'mqqapi://forward/url?version=1&src_type=web&url_prefix=${b64Url.replaceAll('=', '')}');
  debugPrint('mqqapi://forward/url?version=1&src_type=web&url_prefix=$b64Url');
  final resp =
  await launchUrl(qqUrl, mode: LaunchMode.externalApplication);
  debugPrint(resp == true ? '1' : '2');

  // 轮询获取 uin
  var uin = '';
  for (var i = 0; i < 120; i++) {
    final checkResp = await http.get(Uri.parse(
        'https://q.qq.com/ide/devtoolAuth/syncScanSateGetTicket?code=$code'));
    final checkData = json.decode(checkResp.body);
    if (checkData['data']?['uin'] != null &&
        checkData['data']?['uin'] != '') {
      uin = checkData['data']['uin'];
      final userVerifyFile = File(await storage.getPriFilePath('auth'));
      await userVerifyFile.writeAsString(uin);
      debugPrint('登录成功:$uin');
      GlobalLoadingOverlay.hide();
      // 弹出对话框，让用户输入 key
      final key = await showDialog<String>(
        context: context,
        barrierDismissible: false, // 用户必须输入
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('登录密钥'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('如是初次登录(注册)请设置一个'),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: '请输入登录密钥',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('跳过'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, controller.text.trim()),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );

      final userModel = context.read<UserModel>();
      await userModel.loginSuccess(uin: uin, key: key ?? '');
      break;
    }
    await Future.delayed(const Duration(seconds: 1));
  }
}

class MyScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    //final playerProvider = Provider.of<PlayerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('我的'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          child: Column(
            children: [
              // 用户信息块
              Container(
                padding: const EdgeInsets.all(16),
                child: Consumer<UserModel>(
                  builder: (_, user, __) => Row(
                    children: [
                      GestureDetector(
                        onTap: () => login(context),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(user.avatar),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nick,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 220),
                            child: Text(
                              user.signature,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                            ),),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 功能网格
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: EdgeInsets.all(16),
                  childAspectRatio: 1.2,
                  children: [
                    _buildFunctionItem('我的喜欢', Icons.favorite, Colors.red, context),
                    _buildFunctionItem('本地音乐', Icons.library_music, Colors.blue, context),
                    _buildFunctionItem('最近播放', Icons.history, Colors.green, context),
                    _buildFunctionItem('下载管理', Icons.download, Colors.orange, context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFunctionItem(String title, IconData icon, Color color, BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      color: theme.cardColor,
      child: InkWell(
        onTap: () {
          _showComingSoonSnackbar(context, title);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyLarge?.color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonSnackbar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 功能开发中...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}