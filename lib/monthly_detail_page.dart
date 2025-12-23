
import 'package:flutter/material.dart';
import 'API CALL/google_sheets_api.dart';
import 'workorder_summary.dart';

class MonthlyDetailPage extends StatefulWidget {
  final WorkOrderSummary summary;

  const MonthlyDetailPage({super.key, required this.summary});

  @override
  State<MonthlyDetailPage> createState() => _MonthlyDetailPageState();
}

class _MonthlyDetailPageState extends State<MonthlyDetailPage> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  bool loading = true;

  List<Map<String, dynamic>> rows = [];

  List<dynamic> workOrders = [];
  List<dynamic> customers = [];
  List<dynamic> payments = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      workOrders = await GoogleSheetsApi.getSheet("Work Orders");
      customers = await GoogleSheetsApi.getSheet("Customer");
      payments = await GoogleSheetsApi.getSheet("Received Payments");

      processData();
    } catch (e) {
      debugPrint("Monthly detail error: $e");
    }

    setState(() => loading = false);
  }

  void processData() {
    rows.clear();

    for (var wo in workOrders) {
      if (wo == null) continue;

      String recordedDate = wo["Recorded Date"] ?? "";
      if (recordedDate.isEmpty) continue;

      DateTime dt = DateTime.parse(recordedDate);
      String monthYear = "${_monthName(dt.month)} ${dt.year}";

      if (monthYear != widget.summary.monthYear) continue;

      String workOrderId = wo["ID"].toString();
      String customerId = wo["Customer Name"].toString();

      // 🔹 CUSTOMER NAME LOOKUP
      String customerName = "";
      for (var c in customers) {
        if (c["ID"].toString() == customerId) {
          customerName = c["Customer Name"].toString();
          break;
        }
      }

      // 🔹 ADVANCE PAYMENT CALCULATION
      double advance = 0;
      for (var p in payments) {
        final type = p["Type of payment"]
        ?.toString()
        .toLowerCase()
        .trim();

if (p["Work Order ID"].toString().trim() == workOrderId.trim() &&
    type != null &&
    type.contains("advance")) {
  advance +=
      double.tryParse(
        p["Received Payment"]?.toString().trim() ?? "0",
       
      ) ??
      0;
      debugPrint("type : $type");
      debugPrint("recived payment : $advance");
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
      "Dec"
    ];
    return months[m];
  }

  DataCell cell(dynamic v) =>
      DataCell(Center(child: Text(v.toString())));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Details - ${widget.summary.monthYear}"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;

                return Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: screenWidth),
                      child: Scrollbar(
                        controller: _vertical,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _vertical,
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            border:
                                TableBorder.all(color: Colors.grey),
                            headingRowColor:
                                MaterialStateProperty.all(
                                    Colors.grey.shade200),
                            columns: const [
                              DataColumn(label: Text("Customer Name")),
                              DataColumn(label: Text("K/W")),
                              DataColumn(label: Text("Loan / Cash")),
                              DataColumn(label: Text("Total Amount")),
                              DataColumn(label: Text("Advance")),
                            ],
                            rows: rows.map((r) {
                              return DataRow(cells: [
                                cell(r["customer"]),
                                cell(r["kw"]),
                                cell(r["mode"]),
                                cell("₹${r["amount"]}"),
                                cell("₹${r["advance"]}"),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
