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
    // Analytics Logic
    Map<String, int> statusCounts = {};
    for (var lead in filteredLeads) {
      String status = lead["Status"]?.toString().trim() ?? "Unknown";
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    List<String> statusCols = statusCounts.keys.toList()..sort();

    Map<String, Map<String, int>> tmeMetrics = {};
    for (var lead in filteredLeads) {
      String tmeId = lead["Tellemarketing Executive"]?.toString() ?? "N/A";
      String status = lead["Status"]?.toString().trim() ?? "";
      tmeMetrics.putIfAbsent(tmeId, () => {"total": 0, "closed": 0, "pending": 0, "notConv": 0});
      var m = tmeMetrics[tmeId]!;
      m["total"] = m["total"]! + 1;
      if (status == "Sale closed") m["closed"] = m["closed"]! + 1;
      else if (["Not converted", "Sale not closed", "Not Interested"].contains(status)) m["notConv"] = m["notConv"]! + 1;
      else m["pending"] = m["pending"]! + 1;
    }

    return SingleChildScrollView(
      // Ensure the scroll view itself has a defined physics to prevent conflict
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAttractiveFilterBar(),
          const SizedBox(height: 30),
          
          // STATUS OVERVIEW SECTION
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

          // TME PERFORMANCE SECTION - Structured with explicit heights to fix errors
          const Text("TME Performance", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          // Using a Column for mobile-first compatibility if needed, 
          // but styled as a Row layout for Web/Desktop
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildTmeTable(tmeMetrics)),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _buildChartCard(statusCounts)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildTmeTable(tmeMetrics),
                    const SizedBox(height: 20),
                    _buildChartCard(statusCounts),
                  ],
                );
              }
            }
          ),
        ],
      ),
    );
  }

  Widget _buildAttractiveFilterBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF212327),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 15,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _filterDateBox("FROM", fromDate, (d) => setState(() => fromDate = d)),
          _filterDateBox("TO", toDate, (d) => setState(() => toDate = d)),
          ElevatedButton.icon(
            onPressed: _filterData,
            icon: const Icon(Icons.filter_list, color: Colors.black),
            label: const Text("APPLY FILTER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
                Text(DateFormat('dd-MM-yyyy').format(date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(width: 10),
            const Icon(Icons.calendar_today, size: 16, color: Colors.cyanAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalScrollTable(ScrollController controller, DataTable table) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF212327), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      ),
    );
  }

  Widget _buildTmeTable(Map<String, Map<String, int>> tmeMetrics) {
    return Container(
      height: 400, // Explicit height to prevent "RenderBox with no size"
      decoration: BoxDecoration(color: const Color(0xFF212327), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Scrollbar(
        controller: _horizontalController2,
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
                DataColumn(label: Text("Not Conv", style: TextStyle(color: Colors.cyanAccent))),
              ],
              rows: tmeMetrics.entries.map((e) => DataRow(cells: [
                DataCell(Text(_getEmployeeName(e.key), style: const TextStyle(color: Colors.white, fontSize: 12))),
                DataCell(Text(e.value["total"].toString(), style: const TextStyle(color: Colors.white))),
                DataCell(Text(e.value["closed"].toString(), style: const TextStyle(color: Colors.white))),
                DataCell(Text(e.value["pending"].toString(), style: const TextStyle(color: Colors.white))),
                DataCell(Text(e.value["notConv"].toString(), style: const TextStyle(color: Colors.white))),
              ])).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(Map<String, int> statusData) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF212327),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Status Analytics", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: statusData.isEmpty 
              ? const Center(child: Text("No data found", style: TextStyle(color: Colors.grey)))
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (statusData.values.isEmpty ? 10 : statusData.values.reduce((a, b) => a > b ? a : b).toDouble()) + 5,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) { // Explicitly define TitleMeta
                            if (value.toInt() < 0 || value.toInt() >= statusData.length) return const SizedBox.shrink();
                            
                            return SideTitleWidget(
                              meta: meta, // Pass the meta object directly
                              space: 8,   // Replaces axisSide for positioning
                              child: Text(
                                statusData.keys.elementAt(value.toInt()).substring(0, 3), 
                                style: const TextStyle(color: Colors.grey, fontSize: 10)
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: statusData.entries.toList().asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [BarChartRodData(toY: e.value.value.toDouble(), color: Colors.cyanAccent, width: 16)],
                      );
                    }).toList(),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}