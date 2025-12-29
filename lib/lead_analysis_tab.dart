import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class LeadAnalysisTab extends StatefulWidget {
  final List<dynamic> leads;
  final List<dynamic> employees;
  const LeadAnalysisTab({
    super.key,
    required this.leads,
    required this.employees,
  });

  @override
  State<LeadAnalysisTab> createState() => _LeadAnalysisTabState();
}

class _LeadAnalysisTabState extends State<LeadAnalysisTab> {
  DateTime fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime toDate = DateTime.now();
  List<dynamic> filteredLeads = [];

  final ScrollController _horizontalController1 = ScrollController();
  final ScrollController _horizontalController2 = ScrollController();
  final ScrollController _horizontalController3 = ScrollController();
  final ScrollController _verticalTableController = ScrollController();

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
        } catch (e) {
          return false;
        }
      }).toList();
    });
  }

  DateTime _parseSheetDate(String dateStr) {
    try {
      return DateFormat("d/M/yyyy").parse(dateStr.trim());
    } catch (_) {
      return DateTime.parse(dateStr.trim());
    }
  }

  String _getEmployeeName(String empid) {
    var emp = widget.employees.firstWhere(
      (e) => e["EMPID"].toString().trim() == empid.trim(),
      orElse: () => null,
    );
    return emp != null ? emp["Name"].toString() : empid;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, int> statusCounts = {};
    for (var lead in filteredLeads) {
      String status = lead["Status"]?.toString().trim() ?? "Unknown";
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    List<String> statusCols = statusCounts.keys.toList()..sort();

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
          const SizedBox(height: 15),
          Text(
            "Showing results from ${DateFormat('dd MMM yyyy').format(fromDate)} to ${DateFormat('dd MMM yyyy').format(toDate)}",
            style: TextStyle(color: Colors.cyanAccent.withOpacity(0.7), fontSize: 12),
          ),
          const SizedBox(height: 30),

          const Text("Status Overview", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildStatusTable(statusCols, statusCounts),

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
                        // Adjusted Flex: Table increased slightly, Graph decreased slightly
                        Expanded(flex: 22, child: _buildTmeTable(tmeMetrics)),
                        const SizedBox(width: 20),
                        Expanded(flex: 28, child: _buildChartCard(tmeMetrics)),
                      ],
                    )
                  else ...[
                    _buildTmeTable(tmeMetrics),
                    const SizedBox(height: 20),
                    _buildChartCard(tmeMetrics),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTable(List<String> statusCols, Map<String, int> statusCounts) {
    return _buildHorizontalScrollTable(
      _horizontalController1,
      DataTable(
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
      ),
    );
  }

  Widget _buildTmeTable(Map<String, Map<String, dynamic>> tmeMetrics) {
    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: const Color(0xFF212327),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Sticky Header Row with White Underline
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1C1E),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 1), // The white line under the header
              ),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text("TME Name", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text("Total", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text("Closed", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text("Pending", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text("Not Converted", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          // Scrollable Table Body
          Expanded(
            child: Theme(
              data: ThemeData(
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all(Colors.cyanAccent.withOpacity(0.5)),
                  thickness: WidgetStateProperty.all(6),
                  radius: const Radius.circular(10),
                ),
              ),
              child: Scrollbar(
                controller: _verticalTableController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _verticalTableController,
                  itemCount: tmeMetrics.length,
                  itemBuilder: (context, index) {
                    var entry = tmeMetrics.entries.elementAt(index);
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(_getEmployeeName(entry.key), style: const TextStyle(color: Colors.white, fontSize: 12))),
                          Expanded(child: Text(entry.value["total"].toString(), style: const TextStyle(color: Colors.white, fontSize: 12))),
                          Expanded(child: Text(entry.value["closed"].toString(), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(child: Text(entry.value["pending"].toString(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
                          Expanded(child: Text(entry.value["notConv"].toString(), style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(Map<String, Map<String, dynamic>> tmeMetrics) {
    List<MapEntry<String, double>> performanceData = tmeMetrics.entries.map((e) {
      double closed = (e.value["closed"] as int).toDouble();
      return MapEntry(e.key, closed);
    }).toList();
    performanceData.sort((a, b) => b.value.compareTo(a.value));

    return Container(
      height: 480,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sales Closed Ranking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 30),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double spacingPerBar = 75.0;
                double calculatedWidth = performanceData.length * spacingPerBar;
                double finalWidth = calculatedWidth > constraints.maxWidth ? calculatedWidth : constraints.maxWidth;

                return Theme(
                  data: ThemeData(
                    scrollbarTheme: ScrollbarThemeData(
                      thumbColor: WidgetStateProperty.all(Colors.cyanAccent.withOpacity(0.8)),
                      trackVisibility: WidgetStateProperty.all(true),
                      thickness: WidgetStateProperty.all(8.0),
                    ),
                  ),
                  child: Scrollbar(
                    controller: _horizontalController3,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalController3,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 25), // Padding for scrollbar
                        child: SizedBox(
                          width: finalWidth,
                          child: performanceData.isEmpty 
                            ? const Center(child: Text("No data", style: TextStyle(color: Colors.grey)))
                            : BarChart(_getBarChartData(performanceData)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _buildCustomLegend(),
        ],
      ),
    );
  }

  BarChartData _getBarChartData(List<MapEntry<String, double>> performanceData) {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: 15,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.blueGrey.shade900.withOpacity(0.9),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            String name = _getEmployeeName(performanceData[groupIndex].key);
            return BarTooltipItem('$name\nClosed: ${rod.toY.toInt()}', const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold));
          },
        ),
      ),
      gridData: FlGridData(show: true, horizontalInterval: 5, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05))),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)))),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, 
            reservedSize: 40, // Increased to show names fully
            getTitlesWidget: (v, m) {
              if (v.toInt() < 0 || v.toInt() >= performanceData.length) return const SizedBox.shrink();
              String name = _getEmployeeName(performanceData[v.toInt()].key).split(' ').first;
              return SideTitleWidget(meta: m, space: 10, child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 10)));
            }
          ),
        ),
        rightTitles: const AxisTitles(), topTitles: const AxisTitles(),
      ),
      barGroups: performanceData.asMap().entries.map((e) {
        double sales = e.value.value;
        Color barColor = sales >= 7 ? Colors.greenAccent : sales >= 3 ? Colors.cyanAccent : sales >= 1 ? Colors.orangeAccent : Colors.redAccent;
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: sales, color: barColor, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(show: true, toY: 15, color: Colors.white.withOpacity(0.02)),
          ),
        ]);
      }).toList(),
    );
  }

  Widget _buildCustomLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem("Exc (7+)", Colors.greenAccent),
          const SizedBox(width: 10),
          _legendItem("Good (3-6)", Colors.cyanAccent),
          const SizedBox(width: 10),
          _legendItem("Avg (1-2)", Colors.orangeAccent),
          const SizedBox(width: 10),
          _legendItem("Poor (0)", Colors.redAccent),
        ],
      ),
    );
  }

  Widget _legendItem(String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.grey, fontSize: 9)),
    ]);
  }

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
            onPressed: _filterData, icon: const Icon(Icons.filter_list, color: Colors.black, size: 18),
            label: const Text("APPLY FILTER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
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
              Text(DateFormat('dd-MM-yyyy').format(date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            const SizedBox(width: 10),
            const Icon(Icons.calendar_today, size: 14, color: Colors.cyanAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalScrollTable(ScrollController controller, DataTable table) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF212327), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Theme(
        data: ThemeData(
          scrollbarTheme: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(Colors.cyanAccent.withOpacity(0.8)),
            trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
            trackVisibility: WidgetStateProperty.all(true),
            thickness: WidgetStateProperty.all(8.0),
          ),
        ),
        child: Scrollbar(
          controller: controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: Padding(padding: const EdgeInsets.only(bottom: 15), child: table),
          ),
        ),
      ),
    );
  }
}