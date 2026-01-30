import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ComplianceDashboardPage extends StatefulWidget {
  final String authorityId;

  const ComplianceDashboardPage({
    Key? key,
    required this.authorityId,
  }) : super(key: key);

  @override
  State<ComplianceDashboardPage> createState() =>
      _ComplianceDashboardPageState();
}

class _ComplianceDashboardPageState extends State<ComplianceDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedChartIndex = 0;

  final List<ComplianceData> _complianceData = [
    ComplianceData('Annual Reporting', 85, Colors.blue),
    ComplianceData('Safety Standards', 92, Colors.green),
    ComplianceData('Financial Audit', 78, Colors.orange),
    ComplianceData('Environmental', 65, Colors.teal),
    ComplianceData('Data Privacy', 88, Colors.purple),
  ];

  final List<ViolationData> _violationData = [
    ViolationData('Jan', 12),
    ViolationData('Feb', 8),
    ViolationData('Mar', 15),
    ViolationData('Apr', 10),
    ViolationData('May', 7),
    ViolationData('Jun', 11),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.warning), text: 'Violations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAnalyticsTab(),
          _buildViolationsTab(),
        ],
      ),
    );
  }

  // ================= OVERVIEW TAB =================

  Widget _buildOverviewTab() {
    final overallCompliance = _calculateOverallCompliance();
    final overallInt = overallCompliance.round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildComplianceCircle(overallInt),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Overall Compliance',
                            style:
                            TextStyle(color: Colors.grey, fontSize: 14)),
                        Text(
                          '$overallInt%',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                        Text(
                          _getComplianceStatus(overallInt),
                          style: TextStyle(
                              color: _getComplianceColor(overallInt)),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._complianceData.map(_buildComplianceRow),
        ],
      ),
    );
  }

  // ================= ANALYTICS TAB =================

  Widget _buildAnalyticsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildChartTypeButton('Bar', 0),
              _buildChartTypeButton('Line', 1),
              _buildChartTypeButton('Pie', 2),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildSelectedChart()),
        ],
      ),
    );
  }

  // ================= VIOLATIONS TAB =================

  Widget _buildViolationsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          maxY: 20,
          barGroups: _violationData.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.count.toDouble(),
                  color: Colors.red,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _violationData[value.toInt()].month,
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  // ================= CHARTS =================

  Widget _buildSelectedChart() {
    if (_selectedChartIndex == 2) {
      return CustomPaint(
        painter: PieChartPainter(
          data: _complianceData.map((e) => e.percentage.toDouble()).toList(),
          colors: _complianceData.map((e) => e.color).toList(),
        ),
        child: const SizedBox.expand(),
      );
    }

    if (_selectedChartIndex == 1) {
      return LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                6,
                    (i) => FlSpot(i.toDouble(), 70 + i * 3),
              ),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: 100,
        barGroups: List.generate(6, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: 60 + i * 5,
                color: Colors.blue,
              )
            ],
          );
        }),
      ),
    );
  }

  // ================= HELPERS =================

  Widget _buildComplianceCircle(int percentage) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CircularProgressIndicator(
        value: percentage / 100,
        strokeWidth: 8,
        color: _getComplianceColor(percentage),
        backgroundColor: Colors.grey.shade200,
      ),
    );
  }

  Widget _buildChartTypeButton(String label, int index) {
    final selected = _selectedChartIndex == index;
    return ElevatedButton(
      onPressed: () => setState(() => _selectedChartIndex = index),
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.blue : Colors.grey.shade300,
        foregroundColor: selected ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

  Widget _buildComplianceRow(ComplianceData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(data.name)),
          Text('${data.percentage}%'),
        ],
      ),
    );
  }

  double _calculateOverallCompliance() {
    final total =
    _complianceData.fold(0, (sum, e) => sum + e.percentage);
    return total / _complianceData.length;
  }

  Color _getComplianceColor(int percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.orange;
    return Colors.red;
  }

  String _getComplianceStatus(int percentage) {
    if (percentage >= 90) return 'Excellent';
    if (percentage >= 75) return 'Good';
    if (percentage >= 60) return 'Fair';
    return 'Needs Improvement';
  }
}

// ================= PIE CHART =================

class PieChartPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;

  PieChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.reduce((a, b) => a + b);
    var startAngle = -pi / 2;
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    for (var i = 0; i < data.length; i++) {
      final sweep = (data[i] / total) * 2 * pi;
      final paint = Paint()..color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================= MODELS =================

class ComplianceData {
  final String name;
  final int percentage;
  final Color color;

  ComplianceData(this.name, this.percentage, this.color);
}

class ViolationData {
  final String month;
  final int count;

  ViolationData(this.month, this.count);
}
