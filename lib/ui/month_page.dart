// 月账：这是「跟厂里对账」用的页面，也是这个 App 存在的核心理由。
//
// 工人月底对不上账，通常不是算错，而是"哪一扎漏记了"或"单价记错了"。
// 所以这一页的重点不是花哨图表，而是三张能直接对上的表：
// 按款号（对单价）、按天（对出勤）、以及可复制出去的对账文本。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/day.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'entry_page.dart';
import 'theme.dart';
import 'pal.dart';
import 'tokens.dart';
import 'widgets.dart';

class MonthPage extends StatefulWidget {
  const MonthPage({super.key});

  @override
  State<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<MonthPage> {
  DateTime _month = firstOfMonth(DateTime.now());
  MonthTotals _totals = const MonthTotals();
  List<StyleSum> _styles = [];
  List<DaySum> _days = [];

  @override
  void initState() {
    super.initState();
    appState.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    appState.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final m = ym(_month);
    final totals = await appState.repo.monthTotals(m);
    final styles = await appState.repo.styleSummary(m);
    final days = await appState.repo.daySummaries(m);
    if (!mounted) return;
    setState(() {
      _totals = totals;
      _styles = styles;
      _days = days;
    });
  }

  void _shift(int delta) {
    setState(() => _month = addMonths(_month, delta));
    _load();
  }

  Future<void> _exportSheet() async {
    final m = ym(_month);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.message_outlined),
              title: const Text('复制对账文本'),
              subtitle: const Text('直接粘到微信发给组长/老板'),
              onTap: () async {
                final text = await appState.repo.monthReportText(m);
                await Clipboard.setData(ClipboardData(text: text));
                if (c.mounted) Navigator.pop(c);
                _toast('对账文本已复制');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('复制 CSV'),
              subtitle: const Text('粘到 Excel / WPS 里能做透视'),
              onTap: () async {
                final csv = await appState.repo.monthCsv(m);
                await Clipboard.setData(ClipboardData(text: csv));
                if (c.mounted) Navigator.pop(c);
                _toast('CSV 已复制，粘到表格里即可');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _openDay(String date) async {
    final records = await appState.repo.workOnDay(date);
    final ots = await appState.repo.overtimeOnDay(date);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        final muted = Pal.dim(context);
        final d = parseYmd(date);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cnDay(d)} ${weekdayCn(d)} 明细',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (records.isEmpty && ots.isEmpty)
                  const EmptyState(title: '这一天没有记录'),
                ...records.map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          PhotoMark(r.photo.isNotEmpty),
                          Expanded(
                            child: Text(r.styleNo,
                                style: const TextStyle(fontSize: 15)),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        [
                          if (r.bundleNo.isNotEmpty) '扎 ${r.bundleNo}',
                          if (r.size.isNotEmpty) '码 ${r.size}',
                          '${r.qty} 件 × ${yuanCsv(r.unitPrice)}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                      trailing: MoneyText(r.amount, size: 15, weight: FontWeight.w700),
                      onTap: () async {
                        Navigator.pop(c);
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EntryPage(editing: r)));
                      },
                    )),
                ...ots.map((o) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('加班 ${hoursText(o.minutes)} 小时',
                          style: TextStyle(
                              fontSize: 15,
                              color: Pal.spark(context))),
                      subtitle: Text('${yuanCsv(o.hourPrice)} 元/时',
                          style: TextStyle(fontSize: 12.5, color: muted)),
                      trailing: MoneyText(o.amount, size: 15, weight: FontWeight.w700),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Pal.dim(context);
    final isCurrent = isSameMonth(_month, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('月账'),
        flexibleSpace: const GlassHeader(),
        actions: [
          IconButton(
            onPressed: _exportSheet,
            icon: const Icon(Icons.ios_share),
            tooltip: '导出 / 对账',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // 月份切换
          Row(
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Center(
                  child: Text('${cnMonth(_month)}${isCurrent ? '（本月）' : ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      )),
                ),
              ),
              IconButton(
                onPressed: isCurrent ? null : () => _shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 合计卡
          HudCorners(
            child: Panel(
              glow: true,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              radius: Tok.radiusLiquid + 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本月总收入',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.14 * 12,
                        color: muted,
                      )),
                  const SizedBox(height: 6),
                  MoneyText(_totals.total, size: 40, weight: FontWeight.w700, accent: true),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                            label: '计件',
                            value: yuanGrouped(_totals.pieceAmount),
                            sub: '${_totals.pieceQty} 件'),
                      ),
                      Container(width: 1, height: 30, color: Pal.line(context)),
                      Expanded(
                        child: _MiniStat(
                            label: '加班',
                            value: yuanGrouped(_totals.overtimeAmount),
                            sub: '${hoursText(_totals.overtimeMinutes)} 小时'),
                      ),
                      Container(width: 1, height: 30, color: Pal.line(context)),
                      Expanded(
                        child: _MiniStat(
                            label: '出勤', value: '${_totals.workDays} 天', sub: '记账天数'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          SectionHeader('按款号', trailing: _styles.isEmpty ? null : '${_styles.length} 个款'),
          if (_styles.isEmpty)
            const EmptyState(
              title: '这个月还没有记录',
              subtitle: '记一笔之后，这里会按款号汇总',
              icon: Icons.inventory_2_outlined,
            )
          else
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < _styles.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_styles[i].styleNo,
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                Text(
                                  '${_styles[i].qty} 件 · 单价 ${_styles[i].priceLabel} 元',
                                  style: TextStyle(fontSize: 12.5, color: muted),
                                ),
                              ],
                            ),
                          ),
                          MoneyText(_styles[i].amount, size: 16, weight: FontWeight.w700),
                        ],
                      ),
                    ),
                    if (i != _styles.length - 1)
                      Divider(height: 1, indent: 14, endIndent: 14,
                          color: Pal.line(context)),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 22),
          SectionHeader('按天', trailing: _days.isEmpty ? null : '点一行看明细'),
          if (_days.isNotEmpty)
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: _days.map((d) {
                  final dt = parseYmd(d.date);
                  return InkWell(
                    onTap: () => _openDay(d.date),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 74,
                            child: Text('${dt.month}-${two(dt.day)}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFeatures: tabularFigures)),
                          ),
                          Expanded(
                            child: Text(
                              [
                                d.pieceQty > 0 ? '${d.pieceQty} 件' : '',
                                d.overtimeMinutes > 0 ? '加班 ${hoursText(d.overtimeMinutes)}h' : '',
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: TextStyle(fontSize: 12.5, color: muted),
                            ),
                          ),
                          MoneyText(d.total, size: 15, weight: FontWeight.w600),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 18, color: muted),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 18),
          Text(
            '对账提示：把「按款号」的件数和单价，跟菲票/组长报的数逐条对；\n对不上通常是漏了一扎，或者扎号记重了。',
            style: TextStyle(fontSize: 12.5, color: muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _MiniStat({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    final muted = Pal.dim(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: muted)),
          const SizedBox(height: 3),
          // 金额位数多时缩字而不是溢出（窄屏 360dp 下三分栏很紧）
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: tabularFigures)),
          ),
          Text(sub, style: TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
  }
}
