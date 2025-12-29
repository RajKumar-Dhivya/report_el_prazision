import 'package:flutter/material.dart';
import 'workorder_summary.dart';

class MonthlyDetailPage extends StatefulWidget {
  final WorkOrderSummary summary;
  final List<dynamic> workOrders;
  final List<dynamic> customers;
  final List<dynamic> payments;
  final List<dynamic> expenses;
  final List<dynamic> usedProducts;
  final List<dynamic> materialLog;

  const MonthlyDetailPage({
    super.key,
    required this.summary,
    required this.workOrders,
    required this.customers,
    required this.payments,
    required this.expenses,
    required this.usedProducts,
    required this.materialLog,
  });

  @override
  State<MonthlyDetailPage> createState() => _MonthlyDetailPageState();
}

class _MonthlyDetailPageState extends State<MonthlyDetailPage> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalTableController = ScrollController();
  
  bool loading = true;
  List<Map<String, dynamic>> rows = [];
  int loanCount = 0;
  int cashCount = 0;

  @override
  void initState() {
    super.initState();
    processData();
    setState(() => loading = false);
  }

  void processData() {
    rows.clear();
    loanCount = 0;
    cashCount = 0;

    for (var wo in widget.workOrders) {
      if (wo == null) continue;
      String recordedDate = wo["Recorded Date"] ?? "";
      if (recordedDate.isEmpty) continue;

      DateTime dt = DateTime.parse(recordedDate);
      if ("${_monthName(dt.month)} ${dt.year}" != widget.summary.monthYear) continue;

      String workOrderId = wo["ID"].toString().trim();
      String paymentMode = (wo["Payment Mode"] ?? "").toString().toLowerCase();

      if (paymentMode.contains("loan")) loanCount++;
      else if (paymentMode.contains("cash")) cashCount++;

      String customerId = wo["Customer Name"].toString();
      String customerName = widget.customers.firstWhere(
        (c) => c["ID"].toString() == customerId,
        orElse: () => {"Customer Name": "Unknown"},
      )["Customer Name"];

      double received = widget.payments
          .where((p) => p["Work Order ID"].toString().trim() == workOrderId)
          .fold(0.0, (sum, p) => sum + (double.tryParse(p["Received Payment"]?.toString() ?? "0") ?? 0));

      double directExpense = widget.expenses
          .where((exp) => exp["Work order ID"].toString().trim() == workOrderId)
          .fold(0.0, (sum, item) => sum + (double.tryParse(item["Amount"].toString()) ?? 0.0));

      double productCost = 0;
      var woUsed = widget.usedProducts.where((up) => up["Work Order id"].toString().trim() == workOrderId);
      for (var p in woUsed) {
        double qty = double.tryParse(p["used quantity"].toString()) ?? 0;
        double unitPrice = widget.materialLog
            .where((ml) => ml["ID"].toString().trim() == p["product id"].toString().trim())
            .fold(0.0, (sum, item) => sum + (double.tryParse(item["Unit Price with GST"].toString()) ?? 0.0));
        productCost += (qty * unitPrice);
      }

      double totalAmount = double.tryParse(wo["Total Amount"].toString()) ?? 0;
      rows.add({
        "customer": customerName,
        "kw": wo["Sanction Load/KW"] ?? "0",
        "mode": wo["Payment Mode"] ?? "N/A",
        "amount": totalAmount,
        "received": received,
        "outstanding": totalAmount - received,
        "expense": directExpense + productCost,
        "profit": totalAmount - (directExpense + productCost),
      });
    }
  }

  String _monthName(int m) => ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][m];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SelectionArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1113),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1C1E),
          title: SelectableText("${widget.summary.monthYear} Analysis", 
              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.cyanAccent),
          elevation: 0,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
            : SingleChildScrollView( // Main scroll for the whole page
                child: Column(
                  children: [
                    _buildHeaderStats(screenWidth),
                    _buildRatioSection(),
                    const SizedBox(height: 16),
                    
                    // Fixed height container for the table to prevent overflow
                    // On mobile, it takes 500px height; on laptop, it takes more
                    Container(
                      height: screenHeight > 800 ? 600 : 450, 
                      child: _buildScrollableTableContainer(screenWidth),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderStats(double screenWidth) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _miniStatCard("Orders", "${rows.length}", Colors.blue, screenWidth),
          _miniStatCard("Total KW", "${widget.summary.sanctionLoad.toStringAsFixed(1)}", Colors.purpleAccent, screenWidth),
          _miniStatCard("Expenses", "₹${(widget.summary.totalAmount - widget.summary.profit).toStringAsFixed(0)}", Colors.orangeAccent, screenWidth),
          _miniStatCard("Net Profit", "₹${widget.summary.profit.toStringAsFixed(0)}", Colors.greenAccent, screenWidth),
          _miniStatCard("Outstanding", "₹${widget.summary.outstanding.toStringAsFixed(0)}", Colors.redAccent, screenWidth),
        ],
      ),
    );
  }

  Widget _miniStatCard(String label, String value, Color color, double screenWidth) {
    double cardWidth = screenWidth > 1100 ? (screenWidth / 6.2) : (screenWidth / 2.4);
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          SelectableText(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SelectableText(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildRatioSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SelectableText("PAYMENT DISTRIBUTION", 
            style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildAttractiveBar("Loan Payments", loanCount, rows.length, Colors.blueAccent, Icons.account_balance),
          const SizedBox(height: 12),
          _buildAttractiveBar("Cash / Direct", cashCount, rows.length, Colors.orangeAccent, Icons.payments),
        ],
      ),
    );
  }

  Widget _buildAttractiveBar(String label, int count, int total, Color color, IconData icon) {
    double percent = total > 0 ? count / total : 0;
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SelectableText(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  SelectableText("$count Case(s) • ${(percent * 100).toStringAsFixed(1)}%", 
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: percent, minHeight: 6, backgroundColor: Colors.white10, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableTableContainer(double screenWidth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: ThemeData.dark().copyWith(
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(Colors.cyanAccent.withOpacity(0.6)),
              trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
              thickness: WidgetStateProperty.all(6),
              radius: const Radius.circular(10),
            ),
          ),
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: screenWidth > 1132 ? (screenWidth - 32) : 1100,
                child: Column(
                  children: [
                    _buildTableHeader(), // Sticky Header
                    Expanded(
                      child: Scrollbar(
                        controller: _verticalTableController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _verticalTableController,
                          padding: EdgeInsets.zero,
                          itemCount: rows.length,
                          itemBuilder: (context, index) => _buildDataRow(rows[index]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF212327),
        border: Border(bottom: BorderSide(color: Colors.cyanAccent, width: 2.5)),
      ),
      child: Row(
        children: [
          _cell("CUSTOMER NAME", flex: 3, isHeader: true,),
          _cell("KW", flex: 2, isHeader: true),
          _cell("PAYMENT MODE", flex: 2, isHeader: true),
          _cell("TOTAL VALUE", flex: 2, isHeader: true),
          _cell("RECEIVED", flex: 2, isHeader: true),
          _cell("OUTSTANDING", flex: 2, isHeader: true),
          _cell("EXPENSE", flex: 2, isHeader: true),
          _cell("PROFIT", flex: 2, isHeader: true),
        ],
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
      child: Row(
        children: [
          _cell(r["customer"], flex: 3, isBold: true, color: Colors.white),
          _cell(r["kw"].toString(), flex: 2),
          _cell(r["mode"], flex: 2),
          _cell("₹${r["amount"].toStringAsFixed(0)}", flex: 2),
          _cell("₹${r["received"].toStringAsFixed(0)}", flex: 2, color: Colors.greenAccent),
          _cell("₹${r["outstanding"].toStringAsFixed(0)}", flex: 2, color: Colors.redAccent),
          _cell("₹${r["expense"].toStringAsFixed(0)}", flex: 2, color: Colors.orangeAccent),
          _cell("₹${r["profit"].toStringAsFixed(0)}", flex: 2, color: r["profit"] >= 0 ? Colors.cyanAccent : Colors.redAccent, isBold: true),
        ],
      ),
    );
  }

  Widget _cell(String text, {int flex = 1, bool isHeader = false, bool isBold = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: SelectableText(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: isHeader ? 11 : 13,
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.cyanAccent : (color ?? Colors.white70),
        ),
      ),
    );
  }
}