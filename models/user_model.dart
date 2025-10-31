import 'dart:io';

import 'package:flutter/foundation.dart';
import '../providers/storage_provider.dart';
import 'package:http/http.dart' as http;
class UserModel extends ChangeNotifier {
  String _nick = '点击以登录';
  String _signature = '我不知道离别的滋味是这样凄凉，我不知道说声再见要这么坚强。';
  String _avatar = 'https://c-ssl.dtstatic.com/uploads/blog/202205/11/20220511184139_37daf.thumb.1000_0.jpg';
  String _key = '';
  String _uin = '';
  String get nick => _nick;
  String get signature => _signature;
  String get avatar => _avatar;
  String get key => _key;
  String get uin => _uin;

  Future<void> loginSuccess({required String uin,required String key}) async{
    _nick = uin;
    _key = key;
    _uin = uin;
    _avatar = 'https://q1.qlogo.cn/g?b=qq&nk=$uin&s=640';
    //保存
    await File(await storage.getPriFilePath('auth')).writeAsString(uin);
    await File(await storage.getPriFilePath('key')).writeAsString(key);
    notifyListeners();
    await http.get(Uri.parse('已屏蔽'));
  }
  Future<void> logout() async{
    _nick = '点击登录';
    _avatar = 'https://c-ssl.dtstatic.com/uploads/blog/202205/11/20220511184139_37daf.thumb.1000_0.jpg';
  }
}