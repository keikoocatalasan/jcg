import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() =>
      _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  int _selectedRangeDays = 7;
  bool _isLoading = true;
  String? _error;

  List<_DailyCount> _userGrowth = [];
  List<_DailyCount> _mealLogs = [];
  List<_DailyCount> _hydrationLogs = [];
  List<_DailyCount> _weightLogs = [];
  List<_DailyCount> _aiScans = [];
  List<_DailyCount> _postsCreated = [];
  List<_DailyCount> _reportsFiled = [];
  int _totalFoods = 0;
  int _totalOfficialFoods = 0;
  int _reportResolutionRate = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final supabase = ref.read(supabaseClientProvider);
      final result = await supabase.rpc('admin_analytics_snapshot', params: {
        'p_range_days': _selectedRangeDays,
      });
      if (result == null) return;

      final data = result as Map<String, dynamic>;

      _userGrowth = _parseDailyCounts(data['user_growth']);
      _mealLogs = _parseDailyCounts(data['meal_logs']);
      _hydrationLogs = _parseDailyCounts(data['hydration_logs']);
      _weightLogs = _parseDailyCounts(data['weight_logs']);
      _aiScans = _parseDailyCounts(data['ai_scans']);
      _postsCreated = _parseDailyCounts(data['posts_created']);
      _reportsFiled = _parseDailyCounts(data['reports_filed']);
      _totalFoods = (data['total_foods'] as num?)?.toInt() ?? 0;
      _totalOfficialFoods =
          (data['total_official_foods'] as num?)?.toInt() ?? 0;
      _reportResolutionRate =
          (data['report_resolution_rate'] as num?)?.toInt() ?? 0;

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Live statistics are unavailable. Check the server migration and try again.';
          _isLoading = false;
        });
      }
    }
  }

  List<_DailyCount> _parseDailyCounts(dynamic raw) {
    if (raw == null || raw is! List) return [];
    return raw
        .map((e) => _DailyCount(
              date: e['date'] as String,
              count: (e['count'] as num).toInt(),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Statistics'),
        actions: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7d')),
              ButtonSegment(value: 30, label: Text('30d')),
              ButtonSegment(value: 90, label: Text('90d')),
            ],
            selected: {_selectedRangeDays},
            onSelectionChanged: (v) {
              setState(() => _selectedRangeDays = v.first);
              _loadData();
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.accentPrimary,
              selectedForegroundColor: AppColors.textOnAccent,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: GlassBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                            onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSectionHeader('User Growth', Icons.people),
                      _buildLineChart(_userGrowth, AppColors.accentPrimary),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                          'Engagement — Meal Logs', Icons.restaurant),
                      _buildBarChart(_mealLogs, AppColors.accentPrimary),
                      const SizedBox(height: 16),
                      _buildSectionHeader('Hydration Logs', Icons.water_drop),
                      _buildBarChart(_hydrationLogs, AppColors.proteinColor),
                      const SizedBox(height: 16),
                      _buildSectionHeader('Weight Logs', Icons.monitor_weight),
                      _buildBarChart(_weightLogs, AppColors.carbsColor),
                      const SizedBox(height: 16),
                      _buildSectionHeader('AI Scans', Icons.camera_alt),
                      _buildBarChart(_aiScans, AppColors.accentPrimary),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Community Activity', Icons.forum),
                      _buildBarChartOverlay(
                          _postsCreated, _reportsFiled, 'Posts', 'Reports'),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Database Health', Icons.storage),
                      _buildDbHealthCard(theme),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                          'Report Resolution', Icons.check_circle),
                      _buildResolutionCard(theme),
                      const SizedBox(height: 32),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accentPrimary),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<_DailyCount> data, Color color) {
    if (data.isEmpty) return _emptyChart();
    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.count.toDouble()))
        .toList();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.divider.withAlpha(51), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (data.length / 5).ceilToDouble().clamp(1, 100),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Text(data[i].date.substring(5),
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary));
                },
              ),
            ),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: FlDotData(show: data.length <= 31),
              belowBarData:
                  BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<_DailyCount> data, Color color) {
    if (data.isEmpty) return _emptyChart();

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          barGroups: data.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.count.toDouble(),
                  color: color,
                  width: _selectedRangeDays <= 7
                      ? 16
                      : _selectedRangeDays <= 30
                          ? 6
                          : 3,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(3)),
                ),
              ],
            );
          }).toList(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.divider.withAlpha(51), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: _selectedRangeDays <= 30,
                reservedSize: 20,
                interval: (data.length / 6).ceilToDouble().clamp(1, 100),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  final parts = data[i].date.split('-');
                  return Text(
                      parts.length >= 3
                          ? '${parts[1]}/${parts[2]}'
                          : data[i].date,
                      style: const TextStyle(
                          fontSize: 8, color: AppColors.textSecondary));
                },
              ),
            ),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) => value == 0
                        ? const SizedBox.shrink()
                        : Text('${value.toInt()}',
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.textSecondary)))),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChartOverlay(List<_DailyCount> data1, List<_DailyCount> data2,
      String label1, String label2) {
    if (data1.isEmpty || data2.isEmpty) return _emptyChart();
    final overallMax =
        (data1.fold<int>(0, (m, d) => d.count > m ? d.count : m) >
                data2.fold<int>(0, (m, d) => d.count > m ? d.count : m))
            ? data1.fold<int>(0, (m, d) => d.count > m ? d.count : m)
            : data2.fold<int>(0, (m, d) => d.count > m ? d.count : m);

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.center,
              maxY: (overallMax * 1.2).ceilToDouble(),
              barGroups: data1.asMap().entries.map((e) {
                final count2 = e.key < data2.length ? data2[e.key].count : 0;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.count.toDouble(),
                      color: AppColors.accentPrimary,
                      width: _selectedRangeDays <= 7 ? 7 : 4,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          topRight: Radius.circular(2)),
                    ),
                    BarChartRodData(
                      toY: count2.toDouble(),
                      color: AppColors.error,
                      width: _selectedRangeDays <= 7 ? 7 : 4,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          topRight: Radius.circular(2)),
                    ),
                  ],
                );
              }).toList(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.divider.withAlpha(51), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(AppColors.accentPrimary, label1),
            const SizedBox(width: 16),
            _legendDot(AppColors.error, label2),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _emptyChart() {
    return const SizedBox(
      height: 100,
      child: Center(
        child: Text('No data for this period',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildDbHealthCard(ThemeData theme) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _metricColumn('Total Foods', '$_totalFoods'),
            ),
            Expanded(
              child: _metricColumn('Official Foods', '$_totalOfficialFoods'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.accentPrimary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildResolutionCard(ThemeData theme) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$_reportResolutionRate%',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimary)),
            const SizedBox(height: 4),
            const Text('Report Resolution Rate',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _reportResolutionRate / 100,
                backgroundColor: AppColors.surface,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyCount {
  final String date;
  final int count;
  const _DailyCount({required this.date, required this.count});
}
