import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeadAnalysisTab extends StatefulWidget {
  final List<dynamic> leads;
  const LeadAnalysisTab({super.key, required this.leads});

  @override
  State<LeadAnalysisTab> createState() => _LeadAnalysisTabState();
}

class _LeadAnalysisTabState extends State<LeadAnalysisTab> {
  // Set initial filter to current month
  DateTime fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime toDate = DateTime.now();
  List<dynamic> filteredLeads = [];
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _filterData(); // Run filter immediately on load
  }

  @override
  void didUpdateWidget(covariant LeadAnalysisTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the data arrives late from the API, re-run the filter
    if (oldWidget.leads != widget.leads) {
      _filterData();
    }
  }

  void _filterData() {
    setState(() {
      filteredLeads = widget.leads.where((lead) {
        if (lead == null || lead["Date"] == null || lead["Date"].toString().trim().isEmpty) {
          return false;
        }
        
        try {
          DateTime leadDate = _parseSheetDate(lead["Date"].toString().trim());
          
          // Normalize dates to remove time comparison (only compare Year, Month, Day)
          DateTime pureLeadDate = DateTime(leadDate.year, leadDate.month, leadDate.day);
          DateTime pureFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
          DateTime pureTo = DateTime(toDate.year, toDate.month, toDate.day);

          return (pureLeadDate.isAtSameMomentAs(pureFrom) || pureLeadDate.isAfter(pureFrom)) &&
                 (pureLeadDate.isAtSameMomentAs(pureTo) || pureLeadDate.isBefore(pureTo));
        } catch (e) {
          debugPrint("Date Parsing Error: $e for value: ${lead["Date"]}");
          return false;
        }
      }).toList();
    });
  }

  // STRENGTHENED DATE PARSING
  DateTime _parseSheetDate(String dateStr) {
    try {
      // Try dd/MM/yyyy or d/M/yyyy (Common in Indian/UK Sheets)
      return DateFormat("d/M/yyyy").parse(dateStr);
    } catch (_) {
      try {
        // Try MM/dd/yyyy (US Style)
        return DateFormat("M/d/yyyy").parse(dateStr);
      } catch (__) {
        // Try standard ISO 2024-09-02
        return DateTime.parse(dateStr);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Generate counts based on "Status"
    Map<String, int> statusCounts = {};
    for (var lead in filteredLeads) {
      String status = lead["Status"]?.toString().trim() ?? "No Status";
      if (status.isNotEmpty) {
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
    }
    List<String> dynamicColumns = statusCounts.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          const SizedBox(height: 25),
          if (filteredLeads.isEmpty)
             const Center(child: Padding(
               padding: EdgeInsets.all(40.0),
               child: Text("No leads found for selected dates.", style: TextStyle(color: Colors.grey)),
             ))
          else
            _buildDynamicTable(statusCounts, dynamicColumns),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF212327), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10)
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 15,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _dateField("From:", fromDate, (d) => setState(() => fromDate = d)),
          _dateField("To:", toDate, (d) => setState(() => toDate = d)),
          ElevatedButton(
            onPressed: _filterData,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text("Apply Filter", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicTable(Map<String, int> counts, List<String> columns) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF212327), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10)
      ),
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1A1C1E)),
              columns: [
                const DataColumn(label: Text("Total Lead", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                ...columns.map((col) => DataColumn(label: Text(col, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)))),
              ],
              rows: [
                DataRow(cells: [
                  DataCell(Text(filteredLeads.length.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ...columns.map((col) => DataCell(Text(counts[col].toString(), style: const TextStyle(color: Colors.white)))),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime date, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        DateTime? p = await showDatePicker(
          context: context, 
          initialDate: date, 
          firstDate: DateTime(2020), 
          lastDate: DateTime(2030),
        );
        if (p != null) onPick(p);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label ", style: const TextStyle(color: Colors.grey)),
          Text(DateFormat('dd-MM-yyyy').format(date), style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
          const Icon(Icons.calendar_today, size: 14, color: Colors.cyanAccent),
        ],
      ),
    );
  }
}