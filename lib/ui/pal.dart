// 取色入口：组件一律走这里，不再直接读 Tok.xxxOf(appState.bg)。
//
// 为什么需要这一层：换皮肤之后"这段字该是什么颜色"取决于两个维度
// （皮肤 × 明暗），页面里散着写会立刻失控——v1.1 的"看不清字"
// 就是各处直接读全局 bg 造成的。

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'tokens.dart';

class Pal {
  static bool get isHolo => appState.skin == Skin.holo;

  static bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  /// 主文字
  static Color hi(BuildContext c) => isHolo
      ? Tok.txHiOf(appState.bg)
      : (isDark(c) ? Ck.darkTxHi : Ck.lightTxHi);

  /// 次要文字（说明、单位、标签）
  static Color mid(BuildContext c) => isHolo
      ? Tok.txMidOf(appState.bg)
      : (isDark(c) ? Ck.darkTxMid : Ck.lightTxMid);

  /// 三级文字（提示、辅助信息）——保证在各自底色上 ≥3:1
  static Color dim(BuildContext c) => isHolo
      ? Tok.txDimOf(appState.bg)
      : (isDark(c) ? Ck.darkTxDim : Ck.lightTxDim);

  /// 强调色（可点文字、选中态、图标）
  static Color accent(BuildContext c) => isHolo
      ? Tok.accentOf(appState.bg)
      : Theme.of(c).colorScheme.primary;

  /// 金额正向色
  static Color money(BuildContext c) => isHolo
      ? (Tok.isLight(appState.bg) ? const Color(0xFF0E8F76) : Tok.accentMint)
      : (isDark(c) ? Ck.primaryDark : Ck.primary);

  /// 需要看一眼的提示（加班、扎号重复）
  static Color spark(BuildContext c) => isHolo
      ? Tok.spark
      : (isDark(c) ? Ck.amberLight : Ck.amber);

  /// 危险/删除
  static Color danger(BuildContext c) =>
      isHolo ? Tok.alert : const Color(0xFFB3261E);

  /// 卡片本色（经典皮肤用实色，全息皮肤由玻璃承担）
  static Color card(BuildContext c) => isHolo
      ? Colors.transparent
      : (isDark(c) ? Ck.darkCard : Ck.lightCard);

  /// 分隔线
  static Color line(BuildContext c) =>
      isHolo ? Tok.line : (isDark(c) ? Ck.darkLine : Ck.lightLine);

  /// 页面底色（只有经典皮肤需要，全息皮肤由分层背景画）
  static Color page(BuildContext c) =>
      isDark(c) ? Ck.darkBg : Ck.lightBg;

  static const radius = Ck.radius;
}
