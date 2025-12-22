import 'package:flutter/material.dart';
import 'API CALL/google_sheets_api.dart';
import 'workorder_summary.dart';
import 'monthly_detail_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WorkOrderReportPage(),
    );
  }
}

class WorkOrderReportPage extends StatefulWidget {
  @override
  _WorkOrderReportPageState createState() => _WorkOrderReportPageState();
}

class _WorkOrderReportPageState extends State<WorkOrderReportPage> {
  final ScrollController _horizontalScrollController = ScrollController();

  Map<String, WorkOrderSummary> summaryMap = {};
  List<dynamic> receivedPayments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    try {
      final workOrders = await GoogleSheetsApi.getSheet("Work Orders");
      final payments = await GoogleSheetsApi.getSheet("Received Payments");

      receivedPayments = payments;
      processWorkOrders(workOrders);
      calculateReceivedPayments();
    } catch (e) {
      print("Error loading data: $e");
    }

    setState(() => loading = false);
  }

  void processWorkOrders(List rows) {
    summaryMap.clear();

    for (var row in rows) {
      String recordedDate = row["Recorded Date"];
      String paymentMode = row["Payment Mode"];
      double sanctionLoad =
          double.tryParse(row["Sanction Load/KW"].toString()) ?? 0;
      double totalAmount = double.tryParse(row["Total Amount"].toString()) ?? 0;

      DateTime dt = DateTime.parse(recordedDate);
      String monthYear = "${_monthName(dt.month)} ${dt.year}";

      summaryMap.putIfAbsent(monthYear, () => WorkOrderSummary(monthYear));
      var s = summaryMap[monthYear]!;

      s.totalWorkOrders++;
      s.sanctionLoad += sanctionLoad;
      s.totalAmount += totalAmount;

      if (paymentMode.toLowerCase() == "loan") {
        s.loanCount++;
      } else if (paymentMode.toLowerCase() == "cash") {
        s.cashCount++;
      }

      s.workOrderIds.add(row["ID"].toString());
    }
  }

  void calculateReceivedPayments() {
    for (var payment in receivedPayments) {
      String woID = payment["Work Order ID"].toString();
      double amount =
          double.tryParse(payment["Received Payment"].toString()) ?? 0;

      for (var s in summaryMap.values) {
        if (s.workOrderIds.contains(woID)) {
          s.amountReceived += amount;
        }
      }
    }

    // Calculate outstanding
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
    return Scaffold(
      appBar: AppBar(
        title: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/company_logo.png',
                height: 200,
                width: 300,
              ),
              // const SizedBox(width: 12),
            ),
            const Expanded(
              child: Text(
                "Monthly Work Order Report",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : summaryMap.isEmpty
          ? const Center(child: Text("No Data Found"))
          : LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = constraints.maxWidth;

      double colWidth = screenWidth < 900 ? 120 : screenWidth / 12;

      // Minimum width required for full table (8 columns)
      double tableMinWidth = colWidth * 8;

      return Scrollbar(
        controller: _horizontalScrollController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: tableMinWidth < screenWidth
                  ? screenWidth
                  : tableMinWidth,
            ),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: MaterialStateProperty.resolveWith(
                (states) => Colors.blue.shade100,
              ),
              columns: const [
                DataColumn(label: Text("Month")),
                DataColumn(label: Text("Work Orders")),
                DataColumn(label: Text("Load (kW)")),
                DataColumn(label: Text("Loan")),
                DataColumn(label: Text("Cash")),
                DataColumn(label: Text("Amount")),
                DataColumn(label: Text("Received")),
                DataColumn(label: Text("Outstanding")),
              ],
              rows: summaryMap.values.map((s) {
                return DataRow(
                  onSelectChanged: (selected) {
                    if (selected == true) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MonthlyDetailPage(
                            monthYear: s.monthYear,
                          ),
                        ),
                      );
                    }
                  },
                  cells: [
                    DataCell(SizedBox(
                        width: colWidth, child: Text(s.monthYear))),
                    DataCell(SizedBox(
                        width: colWidth,
                        child: Text(s.totalWorkOrders.toString()))),
                    DataCell(SizedBox(
                        width: colWidth,
                        child: Text(s.sanctionLoad.toString()))),
                    DataCell(SizedBox(
                        width: colWidth,
                        child: Text(s.loanCount.toString()))),
                    DataCell(SizedBox(
                        width: colWidth,
                        child: Text(s.cashCount.toString()))),
                    DataCell(SizedBox(
                        width: colWidth,
                        child: Text("₹${s.totalAmount}"))),
                    DataCell(SizedBox(
                        width: colWidth,
                        child: Text("₹${s.amountReceived}"))),
                    DataCell(SizedBox(
                        width: colWidth,
                        child: Text("₹${s.outstanding}"))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );
    },
  ),

    );
  }
}
