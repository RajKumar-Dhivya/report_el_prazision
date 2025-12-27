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
  List<dynamic> leads = []; // Corrected variable
  List<dynamic> employees = []; // New variable for employee profiles
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
      // Corrected Sheet Name: "Leads"
      leads = await GoogleSheetsApi.getSheet("Lead"); 
      employees = await GoogleSheetsApi.getSheet("EmployeeProfile");
      
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
      if (recordedDate.isEmpty) continue;
      
      double sanctionLoad = double.tryParse(row["Sanction Load/KW"].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      double totalAmount = double.tryParse(row["Total Amount"].toString()) ?? 0;
      
      DateTime dt = DateTime.parse(recordedDate);
      String monthYear = "${_monthName(dt.month)} ${dt.year}";
      
      summaryMap.putIfAbsent(monthYear, () => WorkOrderSummary(monthYear));
      var s = summaryMap[monthYear]!;
      s.totalWorkOrders++;
      s.sanctionLoad += sanctionLoad;
      s.totalAmount += totalAmount;
      s.workOrderIds.add(row["ID"].toString());
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
    const months = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
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
                          LeadAnalysisTab(leads: leads ?? [],
                          employees: employees ?? [],), 
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
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 0), // Adjusted to fix overflow
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

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _statCard("Total WorkOrders", totalWO.toString(), Colors.blue),
        _statCard("Total Received Amount", "₹${totalReceived.toStringAsFixed(2)}", Colors.green),
        _statCard("Total Outstanding", "₹${totalOutstanding.toStringAsFixed(2)}", Colors.redAccent),
      ],
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: 300,
      decoration: BoxDecoration(color: const Color(0xFF212327), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 10),
          SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF212327), 
        borderRadius: BorderRadius.circular(12)
      ),
      // Adding bottom padding so the scrollbar doesn't overlap the last data row
      padding: const EdgeInsets.only(bottom: 15), 
      child: Theme(
        data: ThemeData(
          scrollbarTheme: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(Colors.cyanAccent.withOpacity(0.8)),
            trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
            trackVisibility: WidgetStateProperty.all(true),
            thickness: WidgetStateProperty.all(8.0),
            radius: const Radius.circular(10),
          ),
        ),
        child: Scrollbar(
          controller: _tableHorizontalController,
          thumbVisibility: true, // Forces it to show on small screens
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _tableHorizontalController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              // Using a fixed minimum width ensures the scrollbar has a reason to exist
              constraints: const BoxConstraints(minWidth: 1000), 
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF1A1C1E)),
                columns: _buildColumns(),
                rows: summaryMap.values.map((s) => _buildDataRow(s)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return ["Month", "Total WO", "Load (kW)", "Amount", "Received", "Outstanding"]
        .map((col) => DataColumn(label: Text(col, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))))
        .toList();
  }

  DataRow _buildDataRow(WorkOrderSummary s) {
    return DataRow(cells: [
      DataCell(
      // 1. MONTH AS BUTTON
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
        child: Text(s.monthYear, 
          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
      ),
    ),
      DataCell(Text(s.totalWorkOrders.toString(), style: const TextStyle(color: Colors.white70))),
      DataCell(Text(s.sanctionLoad.toStringAsFixed(1), style: const TextStyle(color: Colors.white70))),
      DataCell(Text("₹${s.totalAmount}", style: const TextStyle(color: Colors.white70))),
      DataCell(Text("₹${s.amountReceived}", style: const TextStyle(color: Colors.white70))),
      DataCell(Text("₹${s.outstanding}", style: const TextStyle(color: Colors.redAccent))),
    ]);
  }
}