import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryService>(
      builder: (_, lib, __) {
        final stats = lib.stats;
        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reading Stats',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Your reading journey',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary)),
                      const SizedBox(height: 20),

                      // Stat cards
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          StatCard(
                            label: 'Books finished',
                            value: '${stats.totalBooksRead}',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppTheme.success,
                          ),
                          StatCard(
                            label: 'Total reading time',
                            value: stats.totalReadingTimeLabel,
                            icon: Icons.timer_outlined,
                            color: AppTheme.primary,
                          ),
                          StatCard(
                            label: 'Pages read',
                            value: '${stats.totalPagesRead}',
                            icon: Icons.article_outlined,
                            color: AppTheme.warning,
                          ),
                          StatCard(
                            label: 'Day streak',
                            value: '${stats.currentStreak}',
                            icon: Icons.local_fire_department_outlined,
                            color: AppTheme.accentWarm,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Reading activity chart
                      const SectionHeader(title: 'Reading activity'),
                      _ActivityChart(dailyMinutes: stats.dailyMinutes),
                      const SizedBox(height: 24),

                      // Library breakdown
                      const SectionHeader(title: 'Library breakdown'),
                      _LibraryBreakdown(lib: lib),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final Map<String, int> dailyMinutes;
  const _ActivityChart({required this.dailyMinutes});

  @override
  Widget build(BuildContext context) {
    // Generate last 7 days
    final days = List.generate(7, (i) {
      final date = DateTime.now().subtract(Duration(days: 6 - i));
      final key = date.toIso8601String().substring(0, 10);
      return FlSpot(i.toDouble(), (dailyMinutes[key] ?? 0).toDouble());
    });

    final labels = List.generate(7, (i) {
      final date = DateTime.now().subtract(Duration(days: 6 - i));
      return ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];
    });

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppTheme.bgHighlight,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  labels[v.toInt()],
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}m',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                ),
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: days,
              isCurved: true,
              color: AppTheme.primary,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryBreakdown extends StatelessWidget {
  final LibraryService lib;
  const _LibraryBreakdown({required this.lib});

  @override
  Widget build(BuildContext context) {
    final docs = lib.documents;
    final total = docs.length;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Import documents to see stats',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ),
      );
    }

    // Single-pass counting optimization
    var pdfs = 0, epubs = 0, txts = 0, docxs = 0;
    for (var doc in docs) {
      switch (doc.type) {
        case DocumentType.pdf:
          pdfs++;
          break;
        case DocumentType.epub:
          epubs++;
          break;
        case DocumentType.txt:
          txts++;
          break;
        case DocumentType.docx:
          docxs++;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _BreakdownRow('PDF', pdfs, total, AppTheme.pdfColor),
          _BreakdownRow('EPUB', epubs, total, AppTheme.epubColor),
          _BreakdownRow('TXT', txts, total, AppTheme.txtColor),
          _BreakdownRow('DOCX', docxs, total, AppTheme.docxColor),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _BreakdownRow(this.label, this.count, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary))),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppTheme.bgHighlight,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$count',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
