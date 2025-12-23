// class WorkOrderSummary {
//   String monthYear;
//   int totalWorkOrders;
//   double sanctionLoad;
//   int loanCount;
//   int cashCount;
//   double totalAmount;
//   double amountReceived;
//   double outstanding;
//   double margin;
//   List<String> workOrderIds;

//   WorkOrderSummary({
//     required this.monthYear,
//     this.totalWorkOrders = 0,
//     this.sanctionLoad = 0,
//     this.loanCount = 0,
//     this.cashCount = 0,
//     this.totalAmount = 0,
//     this.amountReceived = 0,
//     this.outstanding = 0,
//     this.margin = 0,
//     List<String>? workOrderIds,
//   }) : workOrderIds = workOrderIds ?? [];
// }


class WorkOrderSummary {
  String monthYear;
  int totalWorkOrders = 0;
  double sanctionLoad = 0;
  int loanCount = 0;
  int cashCount = 0;
  double totalAmount = 0;
  double amountReceived = 0;
  double outstanding = 0;
  double margin = 0;
  List<String> workOrderIds = [];

  WorkOrderSummary(this.monthYear);
}
