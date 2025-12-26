import 'package:flutter/material.dart';
import 'workorder_summary.dart';
import 'bottom_horizontal_scrollbar.dart';

class MonthlyDetailPage extends StatefulWidget {
  final WorkOrderSummary summary;
  final List<dynamic> workOrders;
  final List<dynamic> customers;
  final List<dynamic> payments;

  const MonthlyDetailPage({
    super.key,
    required this.summary,
    required this.workOrders,
    required this.customers,
    required this.payments,
  });

  @override
  State<MonthlyDetailPage> createState() => _MonthlyDetailPageState();
}

class _MonthlyDetailPageState extends State<MonthlyDetailPage> {
  // Single controller for both the table view and the custom scrollbar
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  bool loading = true;
  List<Map<String, dynamic>> rows = [];
  
  // The width the table needs to stay readable
  final double _minTableWidth = 1000.0;

  @override
  void initState() {
    super.initState();
    processData();
    setState(() => loading = false);
  }

  void processData() {
    rows.clear();
    for (var wo in widget.workOrders) {
      if (wo == null) continue;
      String recordedDate = wo["Recorded Date"] ?? "";
      if (recordedDate.isEmpty) continue;

      DateTime dt = DateTime.parse(recordedDate);
      String monthYear = "${_monthName(dt.month)} ${dt.year}";
      if (monthYear != widget.summary.monthYear) continue;

      String workOrderId = wo["ID"].toString();
      String customerId = wo["Customer Name"].toString();

      String customerName = "";
      for (var c in widget.customers) {
        if (c["ID"].toString() == customerId) {
          customerName = c["Customer Name"].toString();
          break;
        }
      }

      double advance = 0;
      for (var p in widget.payments) {
        final type = p["Type of payment"]?.toString().toLowerCase().trim();
        if (p["Work Order ID"].toString().trim() == workOrderId.trim() &&
            type != null && type.contains("advance")) {
          advance += double.tryParse(p["Received Payment"]?.toString() ?? "0") ?? 0;
        }
      }

      rows.add({
        "customer": customerName,
        "kw": wo["Sanction Load/KW"] ?? "",
        "mode": wo["Payment Mode"] ?? "",
        "amount": wo["Total Amount"] ?? "",
        "advance": advance,
      });
    }
  }

  String _monthName(int m) {
    const months = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return months[m];
  }

  DataCell selectableCell(String text, {Color? color, bool isBold = false}) {
    return DataCell(
      SelectableText(
        text,
        style: TextStyle(
          color: color ?? Colors.white70,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;

    return Scaffold(
      backgroundColor: const Color(0xFF111315),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1C1E),
        elevation: 0,
        title: SelectableText(widget.summary.monthYear, 
          style: const TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalController,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _buildTableSection()),
                            const SizedBox(width: 16),
                            Expanded(flex: 4, child: _buildGraphSection()),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildGraphSection(),
                            const SizedBox(height: 16),
                            _buildTableSection(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTableSection() {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1A1C1E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. THE ACTUAL DATA TABLE
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false), // Hide default scrollbar
          child: SingleChildScrollView(
            controller: _horizontalController, // Linked Controller
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(), // Better feel on mobile
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: _minTableWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF212327)),
                columns: const [
                  DataColumn(label: Text("Customer", style: TextStyle(color: Colors.cyanAccent))),
                  DataColumn(label: Text("K/W", style: TextStyle(color: Colors.cyanAccent))),
                  DataColumn(label: Text("Mode", style: TextStyle(color: Colors.cyanAccent))),
                  DataColumn(label: Text("Total", style: TextStyle(color: Colors.cyanAccent))),
                  DataColumn(label: Text("Advance", style: TextStyle(color: Colors.cyanAccent))),
                ],
                rows: rows.map((r) => DataRow(cells: [
                  selectableCell(r["customer"].toString(), isBold: true),
                  selectableCell(r["kw"].toString()),
                  selectableCell(r["mode"].toString()),
                  selectableCell("₹${r["amount"]}", color: Colors.greenAccent),
                  selectableCell("₹${r["advance"]}", color: Colors.cyanAccent),
                ])).toList(),
              ),
            ),
          ),
        ),
        
        // 2. THE INTERACTIVE SCROLLBAR BAR
        // We place it right under the table inside the same card
        BottomHorizontalScrollbar(
          controller: _horizontalController, // Linked Controller
          width: _minTableWidth,
        ),
      ],
    ),
  );
}

  Widget _buildGraphSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SelectableText("REVENUE OVERVIEW", 
            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildMetricRow("Received", "₹${widget.summary.amountReceived}", Colors.cyanAccent),
          const Divider(color: Colors.white10, height: 30),
          _buildMetricRow("Outstanding", "₹${widget.summary.outstanding}", Colors.redAccent),
          const SizedBox(height: 30),
          const SelectableText("Payment Status Ratio", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 15),
          _buildCustomBar("Loan Orders", widget.summary.loanCount, widget.summary.totalWorkOrders, Colors.blueAccent),
          const SizedBox(height: 10),
          _buildCustomBar("Cash Orders", widget.summary.cashCount, widget.summary.totalWorkOrders, Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SelectableText(label, style: const TextStyle(color: Colors.white60, fontSize: 16)),
        SelectableText(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCustomBar(String label, int value, int total, Color color) {
    double percent = total > 0 ? value / total : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SelectableText(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            SelectableText("$value", style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color, 
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}