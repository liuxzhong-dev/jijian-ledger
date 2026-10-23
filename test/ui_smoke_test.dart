// UI 冒烟测试：只验证"新皮肤能不能构建出来"，不验证业务。
//
// 为什么只做这一层：组件测试跑在假时钟里，真实的 SQLite I/O 不会推进，
// 页面里的 await 查询永远等不到结果，pumpAndSettle 也等不到空闲
// （录入页光标闪烁会一直调度新帧）。所以全流程 UI 测试不值得做，
// 但"整个界面树能不能构建、切主题会不会炸"必须自动验证——
// 这轮把展示层从 Material 默认皮肤换成了自绘玻璃，
// ListTile 缺 Material 祖先、背景层缺 Directionality 这类错，
// 光看代码看不出来，只有真跑一遍才会抛。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jijian_ledger/core/photos.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:jijian_ledger/data/db.dart';
import 'package:jijian_ledger/main.dart';
import 'package:jijian_ledger/state/app_state.dart';
import 'package:jijian_ledger/ui/tokens.dart';

/// path_provider 的 method channel。v1.4 起「我的」页初始化要读照片目录大小，
/// 不 mock 它就会抛 MissingPluginException，页签测试直接红。
const _ppChannel = MethodChannel('plugins.flutter.io/path_provider');
final _docsPath = p.join(Directory.systemTemp.path, 'jijian_smoke_docs');

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    final d = Directory(_docsPath);
    if (d.existsSync()) d.deleteSync(recursive: true);
    d.createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ppChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') return _docsPath;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ppChannel, null);
    final d = Directory(_docsPath);
    if (d.existsSync()) d.deleteSync(recursive: true);
  });

  /// 真开一个内存库并交给全局状态——init 必须在 runAsync 里做，
  /// 否则假时钟不会等它回来。
  Future<void> boot(WidgetTester tester) async {
    await tester.runAsync(() async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: dbVersion,
          onCreate: (d, v) => createSchema(d),
          singleInstance: false,
        ),
      );
      await appState.init(database: db);
    });
  }

  /// 推进一帧，再把「真时间」放进来让 SQLite 跑完。
  ///
  /// 组件测试跑在假时钟里，页面 initState 里那句 await 查询不会推进；
  /// 而 sqflite 每次查询都会挂一个 10 秒的事务超时定时器，
  /// 测试结束时定时器还在 → 报 "A Timer is still pending"。
  /// 所以每推一帧都要用 runAsync 把真实 I/O 排干净，定时器才会随查询完成取消。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    }
    await tester.pump();
  }

  testWidgets('首页能构建，两套皮肤 × 三套背景切换都不抛异常', (tester) async {
    await boot(tester);
    await tester.pumpWidget(const LedgerApp());
    await settle(tester);
    expect(tester.takeException(), isNull);

    for (final skin in Skin.values) {
      await tester.runAsync(() => appState.setSkin(skin));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '皮肤 ${skin.name} 构建失败');

      if (skin != Skin.holo) continue;
      for (final bg in BgTheme.values) {
        await tester.runAsync(() => appState.setBg(bg));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '背景 ${bg.name} 构建失败');
      }
    }
  });

  /// 循环推帧，直到 [target] 指向的部件位置收敛（连续两帧坐标不变）。
  ///
  /// ⚠ 为什么需要它（2026-10-21 实测踩坑）：路由/对话框转场**不是一次
  /// `pump(duration)` 能推完的**——点完按钮后单次 `pump(400ms)`，新页面
  /// 可能还没入树；再补一帧它出现了，却停在偏移约 200px 的半路。
  /// 而 `tester.tap` 点到屏幕外的部件**只打印一条 warning、不抛异常**
  /// （静默 miss），于是 setState 从未执行，断言看起来像"功能坏了"。
  /// 用位置收敛作判据，比拍一个固定时长可靠：转场多长、从哪一帧开始
  /// 构建，都不必猜。顺带在每轮塞一点真实 I/O 时间（写库要用）。
  Future<void> pumpUntilStill(WidgetTester tester, Finder target) async {
    Rect? last;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      if (target.evaluate().isEmpty) continue;
      final box = tester.getRect(target);
      if (last != null &&
          (box.left - last.left).abs() < 0.5 &&
          (box.top - last.top).abs() < 0.5) {
        return;
      }
      last = box;
    }
    throw StateError('$target 推了 1.2 秒还没到位');
  }

  /// 等 [target] 从树上消失（弹窗收回、页面 pop 都用它）。
  /// 先查再推：转场在假时钟里要一帧帧推，写库还要真实 I/O 时间。
  Future<void> pumpUntilGone(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 12; i++) {
      if (target.evaluate().isEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    }
    throw StateError('$target 迟迟不消失');
  }

  /// 打开录入页并等它落位。
  Future<void> openEntryPage(WidgetTester tester) async {
    await tester.tap(find.text('记一笔').last);
    await pumpUntilStill(tester, find.text('更多码'));
    // 落位校验：录入页独有的「款号」应该在屏内（测试面宽 800）
    final box = tester.getRect(find.text('款号'));
    expect(box.left, lessThan(800), reason: '录入页还在转场中，先别点它');
  }

  testWidgets('录入页：大码能选到、自定义码能填', (tester) async {
    await boot(tester);
    await tester.pumpWidget(const LedgerApp());
    await settle(tester);

    await openEntryPage(tester);

    // 1) 大码：默认不显示，点「更多码」才出现
    expect(find.text('12XL'), findsNothing, reason: '大码不该默认铺开');
    await tester.tap(find.text('更多码'));
    await settle(tester);
    expect(find.text('12XL'), findsOneWidget);

    // 2) 选一个 12XL，确认能选中（不抛异常即选中成功）
    await tester.tap(find.text('12XL'));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: '选 12XL 失败');

    // 3) 自定义码：填一个不在任何内置列表里的值。
    //    对话框也要等它转场落位再操作，否则 enterText 会打进
    //    录入页自己的输入框里（静默打错目标）。
    await tester.tap(find.text('自定义'));
    final dialogField =
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await pumpUntilStill(tester, dialogField);
    await tester.enterText(dialogField, '170/88A');
    await tester.tap(find.text('确定'));
    // 两步等：先等弹窗完全收回（它的输入框里也是 "170/88A"，
    // 不收完 find.text 会二义），再等写库 + 重建 + 落位。
    await pumpUntilGone(tester, find.byType(AlertDialog));
    await pumpUntilStill(tester, find.text('170/88A'));
    expect(tester.takeException(), isNull, reason: '自定义码对话框失败');
    // 填过之后它必须出现在选项里（并处于选中态）
    expect(find.text('170/88A'), findsOneWidget);
  });

  testWidgets('录入页：菲票拍照区能构建，点「拍菲票」弹出来源选择', (tester) async {
    await boot(tester);
    await tester.pumpWidget(const LedgerApp());
    await settle(tester);

    await openEntryPage(tester);

    // 空状态：「菲票」小标题 + 通栏「拍菲票」按钮
    expect(find.text('菲票'), findsOneWidget);
    expect(find.text('拍菲票'), findsOneWidget);

    // 点「拍菲票」→ 底部弹「拍照 / 从相册选择」（相册入口是给
    // 「下班前把白天拍的票一起补录」的工人留的）
    await tester.tap(find.text('拍菲票'));
    await pumpUntilStill(tester, find.text('拍照'));
    expect(find.text('从相册选择'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '来源选择弹窗构建失败');

    // 点遮罩收回。**不能真去点「拍照」**——那会调 image_picker 的平台
    // 通道，测试环境里没有实现，抛的是 MissingPluginException，
    // 连 PlatformException 的兜底 toast 都接不住。
    await tester.tapAt(const Offset(400, 20));
    await pumpUntilGone(tester, find.text('拍照'));
    expect(find.text('拍菲票'), findsOneWidget, reason: '收回后应回到空状态');
    expect(tester.takeException(), isNull);
  });

  testWidgets('三个页签都能打开（ListTile 必须有 Material 祖先）', (tester) async {
    await boot(tester);
    await tester.pumpWidget(const LedgerApp());
    await settle(tester);

    // 两套皮肤都要过一遍：卡片底色画在哪一层，两边不一样，
    // 踩过的坑正是在其中一边漏了 Material 祖先
    for (final skin in Skin.values) {
      await tester.runAsync(() => appState.setSkin(skin));
      await settle(tester);
      for (final label in ['月账', '我的', '今天']) {
        await tester.tap(find.text(label).last);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${skin.name} 的 $label 页构建失败');
      }
    }
  });

  testWidgets('经典皮肤三种明暗 + 全息四种按钮与玻璃滑块都不炸', (tester) async {
    await boot(tester);
    await tester.pumpWidget(const LedgerApp());
    await settle(tester);

    for (final m in ThemeMode.values) {
      await tester.runAsync(() => appState.setClassicMode(m));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '明暗 ${m.name} 构建失败');
    }

    await tester.runAsync(() => appState.setSkin(Skin.holo));
    await settle(tester);
    for (final s in BtnStyle.values) {
      await tester.runAsync(() => appState.setBtn(s));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '按钮形态 ${s.name} 构建失败');
    }

    // 玻璃强度：直接改内存值（对应滑块拖动中的预览路径）
    appState.glassA = 0.6;
    await settle(tester);
    expect(tester.takeException(), isNull, reason: '最透一档构建失败');

    appState.glassA = 1.0;
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
