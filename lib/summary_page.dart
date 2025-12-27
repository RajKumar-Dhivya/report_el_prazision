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
  final ScrollController _mainVerticalController = ScrollController();

  bool loading = true;
  Map<String, WorkOrderSummary> summaryMap = {};
  List<dynamic> receivedPayments = [];
  List<dynamic> workOrders = [];
  List<dynamic> customers = [];
  List<dynamic> leads = [];
  List<dynamic> employees = [];
  
  // New Lists for Profit Calculation
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
      // Fetching all required sheets
      workOrders = await GoogleSheetsApi.getSheet("Work Orders");
      receivedPayments = await GoogleSheetsApi.getSheet("Received Payments");
      customers = await GoogleSheetsApi.getSheet("Customer");
      leads = await GoogleSheetsApi.getSheet("Lead");
      employees = await GoogleSheetsApi.getSheet("EmployeeProfile");
      
      // Fetching New sheets for profit calculation
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

      // --- PROFIT CALCULATION LOGIC ---
      
      // 1. Sum Expenses for this Work Order
      double totalExpenses = expenses
          .where((exp) => exp["Work order ID"].toString().trim() == woID)
          .fold(0.0, (sum, item) => sum + (double.tryParse(item["Amount"].toString()) ?? 0.0));

      // 2. Sum Used Products Cost
      double totalProductCost = 0;
      var woUsedProducts = usedProducts.where((up) => up["Work Order id"].toString().trim() == woID);
      
      for (var product in woUsedProducts) {
        double qty = double.tryParse(product["used quantity"].toString()) ?? 0;
        String productID = product["product id"].toString().trim();
        
        // Find unit price from Material Log
        double unitPrice = materialLog
            .where((ml) => ml["ID"].toString().trim() == productID)
            .fold(0.0, (sum, item) => sum + (double.tryParse(item["Unit Price with GST"].toString()) ?? 0.0));
        
        totalProductCost += (qty * unitPrice);
      }

      double woProfit = totalAmount - (totalExpenses + totalProductCost);

      // --- ORGANIZE BY MONTH ---
      DateTime dt = DateTime.parse(recordedDate);
      String monthYear = "${_monthName(dt.month)} ${dt.year}";

      summaryMap.putIfAbsent(monthYear, () => WorkOrderSummary(monthYear));
      var s = summaryMap[monthYear]!;
      s.totalWorkOrders++;
      s.sanctionLoad += sanctionLoad;
      s.totalAmount += totalAmount;
      s.profit += woProfit; // Make sure to add 'double profit' to your WorkOrderSummary class
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
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1C1E),
      appBar: !isDesktop ? AppBar(
        title: const Text("Reports Dashboard"),
        backgroundColor: const Color(0xFF212327),
        elevation: 0,
      ) : null,
      drawer: !isDesktop ? _buildSidebar() : null,
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildWorkOrderTab(),
                            LeadAnalysisTab(
                              leads: leads ?? [],
                              employees: employees ?? [],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: const Color(0xFF111315),
      child: Column(
        children: [
          const DrawerHeader(child: Center(child: Icon(Icons.analytics, size: 80, color: Colors.cyanAccent))),
          _sidebarItem(Icons.dashboard, "Dashboard", true),
          _sidebarItem(Icons.assignment, "Work Orders", false),
          _sidebarItem(Icons.leaderboard, "Leads", false),
          _sidebarItem(Icons.settings, "Settings", false),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String title, bool selected) {
    return ListTile(
      leading: Icon(icon, color: selected ? Colors.cyanAccent : Colors.grey),
      title: Text(title, style: TextStyle(color: selected ? Colors.white : Colors.grey)),
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
              Tab(text: "Work Order Summary"),
              Tab(text: "Lead Analysis"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkOrderTab() {
    return SingleChildScrollView(
      controller: _mainVerticalController,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 20),
          _buildDataTable(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    int totalWO = summaryMap.values.fold(0, (sum, item) => sum + item.totalWorkOrders);
    double totalReceived = summaryMap.values.fold(0.0, (sum, item) => sum + item.amountReceived);
    double totalOutstanding = summaryMap.values.fold(0.0, (sum, item) => sum + item.outstanding);
    double totalProfit = summaryMap.values.fold(0.0, (sum, item) => sum + item.profit);

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _statCard("Total WorkOrders", totalWO.toString(), Colors.blue),
        _statCard("Total Received Amount", "₹${totalReceived.toStringAsFixed(2)}", Colors.green),
        _statCard("Total Outstanding", "₹${totalOutstanding.toStringAsFixed(2)}", Colors.redAccent),
        _statCard("Total Profit", "₹${totalProfit.toStringAsFixed(2)}", Colors.cyanAccent), // New Profit Card
      ],
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: 250, // Slightly reduced to fit 4 cards better
      decoration: BoxDecoration(
          color: const Color(0xFF212327),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 10),
          SelectableText(value,
              style: TextStyle(color: color == Colors.cyanAccent ? Colors.cyanAccent : Colors.white, 
              fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minTableWidth = 1100.0; // Increased to accommodate Profit column
        double adaptiveWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF212327),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: ThemeData(
              scrollbarTheme: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.all(Colors.cyanAccent.withOpacity(0.8)),
                trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
                trackVisibility: WidgetStateProperty.all(true),
                thickness: WidgetStateProperty.all(8.0),
                radius: const Radius.circular(10),
                interactive: true,
              ),
            ),
            child: Scrollbar(
              controller: _tableHorizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _tableHorizontalController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: adaptiveWidth),
                    child: DataTable(
                      columnSpacing: isDesktop ? (constraints.maxWidth / 9) : 35,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF1A1C1E)),
                      columns: _buildColumns(),
                      rows: summaryMap.values.map((s) => _buildDataRow(s)).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<DataColumn> _buildColumns() {
    return ["Month", "Total WO", "Load (kW)", "Amount", "Received", "Outstanding", "Profit"]
        .map((col) => DataColumn(
            label: Text(col, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))))
        .toList();
  }

  DataRow _buildDataRow(WorkOrderSummary s) {
    return DataRow(cells: [
      DataCell(
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MonthlyDetailPage(
                  summary: s,
                  workOrders: workOrders,
                  customers: customers,
                  payments: receivedPayments,
                ),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            backgroundColor: Colors.cyanAccent.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(s.monthYear, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        ),
      ),
      DataCell(Text(s.totalWorkOrders.toString(), style: const TextStyle(color: Colors.white70))),
      DataCell(Text(s.sanctionLoad.toStringAsFixed(1), style: const TextStyle(color: Colors.white70))),
      DataCell(Text("₹${s.totalAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white70))),
      DataCell(Text("₹${s.amountReceived.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white70))),
      DataCell(Text("₹${s.outstanding.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent))),
      DataCell(Text("₹${s.profit.toStringAsFixed(2)}", 
          style: TextStyle(color: s.profit >= 0 ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold))),
    ]);
  }
}