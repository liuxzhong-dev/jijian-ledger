// 全局应用状态：数据源、外观偏好、刷新通知。
//
// 用全局单例而不是状态管理库，是刻意的取舍：这个 App 只有一个数据源
// （本地 SQLite）和一个写入入口，引入状态管理只会多一层要理解的东西。
//
// 外观分两套皮肤：
//   classic（默认）—— 等于 v1.0：明暗跟随系统或手选，纯色卡片。
//   holo          —— 爪 Pro：背景三选一 + 玻璃厚度 + 按钮四形态。
// 默认给 classic 是主人的决定：全息那套在手机竖屏上小字对比度不够，
// 而记账本的第一要求是「看得清」。

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../core/sizes.dart';
import '../data/db.dart';
import '../data/repo.dart';
import '../ui/tokens.dart';

class AppState extends ChangeNotifier {
  late Repo repo;
  int version = 0;

  Skin skin = Skin.classic;

  /// 经典皮肤：跟随系统 / 浅色 / 深色（等同 v1.0 的 ThemeMode）
  ThemeMode classicMode = ThemeMode.system;

  /// 全息皮肤：背景 / 玻璃厚度 / 按钮形态
  BgTheme bg = BgTheme.twilight;
  double glassA = 1.0; // 0.6~1.0
  BtnStyle btn = BtnStyle.gem;

  /// 用户自己填过的码（外贸大码、厂里特殊写法）。
  /// 存 settings 表 key `sizes`，逗号分隔，最多 4 个。
  List<String> customSizes = const [];

  bool get isHolo => skin == Skin.holo;

  /// [database] 只在测试里传（内存数据库）。线上不传，走 openLedgerDb()。
  Future<void> init({Database? database}) async {
    final db = database ?? await openLedgerDb();
    repo = Repo(db);

    skin = switch (await repo.getSetting('skin')) {
      'holo' => Skin.holo,
      _ => Skin.classic,
    };
    classicMode = switch (await repo.getSetting('mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    bg = switch (await repo.getSetting('bg')) {
      'ink' => BgTheme.ink,
      'paper' => BgTheme.paper,
      _ => BgTheme.twilight,
    };
    glassA = double.tryParse(await repo.getSetting('glass') ?? '') ?? 1.0;
    if (glassA < 0.6) glassA = 0.6;
    if (glassA > 1) glassA = 1;
    btn = switch (await repo.getSetting('btn')) {
      'glass' => BtnStyle.glass,
      'ghost' => BtnStyle.ghost,
      'pill' => BtnStyle.pill,
      _ => BtnStyle.gem,
    };
    final custom = await repo.getSetting('sizes') ?? '';
    customSizes = custom
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(Sizes.maxCustom)
        .toList();
  }

  /// 数据变更后调用，触发所有页面重新加载
  void touch() {
    version++;
    notifyListeners();
  }

  Future<void> setSkin(Skin s) async {
    skin = s;
    await repo.setSetting('skin', s.name);
    notifyListeners();
  }

  Future<void> setClassicMode(ThemeMode m) async {
    classicMode = m;
    await repo.setSetting('mode', m.name);
    notifyListeners();
  }

  Future<void> setBg(BgTheme t) async {
    bg = t;
    await repo.setSetting('bg', t.name);
    notifyListeners();
  }

  Future<void> setGlass(double v) async {
    glassA = v.clamp(0.6, 1.0);
    await repo.setSetting('glass', glassA.toStringAsFixed(2));
    notifyListeners();
  }

  Future<void> setBtn(BtnStyle s) async {
    btn = s;
    await repo.setSetting('btn', s.name);
    notifyListeners();
  }

  /// 记住一个自定义码：提到最前、去重、超出的丢掉。
  /// 和单价记忆同一个思路——用户填过一次的东西，第二次就该自动带出来。
  Future<void> addCustomSize(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return;
    customSizes = [
      s,
      ...customSizes.where((x) => x != s),
    ].take(Sizes.maxCustom).toList();
    await repo.setSetting('sizes', customSizes.join(','));
    notifyListeners();
  }

  Future<void> removeCustomSize(String s) async {
    customSizes = customSizes.where((x) => x != s).toList();
    await repo.setSetting('sizes', customSizes.join(','));
    notifyListeners();
  }
}

final appState = AppState();
