import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
class StorageProvider {
  // 单例实例
  static final StorageProvider _instance = StorageProvider._internal();
  factory StorageProvider() => _instance;
  StorageProvider._internal();
  // 应用程序文档目录
  Directory? _appPriDir;
  Directory? _appPubDir;
  // 初始化，必须在使用时先调用
  Future<void> init() async {
    _appPriDir ??= await getApplicationSupportDirectory();
    _appPubDir ??= await getExternalStorageDirectory();
  }
  // 获取文件路径
  Future<String> _getPriFilePath(String fileName) async{
    if (_appPriDir == null) {
      throw Exception("PrivateStorage not initialized. Call init() first.");
    }
    final dir = File('${_appPriDir!.path}/$fileName').parent;
    if(!await dir.exists()){
      await dir.create(recursive: true);
    }
    return '${_appPriDir!.path}/$fileName';
  }
  Future<String> getPriFilePath(String fileName) async {
    await init();
    final filePath = await _getPriFilePath(fileName);
    return filePath;
  }
  Future<bool> deletePriFile(String fileName) async {
    await init();
    final file = File(await _getPriFilePath(fileName));
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
  Future<bool> priExists(String fileName) async {
    await init();
    final file = File(await _getPriFilePath(fileName));
    return file.exists();
  }
  // 获取文件路径
  Future<String> _getPubFilePath(String fileName) async{
    if (_appPubDir == null) {
      throw Exception("PublicStorage not initialized. Call init() first.");
    }
    final dir = File('${_appPubDir!.path}/$fileName').parent;
    if(!await dir.exists()){
      await dir.create(recursive: true);
    }
    return '${_appPubDir!.path}/$fileName';
  }
  Future<String> getPubFilePath(String fileName) async {
    await init();
    final filePath = await _getPubFilePath(fileName);
    return filePath;
  }
  Future<bool> deletePubFile(String fileName) async {
    await init();
    final file = File(await _getPubFilePath(fileName));
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
  Future<bool> pubExists(String fileName) async {
    await init();
    final file = File(await _getPriFilePath(fileName));
    return file.exists();
  }
}
final storage = StorageProvider();

/// 把任意 url 的文件直接写进
Future<void> downloadToFile({
  required String url,
  required File targetFile,
  void Function(int received, int total)? onProgress,
}) async {
  // 1. 网络请求
  final resp = await http.Client().send(http.Request('GET', Uri.parse(url)));

  // 2. 内容长度，方便做进度
  final total = resp.contentLength ?? -1;
  var received = 0;

  // 3. 打开 sink（append=false 表示覆盖写）
  final sink = targetFile.openWrite(mode: FileMode.write);

  // 4. 监听流，边下边写
  await resp.stream.listen(
        (chunk) {
      sink.add(chunk);
      if (total > 0) {
        received += chunk.length;
        onProgress?.call(received, total);
      }
    },
    onError: (e) => throw e,          // 下载失败直接抛
    cancelOnError: true,
  ).asFuture();

  // 5. 收尾
  await sink.flush();
  await sink.close();
}
Future<String?> pickFile() async {
  const List<String> allowedExtensions = ['js', 'qing'];
  const int maxSizeBytes = 3 * 1024 * 1024;

  final XFile? file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[
      XTypeGroup(
        label: '支持的插件',
        extensions: allowedExtensions,
      ),
    ],
    confirmButtonText: '安装',
  );

  if (file != null) {
    final int fileSize = await file.length();
    if (fileSize > maxSizeBytes) {
      return null;
    }

    final bytes = await file.readAsBytes();

    const bomUtf8 = [0xEF, 0xBB, 0xBF];
    if (bytes.length >= 3 &&
        bytes[0] == bomUtf8[0] &&
        bytes[1] == bomUtf8[1] &&
        bytes[2] == bomUtf8[2]) {
      return utf8.decode(bytes.sublist(3));
    }

    return utf8.decode(bytes);
  }

  return null;
}