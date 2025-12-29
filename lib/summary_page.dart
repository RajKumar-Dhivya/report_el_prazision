import 'package:flutter/material.dart';
import 'API CALL/google_sheets_api.dart';
import 'workorder_summary.dart';
import 'monthly_detail_page.dart';
import 'lead_analysis_tab.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();

  bool loading = true;
  Map<String, WorkOrderSummary> summaryMap = {};
  List<dynamic> receivedPayments = [];
  List<dynamic> workOrders = [];
  List<dynamic> customers = [];
  List<dynamic> leads = [];
  List<dynamic> employees = [];
  List<dynamic> expenses = [];
  List<dynamic> usedProducts = [];
  List<dynamic> materialLog = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadAllData();
  }

  Future<void> loadAllData() async {
    try {
      workOrders = await GoogleSheetsApi.getSheet("Work Orders");
      receivedPayments = await GoogleSheetsApi.getSheet("Received Payments");
      customers = await GoogleSheetsApi.getSheet("Customer");
      leads = await GoogleSheetsApi.getSheet("Lead");
      employees = await GoogleSheetsApi.getSheet("EmployeeProfile");
      expenses = await GoogleSheetsApi.getSheet("Expense");
      usedProducts = await GoogleSheetsApi.getSheet("Used Products");
      materialLog = await GoogleSheetsApi.getSheet("Material Consumption & Purchase Log");

      processWorkOrders(workOrders);
      calculateReceivedPayments();
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  void processWorkOrders(List rows) {
    summaryMap.clear();
    for (var row in rows) {
      if (row == null || row.values.every((v) => v == null || v.toString().trim().isEmpty)) continue;
      String recordedDate = row["Recorded Date"] ?? "";
      String woID = row["ID"].toString().trim();
      if (recordedDate.isEmpty) continue;

      double sanctionLoad = double.tryParse(row["Sanction Load/KW"].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      double totalAmount = double.tryParse(row["Total Amount"].toString()) ?? 0;

      double totalExpenses = expenses
          .where((exp) => exp["Work order ID"].toString().trim() == woID)
          .fold(0.0, (sum, item) => sum + (double.tryParse(item["Amount"].toString()) ?? 0.0));

      double totalProductCost = 0;
      var woUsedProducts = usedProducts.where((up) => up["Work Order id"].toString().trim() == woID);
      for (var product in woUsedProducts) {
        double qty = double.tryParse(product["used quantity"].toString()) ?? 0;
        double unitPrice = materialLog
            .where((ml) => ml["ID"].toString().trim() == product["product id"].toString().trim())
            .fold(0.0, (sum, item) => sum + (double.tryParse(item["Unit Price with GST"].toString()) ?? 0.0));
        totalProductCost += (qty * unitPrice);
      }

      double woProfit = totalAmount - (totalExpenses + totalProductCost);
      DateTime dt = DateTime.parse(recordedDate);
      String monthYear = "${_monthName(dt.month)} ${dt.year}";

      summaryMap.putIfAbsent(monthYear, () => WorkOrderSummary(monthYear));
      var s = summaryMap[monthYear]!;
      s.totalWorkOrders++;
      s.sanctionLoad += sanctionLoad;
      s.totalAmount += totalAmount;
      s.profit += woProfit;
      s.workOrderIds.add(woID);
    }
  }

  void calculateReceivedPayments() {
    for (var payment in receivedPayments) {
      String woID = payment["Work Order ID"].toString();
      double amount = double.tryParse(payment["Received Payment"].toString()) ?? 0;
      for (var s in summaryMap.values) {
        if (s.workOrderIds.contains(woID)) s.amountReceived += amount;
      }
    }
    for (var s in summaryMap.values) {
      s.outstanding = s.totalAmount - s.amountReceived;
    }
  }

  String _monthName(int m) {
    const months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[m];
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1C1E),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildWorkOrderContent(),
                        LeadAnalysisTab(leads: leads, employees: employees),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
      color: const Color(0xFF212327),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SelectableText("Reports & Analytics",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.grey,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(child: Text("Work Order Summary", style: TextStyle(fontSize: 13))),
              Tab(child: Text("Lead Analysis", style: TextStyle(fontSize: 13))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkOrderContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _mainScrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildSummaryCards(),
              const SizedBox(height: 24),
              // THE TABLE CONTAINER
              _buildStickyTable(constraints.maxHeight),
              const SizedBox(height: 40), // Bottom padding to prevent scroll cutoff
            ],
          ),
        );
      }
    );
  }

  Widget _buildSummaryCards() {
    int totalWO = summaryMap.values.fold(0, (sum, item) => sum + item.totalWorkOrders);
    double totalReceived = summaryMap.values.fold(0.0, (sum, item) => sum + item.amountReceived);
    double totalOutstanding = summaryMap.values.fold(0.0, (sum, item) => sum + item.outstanding);
    double totalProfit = summaryMap.values.fold(0.0, (sum, item) => sum + item.profit);

    return Center( 
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        alignment: WrapAlignment.center, 
        children: [
          _statCard("Total WorkOrders", totalWO.toString(), Colors.blue),
          _statCard("Total Received Amount", "₹${totalReceived.toStringAsFixed(2)}", Colors.green),
          _statCard("Total Outstanding", "₹${totalOutstanding.toStringAsFixed(2)}", Colors.redAccent),
          _statCard("Total Profit", "₹${totalProfit.toStringAsFixed(2)}", Colors.cyanAccent),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: 250, 
      decoration: BoxDecoration(
          color: const Color(0xFF212327),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(color: color == Colors.cyanAccent ? Colors.cyanAccent : Colors.white, 
              fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStickyTable(double maxHeight) {
    final List<String> headers = ["Month", "Total WO", "Load (kW)", "Amount", "Received", "Outstanding", "Profit"];
    
    // Limits the container height so it doesn't overflow the screen
    double dynamicMaxHeight = maxHeight * 0.7;

    return Container(
      constraints: BoxConstraints(
        minHeight: 150,
        maxHeight: dynamicMaxHeight,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF212327),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: ThemeData.dark().copyWith(
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(Colors.cyanAccent.withOpacity(0.5)),
              thickness: WidgetStateProperty.all(6),
            )
          ),
          child: Scrollbar(
            controller: _tableHorizontalController,
            thumbVisibility: true,
            // Horizontal scrollbar is now inside the container clipping area
            child: SingleChildScrollView(
              controller: _tableHorizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1100, // Fixed internal width for horizontal scrolling
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Fits rows if few
                  children: [
                    // --- STICKY HEADER ---
                    Container(
                      color: const Color(0xFF1A1C1E),
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      child: Row(
                        children: headers.map((h) => Expanded(
                          child: Text(h, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))
                        )).toList(),
                      ),
                    ),
                    // --- SCROLLABLE BODY ---
                    Flexible(
                      child: Scrollbar(
                        controller: _tableVerticalController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _tableVerticalController,
                          itemCount: summaryMap.length,
                          shrinkWrap: true, // Allows container to hug the rows
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            var s = summaryMap.values.elementAt(index);
                            return _buildCustomRow(s);
                          },
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

  Widget _buildCustomRow(WorkOrderSummary s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _navigateToDetail(s),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.cyanAccent.withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(s.monthYear, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          Expanded(child: SelectableText(s.totalWorkOrders.toString(), style: const TextStyle(color: Colors.white))),
          Expanded(child: SelectableText(s.sanctionLoad.toStringAsFixed(1), style: const TextStyle(color: Colors.white))),
          Expanded(child: SelectableText("₹${s.totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white))),
          Expanded(child: SelectableText("₹${s.amountReceived.toStringAsFixed(0)}", style: const TextStyle(color: Colors.greenAccent))),
          Expanded(child: SelectableText("₹${s.outstanding.toStringAsFixed(0)}", style: const TextStyle(color: Colors.redAccent))),
          Expanded(child: SelectableText("₹${s.profit.toStringAsFixed(0)}", 
            style: TextStyle(color: s.profit >= 0 ? Colors.cyanAccent : Colors.orangeAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _navigateToDetail(WorkOrderSummary s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthlyDetailPage(
          summary: s,
          workOrders: workOrders,
          customers: customers,
          payments: receivedPayments,
          expenses: expenses,
          usedProducts: usedProducts,
          materialLog: materialLog,
        ),
      ),
    );
  }
}