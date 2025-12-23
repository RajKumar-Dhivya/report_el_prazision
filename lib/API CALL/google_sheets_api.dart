import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsApi {
  static const String apiUrl = "https://script.google.com/macros/s/AKfycbwz1pwdXlH_8oLymDPmB5IUshBRHIorDXKBW5NLVHUdinqVP_MkthA30l_dZilwGytj/exec";

  // Fetch all sheets
  static Future<Map<String, dynamic>> getAllSheets() async {
    final response = await http.get(Uri.parse(apiUrl));
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // Fetch specific sheet
  static Future<List<dynamic>> getSheet(String sheetName) async {
    final response = await http.get(Uri.parse("$apiUrl?sheet=$sheetName"));
    return jsonDecode(response.body);
  }

  // Add a new row to a sheet
  static Future<bool> addRow(String sheetName, Map<String, dynamic> row) async {
    final response = await http.post(
      Uri.parse("$apiUrl?sheet=$sheetName"),
      body: jsonEncode(row),
    );
    return response.statusCode == 200;
  }
}
