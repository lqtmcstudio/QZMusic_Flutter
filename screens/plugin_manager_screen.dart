// plugin_manager_screen.dart (修复和新增删除功能后的文件)
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import '../providers/storage_provider.dart';
import 'package:http/http.dart' as http;

class PluginManagerScreen extends StatefulWidget {
  @override
  _PluginManagerScreenState createState() => _PluginManagerScreenState();
}

class _PluginManagerScreenState extends State<PluginManagerScreen> {
  // 插件列表，用于构建 UI
  List<dynamic> _plugins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  // 模拟加载插件列表的 async 函数
  Future<void> _loadPlugins() async {
    setState(() {
      _isLoading = true;
    });
    List<Map<String, dynamic>> plugins = [];
    debugPrint('开始加载插件列表...');

    // 解析 Map 并 build UI 界面
    // 假设 storage 变量在 storage_provider.dart 中已定义
    final indexFile = File(await storage.getPriFilePath('plugins/index.json'));
    if (!await indexFile.exists()) {
      plugins = [];
    } else {
      final indexString = await indexFile.readAsString();
      if (indexString.isEmpty) {
        plugins = [];
      } else {
        try {
          List<dynamic> decoded = json.decode(indexString);
          plugins = decoded
              .whereType<Map<String, dynamic>>()   // 只保留 Map 元素
              .toList();
        } catch(e) {
          debugPrint('插件索引文件解析错误: $e');
          plugins = [];
        }
      }
    }

    // 模拟延迟，确保看到加载状态
    await Future.delayed(Duration(milliseconds: 300));

    setState(() {
      _plugins = plugins;
      _isLoading = false;
    });

    debugPrint('插件列表加载并解析完成，共 ${_plugins.length} 个插件。');
  }

  // 模拟安装插件的 async 函数
  Future<void> _installPlugin(BuildContext context) async {
    // 假设 pickFile() 函数已实现
    final jsString = await pickFile();
    debugPrint(jsString);
    if (jsString == null || jsString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('未选择文件或文件为空'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    List<dynamic> indexData = [];
    final indexFile = File(await storage.getPriFilePath('plugins/index.json'));
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        indexData = json.decode(content);
      } catch (_) {
        // 如果解析失败，则从空列表开始
        indexData = [];
      }
    } else {
      final dir = indexFile.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
    }
    try {
      //尝试安装
      JavascriptRuntime? runtime;
      runtime = getJavascriptRuntime(forceJavascriptCoreOnAndroid: false);
      final dependsCode = r"""async function customFetch(url, options = {}) {
    const method = options.method || 'GET';
    const headers = options.headers || {};

    return new Promise((resolve, reject) => {
        // 假设 XMLHttpRequest 在 QuickJS 环境中可用
        const xhr = new XMLHttpRequest();
        xhr.open(method, url);

        for (let key in headers) {
            // 确保只设置非继承属性
            if (Object.prototype.hasOwnProperty.call(headers, key)) {
                xhr.setRequestHeader(key, headers[key]);
            }
        }

        xhr.onload = () => {
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    // 尝试解析JSON并返回 JSON 字符串
                    const data = JSON.parse(xhr.responseText);
                    resolve(JSON.stringify(data));
                } catch (e) {
                    reject(new Error('JSON解析错误: ' + e.message));
                }
            } else {
                reject(new Error('HTTP error! status: ' + xhr.status));
            }
        };

        xhr.onerror = () => reject(new Error('Network error'));

        // 发送请求体 (GET请求通常为null)
        xhr.send(options.body || null);
    });
}""";
      runtime.evaluate(dependsCode);
      runtime.evaluate(jsString);
      final info = json.decode(runtime.evaluate('MusicPlugin.info').stringResult);
      for (var i in indexData) {
        if (i['uid'] == info['uid']) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已安装相同插件!'),duration: Duration(seconds:3),));
          return;
        }
      }
      indexData.add({
        "uid":info['uid'],
        "name":info['name'],
        "version":info['version'],
        "support":info['support'],
        "description": info['description'],
        "enabled": false, // 默认禁用
      });
      await indexFile.writeAsString(json.encode(indexData),flush: true);

      // 模拟将插件JS文件写入本地
      final pluginFile = File(await storage.getPriFilePath('plugins/${info['uid']}.js'));
      await pluginFile.writeAsString(jsString, flush: true);

    } catch(e) {
      debugPrint('插件安装失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('插件安装失败: $e'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    await _loadPlugins();
    return;
  }
  Future<void> _installPluginFromUrl(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网址不能为空'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在从 $url 下载插件...'),
        duration: Duration(seconds: 5),
      ),
    );

    String? jsString;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        jsString = utf8.decode(response.bodyBytes); // 确保正确处理编码
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('插件下载失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('插件下载失败: $e'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (jsString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载文件为空'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 接下来的安装逻辑与 _installPlugin 相同
    List<dynamic> indexData = [];
    // **注意：由于 storage 已全局声明，这里直接使用**
    final indexFile = File(await storage.getPriFilePath('plugins/index.json'));
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        indexData = json.decode(content);
      } catch (_) {
        indexData = [];
      }
    } else {
      final dir = indexFile.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
    }

    try {
      // 尝试安装
      JavascriptRuntime? runtime;
      // 使用现有的运行时获取插件信息
      runtime = getJavascriptRuntime(forceJavascriptCoreOnAndroid: false);

      // 依赖代码 (需要确保 customFetch 函数在环境中)
      final dependsCode = r"""async function customFetch(url, options = {}) {
    const method = options.method || 'GET';
    const headers = options.headers || {};

    return new Promise((resolve, reject) => {
        // 假设 XMLHttpRequest 在 QuickJS 环境中可用
        const xhr = new XMLHttpRequest();
        xhr.open(method, url);

        for (let key in headers) {
            // 确保只设置非继承属性
            if (Object.prototype.hasOwnProperty.call(headers, key)) {
                xhr.setRequestHeader(key, headers[key]);
            }
        }

        xhr.onload = () => {
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    // 尝试解析JSON并返回 JSON 字符串
                    const data = JSON.parse(xhr.responseText);
                    resolve(JSON.stringify(data));
                } catch (e) {
                    reject(new Error('JSON解析错误: ' + e.message));
                }
            } else {
                reject(new Error('HTTP error! status: ' + xhr.status));
            }
        };

        xhr.onerror = () => reject(new Error('Network error'));

        // 发送请求体 (GET请求通常为null)
        xhr.send(options.body || null);
    });
}""";
      runtime.evaluate(dependsCode);
      runtime.evaluate(jsString);
      final info = json.decode(runtime.evaluate('MusicPlugin.info').stringResult);

      for (var i in indexData) {
        if (i['uid'] == info['uid']) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已安装相同插件!'),duration: Duration(seconds:3),));
          return;
        }
      }

      indexData.add({
        "uid":info['uid'],
        "name":info['name'],
        "version":info['version'],
        "support":info['support'],
        "description": info['description'],
        "enabled": false, // 默认禁用
      });
      await indexFile.writeAsString(json.encode(indexData),flush: true);

      // 模拟将插件JS文件写入本地
      final pluginFile = File(await storage.getPriFilePath('plugins/${info['uid']}.js'));
      await pluginFile.writeAsString(jsString, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('插件 ${info['name']} 安装成功!'),
          duration: Duration(seconds: 3),
        ),
      );

    } catch(e) {
      debugPrint('插件安装失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('插件安装失败: $e'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    await _loadPlugins();
    return;
  }
  Future<void> _startPlugin(String uid) async{
    final indexFile = File(await storage.getPriFilePath('plugins/index.json'));
    List<dynamic> indexData = [];
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        indexData = json.decode(content);
      } catch (_) {
        return;
      }

      // 禁用所有其他插件，确保只有一个插件被启用
      for (var i in indexData) {
        if (i['uid'] == uid) {
          i['enabled'] = true;
        } else {
          i['enabled'] = false;
        }
      }

      await indexFile.writeAsString(json.encode(indexData),flush: true);
    }
    await _loadPlugins(); // 确保状态更新
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('插件已启用!'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }

  Future<void> _stopPlugin(String uid) async {
    final indexFile = File(await storage.getPriFilePath('plugins/index.json'));
    List<dynamic> indexData = [];
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        indexData = json.decode(content);
      } catch (_) {
        return;
      }
      for (var i in indexData) {
        if (i['uid'] == uid) {
          i['enabled'] = false;
          break;
        }
      }
      // 写入配置
      await indexFile.writeAsString(json.encode(indexData),flush: true);
    } else {
      return;
    }
    await _loadPlugins();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('插件已禁用!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 新增：删除插件的 async 函数
  Future<void> _deletePlugin(Map<String, dynamic> plugin) async {
    final uid = plugin['uid'];
    try {
      await _stopPlugin(uid);
    } catch(e) {
      debugPrint('禁用插件失败：$e');
    }
    final indexFile = File(await storage.getPriFilePath('plugins/index.json'));
    List<dynamic> indexData = [];
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        indexData = json.decode(content);
        indexData.removeWhere((item) => item is Map && item['uid'] == uid);
        await indexFile.writeAsString(json.encode(indexData),flush: true);
      } catch (e) {
        debugPrint('删除插件时更新索引失败: $e');
      }
    }
    try {
      final pluginFile = File(await storage.getPriFilePath('plugins/$uid.js'));
      if (await pluginFile.exists()) {
        await pluginFile.delete();
        debugPrint('插件文件 $uid.js 已删除');
      }
      // 尝试删除配置key文件
      final keyFile = File(await storage.getPriFilePath('plugins/$uid.js.key'));
      if (await keyFile.exists()) {
        await keyFile.delete();
        debugPrint('插件配置 key 文件 $uid.json 已删除');
      }
    } catch(e) {
      debugPrint('删除插件文件或配置失败: $e');
    }
    await _loadPlugins();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('插件 ${plugin['name']} 已删除!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // **新增：配置插件 Key 的 async 函数**
  Future<void> _configurePluginKey(String uid, String key) async {
    try {
      // 写入文件 plugins/${uid}.json，内容格式为 {"key": "用户输入的key"}
      final keyFile = File(await storage.getPriFilePath('plugins/$uid.js.key'));
      // 确保目录存在
      if (!await keyFile.parent.exists()) {
        await keyFile.parent.create(recursive: true);
      }

      await keyFile.writeAsString(key, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('插件 Key 配置成功!'),
          duration: Duration(seconds: 2),
        ),
      );
      debugPrint('插件 $uid 的 Key 已写入: $key');
    } catch (e) {
      debugPrint('写入插件 Key 失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('插件 Key 配置失败: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  void _showInstallFromUrlDialog(BuildContext context) {
    final TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('在线导入插件'),
          content: TextField(
            controller: urlController,
            decoration: InputDecoration(
              hintText: "输入插件JS文件网址 (例如: http://example.com/plugin.js)",
            ),
            autofocus: true,
            keyboardType: TextInputType.url,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('导入'),
              onPressed: () {
                final url = urlController.text.trim();
                Navigator.of(dialogContext).pop(); // 关闭对话框
                if (url.isNotEmpty) {
                  _installPluginFromUrl(context, url);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('网址不能为空'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
  // **新增：配置 Key 对话框**
  void _showKeyConfigurationDialog(BuildContext context, Map<String, dynamic> plugin) {
    final TextEditingController keyController = TextEditingController();
    final String uid = plugin['uid'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('输入 ApiKey: ${plugin['name']}'),
          content: TextField(
            controller: keyController,
            decoration: InputDecoration(
              hintText: "如果不存在请跳过",
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('跳过'),
              onPressed: () {
                Navigator.of(dialogContext).pop(null); // 返回 null 表示跳过
              },
            ),
            TextButton(
              child: Text('确定'),
              onPressed: () {
                // 返回用户输入的 key (如果非空)
                Navigator.of(dialogContext).pop(keyController.text.trim());
              },
            ),
          ],
        );
      },
    ).then((result) {
      if (result is String) {
        final String key = result;
        if (key.isNotEmpty) {
          _configurePluginKey(uid, key);
        } else {
          // 用户点击确定，但输入框为空，提示用户可以跳过
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('输入为空，已跳过配置。'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (result == null) {
        // 用户点击跳过或取消
        // 可选：在这里处理"跳过"的逻辑，例如提示用户
      }
    });

    // 异步加载 Key 并更新输入框
    () async {
      try {
        final keyFile = File(await storage.getPriFilePath('plugins/$uid.js.key'));
    if (await keyFile.exists()) {
    final content = await keyFile.readAsString();
    keyController.text = content;
    } else {
    debugPrint('1111');
    }
    } catch (e) {
    debugPrint('加载插件 Key 失败: $e');
    }
  }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('插件管理'),
        actions: [
          // 新增：在线导入按钮
          IconButton(
            icon: Icon(Icons.download), // 使用下载图标
            onPressed: () => _showInstallFromUrlDialog(context),
            tooltip: '在线导入插件 (URL)',
          ),
          // 右上角安装按钮 (保持不变，用于本地文件导入)
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _installPlugin(context),
            tooltip: '从本地文件安装插件',
          ),
          // 添加刷新按钮
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPlugins,
            tooltip: '刷新插件列表',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // 显示加载指示器
          : RefreshIndicator( // 下拉刷新
        onRefresh: _loadPlugins,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _plugins.length,
          itemBuilder: (context, index) {
            final Map<String, dynamic> plugin = _plugins[index];
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                // ------------------------------------------
                // 替换为弹出菜单功能
                // ------------------------------------------
                onLongPress: () => _showPluginActionMenu(context, plugin),

                leading: Icon(
                  plugin['enabled'] == true ? Icons.extension : Icons.extension_off,
                  color: plugin['enabled'] == true ? Colors.orange : Colors.grey,
                ),
                title: Text(
                  plugin['name'],
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('版本: ${plugin['version']}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text(plugin['description'] ?? '无描述'), // 增加容错
                  ],
                ),
                isThreeLine: true,
                trailing: Switch(
                  // 增加容错，确保 enabled 字段存在且为 bool
                  value: plugin['enabled'] == true,
                  onChanged: (bool value) {
                    if (value) {
                      // 启用插件，同时会自动禁用其他插件
                      _startPlugin(plugin['uid']);
                    } else {
                      // 禁用插件
                      _stopPlugin(plugin['uid']);
                    }
                  },
                  activeColor: Colors.orange,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // **修改：将原来的删除确认对话框改为插件操作菜单**
  void _showPluginActionMenu(BuildContext context, Map<String, dynamic> plugin) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc){
          return SafeArea( // 确保底部按钮不会被系统手势栏遮挡
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.vpn_key),
                  title: Text('配置 ApiKey'),
                  onTap: () {
                    Navigator.pop(context); // 关闭底部弹窗
                    _showKeyConfigurationDialog(context, plugin); // 弹出配置 key 对话框
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('删除插件', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context); // 关闭底部弹窗
                    _showDeleteConfirmationDialog(context, plugin); // 弹出删除确认对话框
                  },
                ),
              ],
            ),
          );
        }
    );
  }

  // 确认删除对话框（保持原逻辑，但现在从菜单中调用）
  void _showDeleteConfirmationDialog(BuildContext context, Map<String, dynamic> plugin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除插件'),
        content: Text('确定要删除插件 "${plugin['name']}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            // 删除按钮，调用 _deletePlugin
            onPressed: () {
              Navigator.pop(context); // 先关闭对话框
              _deletePlugin(plugin);
            },
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}