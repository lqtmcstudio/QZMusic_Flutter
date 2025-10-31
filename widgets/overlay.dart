import 'package:flutter/material.dart';

// 用于全局管理 OverlayEntry
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class GlobalLoadingOverlay {
  static OverlayEntry? _overlayEntry;
  static String _currentText = '加载中...';

  // 显示加载覆盖层
  static void show({String text = '加载中...'}) {
    if (_overlayEntry != null) return; // 避免重复显示
    _currentText = text;

    final overlay = globalNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('❌ 错误: 无法获取 OverlayState.');
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => WillPopScope( // 阻止用户通过返回键取消
        onWillPop: () async => false,
        child: Container(
          color: Colors.black54, // 半透明黑色背景
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 15),
                  // 使用 StatefulBuilder 来确保文本更新时能够局部刷新
                  StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      // 这是一个在 Overlay 内部的局部状态，当调用 updateText 时会刷新它
                      GlobalLoadingOverlay.updateText = (newText) {
                        setState(() {
                          _currentText = newText;
                        });
                      };
                      return Text(
                        _currentText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  // 更新加载提示文本
  static Function(String)? updateText;

  // 隐藏覆盖层
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    updateText = null; // 清除引用
  }
}