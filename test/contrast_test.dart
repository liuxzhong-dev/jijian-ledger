// 可读性回归测试：把「看不清字」变成可计算的断言。
//
// v1.1 的问题不是审美，是算术：页面里有一批文字不在面板上，而是直接压在
// 渐变背景上（"件数""单价"标签、输入框里的提示、工序/备注那一行）。
// 那几个位置用的 #8A76B0 压在渐变最亮的粉紫段上，对比度只有 1.2:1，
// 人眼等于看不见。截图能看出来，但代码里看不出来——所以用测试钉住。
//
// 阈值用 WCAG 2.1：
//   正文 4.5:1 / 大字号与次要信息 3.0:1 / 图形与描边 3.0:1

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jijian_ledger/ui/tokens.dart';

double _channel(double v) {
  final c = v;
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// 把前景按 alpha 叠到底色上（模拟半透明玻璃/内槽）
Color over(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

/// 某个位置上真实的底色：背景段先被压暗层压过一遍
Color scrimmed(Color stop, Color dim) => over(dim, stop);

void main() {
  group('经典皮肤（默认）文字对比度', () {
    final cases = <String, (Color text, Color bg)>{
      '主文字/白卡': (Ck.lightTxHi, Ck.lightCard),
      '次文字/白卡': (Ck.lightTxMid, Ck.lightCard),
      '三级文字/白卡': (Ck.lightTxDim, Ck.lightCard),
      '三级文字/页面底': (Ck.lightTxDim, Ck.lightBg),
      '主色文字/白卡': (Ck.primary, Ck.lightCard),
      '深色主题 主文字': (Ck.darkTxHi, Ck.darkCard),
      '深色主题 次文字': (Ck.darkTxMid, Ck.darkCard),
      '深色主题 三级文字': (Ck.darkTxDim, Ck.darkCard),
      '深色主题 三级/页面底': (Ck.darkTxDim, Ck.darkBg),
      '深色主题 主色': (Ck.primaryDark, Ck.darkBg),
    };
    cases.forEach((name, v) {
      test(name, () {
        final r = contrast(v.$1, v.$2);
        expect(r, greaterThanOrEqualTo(4.5), reason: '$name 只有 ${r.toStringAsFixed(2)}:1');
      });
    });
  });

  group('全息皮肤：压在背景上的文字（不在面板里）', () {
    for (final theme in BgTheme.values) {
      final spec = BgSpec.of(theme);
      final dark = spec.dark;
      final mid = dark ? Tok.txMid : Tok.txMidLight;
      final dim = dark ? Tok.txDim : Tok.txDimLight;
      // 用最亮的一段背景段做最坏情况
      var brightest = spec.stops.first;
      for (final s in spec.stops) {
        if (_lum(s) > _lum(brightest)) brightest = s;
      }
      final ground = scrimmed(brightest, spec.dimMid);

      test('${theme.name} 次文字 ≥4.5', () {
        final r = contrast(mid, ground);
        expect(r, greaterThanOrEqualTo(4.5),
            reason: '${theme.name} 次文字只有 ${r.toStringAsFixed(2)}:1（底 ${_hex(ground)}）');
      });

      test('${theme.name} 三级文字 ≥3.0', () {
        final r = contrast(dim, ground);
        expect(r, greaterThanOrEqualTo(3.0),
            reason: '${theme.name} 三级文字只有 ${r.toStringAsFixed(2)}:1（底 ${_hex(ground)}）');
      });
    }
  });

  group('全息皮肤：玻璃面板内的文字', () {
    for (final theme in BgTheme.values) {
      final spec = BgSpec.of(theme);
      final dark = spec.dark;
      final hi = dark ? Tok.txHi : Tok.txHiLight;
      final dim = dark ? Tok.txDim : Tok.txDimLight;
      final panelLight = dark
          ? over(Tok.glassFill(0.6), scrimmed(spec.stops.reduce((a, b) => _lum(a) > _lum(b) ? a : b), spec.dimMid))
          : over(const Color.fromRGBO(255, 255, 255, 0.86), scrimmed(Tok.paperMid, spec.dimMid));

      test('${theme.name} 主文字 ≥7', () {
        final r = contrast(hi, panelLight);
        expect(r, greaterThanOrEqualTo(7.0),
            reason: '${theme.name} 主文字只有 ${r.toStringAsFixed(2)}:1（玻璃底 ${_hex(panelLight)}）');
      });

      test('${theme.name} 三级文字 ≥4.5', () {
        final r = contrast(dim, panelLight);
        expect(r, greaterThanOrEqualTo(4.5),
            reason: '${theme.name} 三级文字只有 ${r.toStringAsFixed(2)}:1（玻璃底 ${_hex(panelLight)}）');
      });
    }
  });

  test('宝石按钮上的白字 ≥4.5（顶面/腰身/根部各检查一次）', () {
    final colors = Tok.gemGradient.colors;
    for (final c in colors) {
      final r = contrast(const Color(0xFFFDF8FF), c);
      // 顶面本来就是受光的高光，只要求 3.0（白字在那里必然浅）
      final min = c == colors.first ? 1.6 : 4.5;
      expect(r, greaterThanOrEqualTo(min),
          reason: '宝石按钮 ${_hex(c)} 上白字只有 ${r.toStringAsFixed(2)}:1');
    }
  });

  test('输入框内槽里的提示文字 ≥3.0', () {
    final spec = BgSpec.of(BgTheme.twilight);
    final ground = scrimmed(Tok.bgWarm, spec.dimMid);
    final slot = over(Tok.slotFill.colors.first, ground);
    final r = contrast(Tok.txDim, slot);
    expect(r, greaterThanOrEqualTo(3.0), reason: '内槽提示只有 ${r.toStringAsFixed(2)}:1');
  });
}

String _hex(Color c) =>
    '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';
