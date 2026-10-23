// 菲票大图页。
//
// 两个设计点：
// 1) **必须能缩放**。工人拍菲票的第一动机就是看清手写数字
//    （"这到底是 3 还是 5"），不能放大的看图等于没拍。
//    用 InteractiveViewer 而不是 photo_view 包——少一个依赖，
//    双指缩放 + 双击缩放在这个场景够用。
// 2) **永远黑底**，不随皮肤变。所有相册类 App 都是黑的，
//    这是用户已经形成的预期；白底看照片反而刺眼。
//    这是全 App 唯一一处"不看 Pal 取色"的页面，故意的。

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/photos.dart';

class PhotoViewPage extends StatelessWidget {
  final String photoName;

  const PhotoViewPage({super.key, required this.photoName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('菲票照片'),
      ),
      body: FutureBuilder<File?>(
        future: Photos.file(photoName),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white54));
          }
          final f = snap.data;
          if (f == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '照片文件已丢失。\n\n'
                  '换过手机、或者清理过存储，就会出现这种情况。\n'
                  '账目记录本身没丢，重新拍一张就行。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.7),
                ),
              ),
            );
          }
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.file(
                f,
                fit: BoxFit.contain,
                // 文件在列表滚动期间被删（极端情况）时不崩，显示裂图图标
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined,
                    size: 64, color: Colors.white38),
              ),
            ),
          );
        },
      ),
    );
  }
}
