// 首页（今日）：回答"今天挣了多少、记了几笔"。
//
// 只显示今天，是因为工人最常看的就是今日累计（收工时对一眼）。
// 补记过去某天在录入页改日期即可；历史在「月账」里看。

import 'package:flutter/material.dart';

import '../core/day.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'entry_page.dart';
import 'overtime_page.dart';
import 'theme.dart';
import 'pal.dart';
import 'tokens.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _today = DateTime.now();
  List<WorkRecord> _records = [];
  List<OvertimeRecord> _overtimes = [];
  DaySum _day = DaySum('');
  MonthTotals _month = const MonthTotals();

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
    final d = ymd(_today);
    final m = ym(_today);
    final records = await appState.repo.workOnDay(d);
    final ots = await appState.repo.overtimeOnDay(d);
    final day = await appState.repo.dayTotal(d);
    final month = await appState.repo.monthTotals(m);
    if (!mounted) return;
    setState(() {
      _records = records;
      _overtimes = ots;
      _day = day;
      _month = month;
    });
  }

  /// 今天最后记的那一扎：连续录入靠它——「再记一扎」把款号/单价/码带回去，
  /// 用户只需要填扎号和件数。比"留在录入页"更好的一点是：每记一扎都会
  /// 回来看见今日合计往上跳一次。
  WorkRecord? get _lastToday {
    if (_records.isEmpty) return null;
    return _records.reduce((a, b) => a.createdAt >= b.createdAt ? a : b);
  }

  Future<void> _openEntry() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EntryPage(prefill: _lastToday)),
    );
  }

  Future<void> _openOvertime() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OvertimePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Pal.dim(context);
    final count = _records.length + _overtimes.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('计件本'),
        flexibleSpace: const GlassHeader(),
        actions: [
          TextButton.icon(
            onPressed: _openOvertime,
            icon: const Icon(Icons.nightlight_round, size: 17),
            label: const Text('加班'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: GemFab(
        label: _lastToday == null ? '记一笔' : '再记一扎',
        icon: Icons.add,
        onPressed: _openEntry,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: Tok.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            // 今日大数字：玻璃面板 + 四角 HUD 角标 + 薄荷绿数值
            HudCorners(
              child: Panel(
                glow: true,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                radius: Tok.radiusLiquid + 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 7),
                          decoration: const BoxDecoration(
                            color: Tok.accentMint,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Tok.accentMint, blurRadius: 8)],
                          ),
                        ),
                        Text('今日收入',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.14 * 12,
                              color: muted,
                            )),
                        const Spacer(),
                        Text('${cnDay(_today)} ${weekdayCn(_today)}',
                            style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MoneyText(_day.total,
                        size: 44,
                        weight: FontWeight.w700,
                        accent: true,
                        color: _day.total > 0 ? null : muted),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Pill('计件 ${_day.pieceQty} 件 · ${yuanGrouped(_day.pieceAmount)}',
                            icon: Icons.checkroom),
                        if (_day.overtimeMinutes > 0)
                          Pill(
                            '加班 ${hoursText(_day.overtimeMinutes)} 小时 · ${yuanGrouped(_day.overtimeAmount)}',
                            icon: Icons.nightlight_round,
                            color: Pal.spark(context),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 本月概要
            Row(
              children: [
                Expanded(
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('本月合计',
                            style: TextStyle(fontSize: 12.5, color: muted)),
                        const SizedBox(height: 6),
                        MoneyText(_month.total, size: 20, weight: FontWeight.w700),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('本月件数', style: TextStyle(fontSize: 12.5, color: muted)),
                        const SizedBox(height: 6),
                        Text('${_month.pieceQty} 件',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                fontFeatures: tabularFigures)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            SectionHeader('今天记的', trailing: count > 0 ? '共 $count 笔' : null),
            if (count == 0)
              const EmptyState(
                title: '今天还没记',
                subtitle: '点右下角「记一笔」，把第一扎记上',
              )
            else
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    ..._records.map((r) => _RecordRow(
                          record: r,
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => EntryPage(editing: r)));
                          },
                        )),
                    ..._overtimes.map((o) => _OvertimeRow(
                          record: o,
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => OvertimePage(editing: o)));
                          },
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final WorkRecord record;
  final VoidCallback onTap;
  const _RecordRow({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = Pal.dim(context);
    final sub = [
      if (record.bundleNo.isNotEmpty) '扎 ${record.bundleNo}',
      if (record.size.isNotEmpty) '码 ${record.size}',
      if (record.operation.isNotEmpty) record.operation,
      if (record.note.isNotEmpty) record.note,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PhotoMark(record.photo.isNotEmpty),
                      Expanded(
                        child: Text(record.styleNo,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub.isEmpty ? '无扎号' : sub,
                    style: TextStyle(fontSize: 12.5, color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(record.amount, size: 17, weight: FontWeight.w700),
                const SizedBox(height: 3),
                Text('${record.qty} 件 × ${yuanCsv(record.unitPrice)}',
                    style: TextStyle(fontSize: 12, color: muted, fontFeatures: tabularFigures)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OvertimeRow extends StatelessWidget {
  final OvertimeRecord record;
  final VoidCallback onTap;
  const _OvertimeRow({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = Pal.dim(context);
    final amber = Pal.spark(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.nightlight_round, size: 16, color: amber),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('加班',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: amber)),
                  const SizedBox(height: 3),
                  Text(
                    record.note.isEmpty
                        ? '${hoursText(record.minutes)} 小时'
                        : '${hoursText(record.minutes)} 小时 · ${record.note}',
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(record.amount, size: 17, weight: FontWeight.w700),
                const SizedBox(height: 3),
                Text('${hoursText(record.minutes)} 时 × ${yuanCsv(record.hourPrice)}',
                    style: TextStyle(fontSize: 12, color: muted, fontFeatures: tabularFigures)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
