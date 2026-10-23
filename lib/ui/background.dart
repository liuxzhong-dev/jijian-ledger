// 分层背景：完全照爪 Pro 的 #bgLayer 复刻（渐变 → 32px 网格 → 扫描线 → 极光/压暗/vignette）。
//
// 为什么用 CustomPainter 而不是叠十几个 Container：
// 这些层都是静态的，一次画完 + RepaintBoundary 缓存，滚动时不重绘；
// 用 Container 叠会带来十几层合成，安卓低端机上滚动会掉帧。

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tokens.dart';

class LayeredBackground extends StatelessWidget {
  final BgTheme theme;
  const LayeredBackground({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BgPainter(BgSpec.of(theme)),
        size: Size.infinite,
        isComplex: true,
        willChange: false,
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final BgSpec spec;
  _BgPainter(this.spec);

  Color _mul(Color c, double f) =>
      Color.fromRGBO((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round(), c.a * f);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 1) 背景本体（六段渐变）
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, h),
        spec.stops,
        spec.positions,
      );
    canvas.drawRect(Offset.zero & size, bg);

    // 2) 32px 网格（比背景亮一点点，制造"全息投影"的底纹）
    final gridPaint = Paint()
      ..color = spec.dark ? Tok.grid : Tok.grid.withAlpha(18)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= w; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (var y = 0.0; y <= h; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 3) 扫描线：每 3px 一条 1px 的极淡横线
    final scan = Paint()
      ..color = Color.fromRGBO(217, 194, 240, 0.022 * (spec.dark ? 1 : 0.6))
      ..strokeWidth = 1;
    for (var y = 0.0; y <= h; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(w, y), scan);
    }

    // 4) 极光三团（玻璃要糊的东西，同时给紫底添色散细节）
    final blobs = [
      (0.16, 0.10, 0.72, const Color.fromRGBO(200, 150, 235, 0.16)),
      (0.84, 0.20, 0.62, const Color.fromRGBO(124, 92, 246, 0.14)),
      (0.52, 1.12, 0.86, const Color.fromRGBO(74, 29, 122, 0.22)),
    ];
    for (final b in blobs) {
      final center = Offset(w * b.$1, h * b.$2);
      final r = w * b.$3;
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          r,
          [_mul(b.$4, spec.ovA), _mul(b.$4, 0)],
          [0.0, 0.62],
        );
      canvas.drawCircle(center, r, paint);
    }

    // 5) vignette：中间清亮、四角压暗（阅读区不闷）
    final vig = Paint()
      ..shader = ui.Gradient.radial(
        Offset(w * 0.5, h * 0.45),
        (w > h ? w : h) * 1.05,
        [_mul(spec.dimVig, 0), _mul(spec.dimVig, spec.ovA)],
        [0.52, 1.0],
      );
    canvas.drawRect(Offset.zero & size, vig);

    // 6) 上下压暗：顶部和底部各压一档，让状态栏/导航栏上的文字有对比
    final dim = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, h),
        [
          _mul(spec.dimTop, spec.ovA),
          _mul(spec.dimMid, spec.ovA),
          _mul(spec.dimBot, spec.ovA),
        ],
        [0.0, 0.40, 1.0],
      );
    canvas.drawRect(Offset.zero & size, dim);
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => old.spec != spec;
}
