// 入口：初始化数据库 → 按皮肤组装界面。
//
// 注意必须 await appState.init() 之后再 runApp，
// 否则首帧就会去查一个还没打开的数据库。
//
// 两套皮肤的差异只在这一层决定：
//   经典 —— 只给 theme + darkTheme + themeMode，背景由 Scaffold 自己铺实色。
//   全息 —— 只给 theme（明暗由背景决定），背景由 LayeredBackground 垫在 Navigator 下面。

import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'ui/background.dart';
import 'ui/glass.dart';
import 'ui/home_page.dart';
import 'ui/mine_page.dart';
import 'ui/month_page.dart';
import 'ui/theme.dart';
import 'ui/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.init();
  runApp(const LedgerApp());
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final holo = appState.skin == Skin.holo;
        return MaterialApp(
          title: '计件本',
          debugShowCheckedModeBanner: false,
          theme: holo ? buildHoloTheme(appState.bg) : buildClassicTheme(Brightness.light),
          darkTheme: holo ? null : buildClassicTheme(Brightness.dark),
          themeMode: holo ? ThemeMode.light : appState.classicMode,
          // 全息皮肤的背景不挂在 Scaffold 上，而是垫在 Navigator 下面：
          // 这样 AppBar / 滚动内容 / 底栏都压在同一张渐变上，玻璃才有东西可糊。
          builder: (context, child) {
            if (!holo) return child ?? const SizedBox.shrink();
            return Stack(
              children: [
                Positioned.fill(child: LayeredBackground(theme: appState.bg)),
                child ?? const SizedBox.shrink(),
              ],
            );
          },
          home: const RootShell(),
        );
      },
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // IndexedStack 保留各页状态：切回月账时不会重置到当月
  static const _pages = [HomePage(), MonthPage(), MinePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: GlassNavShell(
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          height: 62,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: '今天',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: '月账',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
