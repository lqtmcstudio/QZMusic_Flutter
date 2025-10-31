import 'dart:convert';
import 'dart:io';
import '../widgets/overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import '../models/music_model.dart';
import '../models/user_model.dart';
import '../providers/player_provider.dart';
import '../providers/storage_provider.dart';
import 'playlist_detail_screen.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late Future<List<Map<String, dynamic>>> _futurePlaylists;
  final uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _futurePlaylists = _loadPlaylists();
  }

  // 加载歌单列表
  Future<List<Map<String, dynamic>>> _loadPlaylists() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final playlistIndexFile =
    File(await storage.getPriFilePath('playlist/index.json'));
    final List<Map<String, dynamic>> playlists = [];

    if (await playlistIndexFile.exists()) {
      final indexString = await playlistIndexFile.readAsString();
      final indexData = json.decode(indexString);

      for (var i2 in indexData) {
        final listName = i2['name'];
        final listDesc = i2['desc'];
        final i = i2['id'];
        final file = File(await storage.getPriFilePath('playlist/$i.json'));
        if (!await file.exists()) continue;

        final listData = json.decode(await file.readAsString());
        final List<Music> currentList = (listData as List)
            .map((jsonItem) => Music.fromJson(jsonItem as Map<String, dynamic>))
            .toList();

        playlists.add({
          'id': i,
          'name': listName ?? '歌单',
          'desc': listDesc ?? '无描述',
          'songs': currentList,
        });
      }
    }

    return playlists;
  }

  // 导入歌单
  Future<void> _importPlaylist(BuildContext context) async {
    final result = await _showImportDialog(context);

    if (result == null) return;

    final platform = result['platform'];
    final input = result['input'];

    if (input!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的链接或ID!')),
      );
      return;
    }

    GlobalLoadingOverlay.show(text: '正在解析歌单');

    String apiUrl;
    String playlistName = '用户导入';
    String playlistDesc = '导入的歌单';
    String source;

    if (platform == 'qq') {
      // QQ 音乐：用户输入 URL
      apiUrl = 'https://cyapi.top/API/song_list.php?url=$input';
      source = 'tx';
    } else if (platform == 'netease') {
      // 网易云音乐：用户输入 ID
      apiUrl = 'https://oiapi.net/api/NeteasePlaylistDetail?id=$input';
      source = 'wy';
    } else {
      GlobalLoadingOverlay.updateText!('❌不支持的平台');
      await Future.delayed(const Duration(seconds: 1));
      GlobalLoadingOverlay.hide();
      return;
    }

    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        GlobalLoadingOverlay.updateText!('❌网络请求失败: ${response.statusCode}');
        await Future.delayed(const Duration(seconds: 2));
        GlobalLoadingOverlay.hide();
        return;
      }

      final dynamic responseData = json.decode(response.body);
      List<Music> musicList = [];
      String listNameFromApi = '';

      if (platform == 'qq') {
        // QQ 音乐格式解析
        if (responseData is Map) {
          final List songList = responseData['song_list'];
          // 尝试从列表中第一首歌获取歌单名字（如果API提供）

          musicList = songList.map((item) {
            return Music(
              id: item['mid'] as String? ?? uuid.v4(),
              source: source,
              name: item['name'] as String? ?? '未知歌曲',
              artist: item['singer'],
              pic: item['cover'],
            );
          }).toList();
        }
      } else if (platform == 'netease') {
        // 网易云音乐格式解析
        debugPrint('1111');
        if (responseData is Map) {
          debugPrint('222');
          final List songList = responseData['data'];

          for (var item in songList) {
            if (item['name'] == null) {
              print('!!! 遇到缺少关键参数的歌曲，ID: ${item['id']}，停止处理。');
              break;
            }


            // 提取歌手信息
            final artists = (item['artists'] != null && item['artists'] is List)
                ? (item['artists'] as List)
                .map((a) => a['name'])
                .whereType<String>()
                .join(' / ')
                : '未知歌手';

            // 创建 Music 对象
            final musicItem = Music(
              id: item['id']?.toString() ?? uuid.v4(),
              source: source,
              name: item['name'] as String? ?? '未知歌曲',
              artist: artists??'',
              pic: item['cover'],
            );
            debugPrint(musicItem
            .name);
            // 将对象添加到结果列表
            musicList.add(musicItem);

            // 你的调试输出 (如果你仍然需要的话)
            debugPrint('!!!!');
          }
        }
      }
      if (musicList.isEmpty) {
        GlobalLoadingOverlay.updateText!('❌歌单解析失败或歌单为空!');
        await Future.delayed(const Duration(seconds: 2));
        GlobalLoadingOverlay.hide();
        return;
      }


      // 1. 更新 index.json
      final indexFile = File(await storage.getPriFilePath('playlist/index.json'));
      List<dynamic> indexData = [];
      if (await indexFile.exists()) {
        try {
          indexData = json.decode(await indexFile.readAsString());
        } catch (_) {
          indexData = [];
        }
      } else {
        final dir = indexFile.parent;
        if (!await dir.exists()) await dir.create(recursive: true);
      }

      final newId = uuid.v4();
      indexData.add({'id': newId, 'name': playlistName, 'desc': playlistDesc});
      await indexFile.writeAsString(json.encode(indexData), flush: true);

      // 2. 写入歌单内容文件
      final playlistFile = File(await storage.getPriFilePath('playlist/$newId.json'));
      final List<Map<String, dynamic>> musicJsonList = musicList.map((m) => m.toJson()).toList();
      await playlistFile.writeAsString(json.encode(musicJsonList), flush: true);

      GlobalLoadingOverlay.updateText!('歌单导入成功 (${musicList.length} 首)');
      await Future.delayed(const Duration(seconds: 2));

      // 3. 重新加载列表
      setState(() {
        _futurePlaylists = _loadPlaylists();
      });

    } catch (e) {
      debugPrint('导入歌单时发生错误: $e');
      GlobalLoadingOverlay.updateText!('❌导入失败: $e');
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      GlobalLoadingOverlay.hide();
    }
  }


  // 导入对话框
  Future<Map<String, String>?> _showImportDialog(BuildContext context) async {
    String? platform = 'netease'; // 默认选中网易云
    final controller = TextEditingController();

    return showDialog<Map<String, String>?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('导入歌单'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择平台:'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ChoiceChip(
                        label: const Text('网易云'),
                        selected: platform == 'netease',
                        onSelected: (selected) {
                          setState(() => platform = 'netease');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('QQ音乐'),
                        selected: platform == 'qq',
                        onSelected: (selected) {
                          setState(() => platform = 'qq');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: platform == 'netease' ? '请输入歌单ID' : '请输入歌单分享链接(URL)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final input = controller.text.trim();
                    if (input.isNotEmpty && platform != null) {
                      Navigator.pop(context, {'platform': platform!, 'input': input});
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入内容')),
                      );
                    }
                  },
                  child: const Text('导入'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadPlaylist(BuildContext context) async{
    final userModel = context.read<UserModel>();
    if (userModel.nick == '点击以登录'){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录!')),
      );
      return;
    }
    GlobalLoadingOverlay.show(text:'获取信息中');
    final response = await http.get(Uri.parse('https://cyapi.top/appdata/user/${userModel.uin}/index.json'));
    if (response.statusCode == 200){
      List indexData;
      try {
        indexData = json.decode(response.body) as List;
      } catch(e) {
        GlobalLoadingOverlay.updateText!('❌歌单为空或网络错误!');
        debugPrint(response.body);
        debugPrint('$e');
        await Future.delayed(Duration(seconds: 1));
        GlobalLoadingOverlay.hide();
        return;
      }
      await File(await storage.getPriFilePath('playlist/index.json')).writeAsString(response.body);
      for (var i=0;i<indexData.length;i++) {
        final index=indexData[i];
        GlobalLoadingOverlay.updateText!('获取歌单中(${i+1}/${indexData.length})');
        try {
          final resp = await http.get(Uri.parse('https://cyapi.top/appdata/user/${userModel.uin}/${index['id'].replaceAll('-','')}.json'));
          if (resp.statusCode == 200) {
            await File(await storage.getPriFilePath('playlist/${index['id']}.json')).writeAsString(resp.body);
          } else {
            debugPrint('!!!!!错误${resp.statusCode}');
            GlobalLoadingOverlay.updateText!('获取${i+1}歌单错误!跳过');
            await Future.delayed(Duration(seconds: 1));
            debugPrint('111');
            continue;
          }
        } catch (e) {
          debugPrint('!!!!!!!$e');
          GlobalLoadingOverlay.updateText!('获取${i+1}歌单错误!跳过');
          await Future.delayed(Duration(seconds: 1));
          continue;
        }
      }
    } else {
      GlobalLoadingOverlay.updateText!('❌不存在云歌单!');
      await Future.delayed(Duration(seconds: 2));
    }
    GlobalLoadingOverlay.hide();
    // 重新加载列表
    setState(() {
      _futurePlaylists = _loadPlaylists();
    });
    return;
  }

  Future<void> _uploadPlaylist(BuildContext context) async{
    final userModel = context.read<UserModel>();
    if (userModel.nick == '点击以登录'){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录!')),
      );
      return;
    }
    GlobalLoadingOverlay.show(text:'上传信息中');
    var indexString = '';
    try{
      indexString = await File(await storage.getPriFilePath('playlist/index.json')).readAsString();
      if (indexString.isEmpty){
        GlobalLoadingOverlay.updateText!('不存在歌单!');
        return;
      }
    } catch(e){
      await Future.delayed(Duration(seconds: 1));
      GlobalLoadingOverlay.hide();
      debugPrint('$e');
      return;
    }
    final uploadUri = 'https://cyapi.top/appdata/user/upload.php';
    final List<int> indexBytes = utf8.encode(indexString);
    final response = await http.post(
      Uri.parse(uploadUri),
      body: json.encode({
        'file_name': 'index',
        'content': base64.encode(indexBytes),
        'uin': userModel.uin,
        'key': userModel.key,
      }),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200){
      final respData = json.decode(response.body);
      if (respData['ok']??false == true){
        GlobalLoadingOverlay.updateText!('上传索引成功');
        final indexData = json.decode(indexString) as List;
        for (var ii=0;ii<indexData.length;ii++) {
          //处理每个歌单上传
          final i=indexData[ii];
          try {
            debugPrint('???');
            final id = i['id'];
            if (id == null){
              GlobalLoadingOverlay.updateText!('❌网络异常!');
              await Future.delayed(Duration(seconds: 2));
              GlobalLoadingOverlay.hide();
              return;
            }
            //上传
            GlobalLoadingOverlay.updateText!('上传歌单中(${ii+1}/${indexData.length})');
            var listString = '';
            try{
              listString = await File(await storage.getPriFilePath('playlist/$id.json')).readAsString();
            } catch(_){
              GlobalLoadingOverlay.updateText!('❌歌单${ii+1}获取失败!跳过');
              await Future.delayed(Duration(milliseconds: 800));
              GlobalLoadingOverlay.hide();
              continue;
            }
            final List<int> listBytes = utf8.encode(listString);
            final resp = await http.post(
              Uri.parse(uploadUri),
              body: json.encode({
                'file_name': '${id.replaceAll('-','')}',
                'content': base64.encode(listBytes),
                'uin': userModel.uin,
                'key': userModel.key,
              }),
            );
            debugPrint('$id');
            if (resp.statusCode==200) {
              final jsonData = json.decode(resp.body);
              if (jsonData['ok']==true){
                debugPrint('上传${ii+1}成功!');
                continue;
              }
            } else {
              debugPrint(resp.body);
            }
            GlobalLoadingOverlay.updateText!('❌上传歌单${ii+1}失败,跳过...');
            await Future.delayed(Duration(seconds: 2));
            print('111');
            continue;
          } catch(e) {
            GlobalLoadingOverlay.updateText!('❌网络异常!');
            debugPrint('$e');
            await Future.delayed(Duration(seconds: 2));
            GlobalLoadingOverlay.hide();
            return;
          }
        }
      } else {
        GlobalLoadingOverlay.updateText!('❌key校验失败!');
      }
    } else {
      GlobalLoadingOverlay.updateText!('❌文件过长或网络异常!');
      await Future.delayed(Duration(seconds: 2));
    }
    GlobalLoadingOverlay.hide();
    return;
  }
  // 创建歌单
  Future<void> _createPlaylist() async {
    final indexFile =
    File(await storage.getPriFilePath('playlist/index.json'));

    String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('创建新歌单'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '请输入歌单名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context, name);
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty) return;

    List<dynamic> indexData = [];
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        indexData = json.decode(content);
      } catch (_) {
        indexData = [];
      }
    } else {
      // 确保目录存在
      final dir = indexFile.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
    }

    final newId = uuid.v4();
    indexData.add({'id': newId, 'name': newName, 'desc': '暂无描述'});

    await indexFile.writeAsString(json.encode(indexData), flush: true);

    // 同时创建对应的空歌单文件
    final playlistFile =
    File(await storage.getPriFilePath('playlist/$newId.json'));
    await playlistFile.writeAsString(json.encode([]), flush: true);

    // 重新加载列表
    setState(() {
      _futurePlaylists = _loadPlaylists();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('歌单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: '上传',
            onPressed: () async{
              _uploadPlaylist(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: '下载',
            onPressed: () async{
              _downloadPlaylist(context);
            },
          ),
          // 新增的导入按钮
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            tooltip: '导入歌单',
            onPressed: () => _importPlaylist(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '创建歌单',
            onPressed: _createPlaylist,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futurePlaylists,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '加载失败：${snapshot.error}',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              );
            }

            final playlists = snapshot.data ?? [];
            if (playlists.isEmpty) {
              return const Center(child: Text('暂无歌单'));
            }

            return ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: theme.cardColor,
                  child: ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(
                      playlist['name'] ?? '未知歌单',
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    ),
                    subtitle: Text(
                      playlist['desc'] ?? '',
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        PlaylistDetailScreen.route(
                          name: playlist['name'],
                          desc: playlist['desc'],
                          cover: playlist['cover'],
                          songs: playlist['songs'],
                        ),
                      );
                    },
                    onLongPress: () => _showPlaylistMenu(context, playlist),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<String?> _editTextDialog(
      BuildContext context, {
        required String title,
        String? initialValue,
      }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '请输入内容'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPlaylistMenu(BuildContext context, Map<String, dynamic> playlist) async {
    final indexFile = File(await storage.getPriFilePath('playlist/index.json'));
    final indexString = await indexFile.readAsString();
    List<dynamic> indexData = json.decode(indexString);

    final String playlistId = playlist['id'] ?? ''; // 确保索引中有 id
    if (playlistId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('修改歌单名称'),
                onTap: () async {
                  Navigator.pop(context);
                  final newName = await _editTextDialog(
                    context,
                    title: '修改歌单名称',
                    initialValue: playlist['name'],
                  );
                  if (newName != null && newName.isNotEmpty) {
                    // 更新索引
                    for (var p in indexData) {
                      if (p['id'] == playlistId) {
                        p['name'] = newName;
                      }
                    }
                    await indexFile.writeAsString(json.encode(indexData), flush: true);
                    setState(() {
                      _futurePlaylists = _loadPlaylists();
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('修改歌单描述'),
                onTap: () async {
                  Navigator.pop(context);
                  final newDesc = await _editTextDialog(
                    context,
                    title: '修改歌单描述',
                    initialValue: playlist['desc'],
                  );
                  if (newDesc != null && newDesc.isNotEmpty) {
                    for (var p in indexData) {
                      if (p['id'] == playlistId) {
                        p['desc'] = newDesc;
                      }
                    }
                    await indexFile.writeAsString(json.encode(indexData), flush: true);
                    setState(() {
                      _futurePlaylists = _loadPlaylists();
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除歌单', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('确认删除'),
                      content: Text('确定要删除歌单 “${playlist['name']}” 吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('删除', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  // 删除对应文件和索引记录
                  indexData.removeWhere((p) => p['id'] == playlistId);
                  await indexFile.writeAsString(json.encode(indexData), flush: true);

                  final file = File(await storage.getPriFilePath('playlist/$playlistId.json'));
                  if (await file.exists()) await file.delete();

                  setState(() {
                    _futurePlaylists = _loadPlaylists();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
