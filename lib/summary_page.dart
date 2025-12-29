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

class _SummaryPageState extends State<SummaryPage>
    with SingleTickerProviderStateMixin {
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
      materialLog = await GoogleSheetsApi.getSheet(
        "Material Consumption & Purchase Log",
      );

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
      if (row == null ||
          row.values.every((v) => v == null || v.toString().trim().isEmpty))
        continue;
      String recordedDate = row["Recorded Date"] ?? "";
      String woID = row["ID"].toString().trim();
      if (recordedDate.isEmpty) continue;

      double sanctionLoad =
          double.tryParse(
            row["Sanction Load/KW"].toString().replaceAll(
              RegExp(r'[^0-9.]'),
              '',
            ),
          ) ??
          0;
      double totalAmount = double.tryParse(row["Total Amount"].toString()) ?? 0;

      double totalExpenses = expenses
          .where((exp) => exp["Work order ID"].toString().trim() == woID)
          .fold(
            0.0,
            (sum, item) =>
                sum + (double.tryParse(item["Amount"].toString()) ?? 0.0),
          );

      double totalProductCost = 0;
      var woUsedProducts = usedProducts.where(
        (up) => up["Work Order id"].toString().trim() == woID,
      );
      for (var product in woUsedProducts) {
        double qty = double.tryParse(product["used quantity"].toString()) ?? 0;
        double unitPrice = materialLog
            .where(
              (ml) =>
                  ml["ID"].toString().trim() ==
                  product["product id"].toString().trim(),
            )
            .fold(
              0.0,
              (sum, item) =>
                  sum +
                  (double.tryParse(item["Unit Price with GST"].toString()) ??
                      0.0),
            );
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
      double amount =
          double.tryParse(payment["Received Payment"].toString()) ?? 0;
      for (var s in summaryMap.values) {
        if (s.workOrderIds.contains(woID)) s.amountReceived += amount;
      }
    }
    for (var s in summaryMap.values) {
      s.outstanding = s.totalAmount - s.amountReceived;
    }
  }

  String _monthName(int m) {
    const months = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[m];
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1113), // Deep black-grey
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
                    )
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
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
    color: const Color(0xFF1A1C1E),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Check if we are on a small screen (e.g., width less than 600)
            bool isMobile = constraints.maxWidth < 600;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Flexible Title
                Expanded(
                  child: SelectableText(
                    "Reports & Analytics",
                    style: TextStyle(
                      color: Colors.white,
                      // Smaller font for mobile, larger for desktop
                      fontSize: isMobile ? 18 : 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                
                const SizedBox(width: 10), // Small gap

                // 2. Company Logo
                Image.asset(
                  'assets/elp-logo (Small).jpeg',
                  height: isMobile ? 30 : 40, // Slightly smaller logo on mobile
                  errorBuilder: (ctx, err, stack) => Icon(
                    Icons.business,
                    color: Colors.cyanAccent,
                    size: isMobile ? 30 : 40,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey.shade500,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(child: Text("WORK ORDER SUMMARY", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            Tab(child: Text("LEAD ANALYSIS", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            children: [
              _buildSummaryCards(),
              const SizedBox(height: 32),
              _buildStickyTable(constraints.maxHeight, constraints.maxWidth),
              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards() {
    int totalWO = summaryMap.values.fold(
      0,
      (sum, item) => sum + item.totalWorkOrders,
    );
    double totalReceived = summaryMap.values.fold(
      0.0,
      (sum, item) => sum + item.amountReceived,
    );
    double totalOutstanding = summaryMap.values.fold(
      0.0,
      (sum, item) => sum + item.outstanding,
    );
    double totalProfit = summaryMap.values.fold(
      0.0,
      (sum, item) => sum + item.profit,
    );

    return Center(
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        alignment: WrapAlignment.center,
        children: [
          _statCard("Total WorkOrders", totalWO.toString(), Colors.blueAccent),
          _statCard(
            "Total Received",
            "₹${totalReceived.toStringAsFixed(0)}",
            Colors.greenAccent,
          ),
          _statCard(
            "Outstanding",
            "₹${totalOutstanding.toStringAsFixed(0)}",
            Colors.redAccent,
          ),
          _statCard(
            "Total Profit",
            "₹${totalProfit.toStringAsFixed(0)}",
            Colors.cyanAccent,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1C1E), const Color(0xFF212327)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyTable(double maxHeight, double maxWidth) {
    final List<String> headers = [
      "Month",
      "Total WO",
      "Load (kW)",
      "Amount",
      "Received",
      "Outstanding",
      "Profit",
    ];

    double tableContentWidth = maxWidth < 1100 ? 1100 : (maxWidth - 48);

    return Container(
      constraints: BoxConstraints(minHeight: 200, maxHeight: maxHeight * 0.7),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: ThemeData.dark().copyWith(
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(
                Colors.cyanAccent.withOpacity(0.3),
              ),
              thickness: WidgetStateProperty.all(6),
            ),
          ),
          child: Scrollbar(
            controller: _tableHorizontalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _tableHorizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableContentWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- HEADER ROW WITH WHITE UNDERLINE ---
                    Container(
                      // The 'color' property MUST be inside decoration, not here.
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(
                          0xFF25282C,
                        ), // Background color moved inside here
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ), // The white line
                        ),
                      ),
                      child: Row(
                        children: headers
                            .map(
                              (h) => Expanded(
                                child: Text(
                                  h,
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    // --- BODY ---
                    Flexible(
                      child: Scrollbar(
                        controller: _tableVerticalController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _tableVerticalController,
                          itemCount: summaryMap.length,
                          shrinkWrap: true,
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.03)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => _navigateToDetail(s),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.cyanAccent.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    s.monthYear,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              s.totalWorkOrders.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              s.sanctionLoad.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              "₹${s.totalAmount.toStringAsFixed(0)}",
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Expanded(
            child: Text(
              "₹${s.amountReceived.toStringAsFixed(0)}",
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              "₹${s.outstanding.toStringAsFixed(0)}",
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              "₹${s.profit.toStringAsFixed(0)}",
              style: TextStyle(
                color: s.profit >= 0 ? Colors.cyanAccent : Colors.orangeAccent,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
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
