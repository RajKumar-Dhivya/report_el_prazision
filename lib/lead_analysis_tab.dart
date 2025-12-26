import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class LeadAnalysisTab extends StatefulWidget {
  final List<dynamic> leads;
  final List<dynamic> employees;
  const LeadAnalysisTab({super.key, required this.leads, required this.employees});

  @override
  State<LeadAnalysisTab> createState() => _LeadAnalysisTabState();
}

class _LeadAnalysisTabState extends State<LeadAnalysisTab> {
  DateTime fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime toDate = DateTime.now();
  List<dynamic> filteredLeads = [];
  final ScrollController _horizontalController1 = ScrollController();
  final ScrollController _horizontalController2 = ScrollController();

  @override
  void initState() {
    super.initState();
    _filterData();
  }

  void _filterData() {
    setState(() {
      filteredLeads = widget.leads.where((lead) {
        if (lead == null || lead["Date"] == null || lead["Date"].toString().isEmpty) return false;
        try {
          DateTime leadDate = _parseSheetDate(lead["Date"].toString());
          DateTime start = DateTime(fromDate.year, fromDate.month, fromDate.day);
          DateTime end = DateTime(toDate.year, toDate.month, toDate.day).add(const Duration(days: 1));
          return leadDate.isAfter(start.subtract(const Duration(seconds: 1))) && leadDate.isBefore(end);
        } catch (e) { return false; }
      }).toList();
    });
  }

  DateTime _parseSheetDate(String dateStr) {
    try { return DateFormat("d/M/yyyy").parse(dateStr.trim()); } 
    catch (_) { return DateTime.parse(dateStr.trim()); }
  }

  String _getEmployeeName(String empid) {
    var emp = widget.employees.firstWhere(
      (e) => e["EMPID"].toString().trim() == empid.trim(), 
      orElse: () => null
    );
    return emp != null ? emp["Name"].toString() : empid;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Status Overview Data
    Map<String, int> statusCounts = {};
    for (var lead in filteredLeads) {
      String status = lead["Status"]?.toString().trim() ?? "Unknown";
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    List<String> statusCols = statusCounts.keys.toList()..sort();

    // 2. TME Performance Logic (Used for Table & Graph)
    Map<String, Map<String, dynamic>> tmeMetrics = {};
    for (var lead in filteredLeads) {
      String tmeId = lead["Tellemarketing Executive"]?.toString() ?? "N/A";
      String status = lead["Status"]?.toString().trim() ?? "";
      
      tmeMetrics.putIfAbsent(tmeId, () => {"total": 0, "closed": 0, "pending": 0, "notConv": 0});
      var m = tmeMetrics[tmeId]!;
      m["total"] = (m["total"] as int) + 1;

      if (status == "Sale closed") {
        m["closed"] = (m["closed"] as int) + 1;
      } else if (["Not converted", "Sale not closed", "Not Interested"].contains(status)) {
        m["notConv"] = (m["notConv"] as int) + 1;
      } else {
        m["pending"] = (m["pending"] as int) + 1;
      }
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAttractiveFilterBar(),
          const SizedBox(height: 30),
          
          const Text("Status Overview", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildHorizontalScrollTable(_horizontalController1, DataTable(
            columns: [
              const DataColumn(label: Text("Total Lead", style: TextStyle(color: Colors.cyanAccent))),
              ...statusCols.map((s) => DataColumn(label: Text(s, style: const TextStyle(color: Colors.cyanAccent)))),
            ],
            rows: [
              DataRow(cells: [
                DataCell(Text(filteredLeads.length.toString(), style: const TextStyle(color: Colors.white))),
                ...statusCols.map((s) => DataCell(Text(statusCounts[s].toString(), style: const TextStyle(color: Colors.white)))),
              ]),
            ],
          )),
          
          const SizedBox(height: 40),

          const Text("TME Performance Analytics", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 900;
              return Column(
                children: [
                  if (isWide) 
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildTmeTable(tmeMetrics)),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _buildChartCard(tmeMetrics)),
                      ],
                    )
                  else ...[
                    _buildTmeTable(tmeMetrics),
                    const SizedBox(height: 20),
                    _buildChartCard(tmeMetrics),
                  ],
                ],
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildTmeTable(Map<String, Map<String, dynamic>> tmeMetrics) {
    return Container(
      height: 480, // Slightly taller to accommodate scrollbar
      decoration: BoxDecoration(color: const Color(0xFF212327), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Scrollbar(
        controller: _horizontalController2,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalController2,
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text("TME", style: TextStyle(color: Colors.cyanAccent))),
                DataColumn(label: Text("Leads", style: TextStyle(color: Colors.cyanAccent))),
                DataColumn(label: Text("Closed", style: TextStyle(color: Colors.cyanAccent))),
                DataColumn(label: Text("Pending", style: TextStyle(color: Colors.cyanAccent))),
                DataColumn(label: Text("Not Converted", style: TextStyle(color: Colors.cyanAccent))),
              ],
              rows: tmeMetrics.entries.map((e) => DataRow(cells: [
                DataCell(Text(_getEmployeeName(e.key), style: const TextStyle(color: Colors.white, fontSize: 12))),
                DataCell(Text(e.value["total"].toString(), style: const TextStyle(color: Colors.white))),
                DataCell(Text(e.value["closed"].toString(), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                DataCell(Text(e.value["pending"].toString(), style: const TextStyle(color: Colors.orangeAccent))),
                DataCell(Text(e.value["notConv"].toString(), style: const TextStyle(color: Colors.redAccent))),
              ])).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(Map<String, Map<String, dynamic>> tmeMetrics) {
    // 1. Prepare Performance Data for EVERYONE
    List<MapEntry<String, double>> performanceData = tmeMetrics.entries.map((e) {
      double closed = (e.value["closed"] as int).toDouble();
      return MapEntry(e.key, closed); 
    }).toList();

    // Sort: Top performers on the left
    performanceData.sort((a, b) => b.value.compareTo(a.value));

    return Container(
      height: 480,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1E), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TME Performance Ranking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Text("Target: 10+ Sales Closed", style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 30),
          Expanded(
            child: performanceData.isEmpty 
              ? const Center(child: Text("No data", style: TextStyle(color: Colors.grey)))
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 15, // Realistic maximum
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.blueGrey.shade900,
                        tooltipBorderRadius: BorderRadius.circular(8), 
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          String name = _getEmployeeName(performanceData[groupIndex].key);
                          return BarTooltipItem(
                            '$name\n',
                            const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: 'Sales Closed: ${rod.toY.toInt()}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: 10,
                          color: Colors.greenAccent.withOpacity(0.3),
                          strokeWidth: 2,
                          dashArray: [10, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(right: 5, bottom: 5),
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                            labelResolver: (line) => 'TARGET: 10',
                          ),
                        ),
                      ],
                    ),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: 2,
                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, 
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value.toInt() < 0 || value.toInt() >= performanceData.length) return const SizedBox.shrink();
                            String name = _getEmployeeName(performanceData[value.toInt()].key).split(' ').first;
                            return SideTitleWidget(
                              meta: meta, 
                              space: 10, 
                              child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 9)),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: performanceData.asMap().entries.map((e) {
                      double sales = e.value.value;
                      
                      // Dynamic Color Logic based on your thresholds
                      Color barColor;
                      if (sales >= 7) {
                        barColor = Colors.greenAccent; // Excellent
                      } else if (sales >= 3) {
                        barColor = Colors.cyanAccent; // Good
                      } else if (sales >= 1) {
                        barColor = Colors.orangeAccent; // Average
                      } else {
                        barColor = Colors.redAccent; // Poor
                      }
                      
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: sales, 
                            color: barColor, 
                            width: 16,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 15,
                              color: Colors.white.withOpacity(0.02),
                            ),
                          )
                        ],
                      );
                    }).toList(),
                  ),
                ),
          ),
          const SizedBox(height: 20),
          _buildCustomLegend(),
        ],
      ),
    );
  }

  Widget _buildCustomLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _legendItem("Excellent (>6)", Colors.greenAccent),
        _legendItem("Good (3-6)", Colors.cyanAccent),
        _legendItem("Average (1-2)", Colors.orangeAccent),
        _legendItem("Poor (0)", Colors.redAccent),
      ],
    );
  }

  Widget _legendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  // Filter Bar and Date display remain the same as previous stable version
  Widget _buildAttractiveFilterBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF212327), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Wrap(
        spacing: 20, runSpacing: 15, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _filterDateBox("FROM", fromDate, (d) => setState(() => fromDate = d)),
          _filterDateBox("TO", toDate, (d) => setState(() => toDate = d)),
          ElevatedButton.icon(
            onPressed: _filterData,
            icon: const Icon(Icons.filter_list, color: Colors.black),
            label: const Text("APPLY FILTER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
          ),
        ],
      ),
    );
  }

  Widget _filterDateBox(String label, DateTime date, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        DateTime? p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (p != null) onPick(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF1A1C1E), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
              Text(DateFormat('dd-MM-yyyy').format(date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(width: 10),
            const Icon(Icons.calendar_today, size: 16, color: Colors.cyanAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalScrollTable(ScrollController controller, DataTable table) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF212327), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.white10),
      ),
      child: Theme(
        data: ThemeData(
          // This specifically targets the scrollbar appearance
          scrollbarTheme: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(Colors.cyanAccent.withOpacity(0.8)), // Bright Cyan
            trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)), // Subtle track
            trackVisibility: WidgetStateProperty.all(true), // Makes the path visible
            thickness: WidgetStateProperty.all(8.0), // Makes it thicker
            radius: const Radius.circular(10), // Rounded edges
          ),
        ),
        child: Scrollbar(
          controller: controller,
          thumbVisibility: true, // Always visible
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: Padding(
              // Adding padding at the bottom so the scrollbar doesn't cover the data
              padding: const EdgeInsets.only(bottom: 15), 
              child: table,
            ),
          ),
        ),
      ),
    );
  }
}