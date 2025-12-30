import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsApi {
  // static const String apiUrl = "https://script.google.com/macros/s/AKfycbwz1pwdXlH_8oLymDPmB5IUshBRHIorDXKBW5NLVHUdinqVP_MkthA30l_dZilwGytj/exec";
  static const String apiUrl =
      "https://asia-south1-solar-century-480005-h5.cloudfunctions.net/elprazionReport/data";

  // Fetch all sheets
  static Future<Map<String, dynamic>> getAllSheets() async {
    final response = await http.get(Uri.parse(apiUrl));
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // Fetch specific sheet
static Future<List<dynamic>> getSheets(String sheetNames) async {
  final uri = Uri.parse(apiUrl).replace(
    queryParameters: {'sheet': sheetNames},
  );

  final response = await http.get(
    uri,
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded;
    } else {
      throw Exception("Invalid response format");
    }
  } else {
    throw Exception(
      'Failed to load sheets ${response.statusCode}: ${response.body}',
    );
  }
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

//----------------//----------------//----------------//--------------------------------//----------------//

// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class GoogleSheetsApi {
//   static const String baseUrl =
//       "https://asia-south1-solar-century-480005-h5.cloudfunctions.net/elprazionReport/data";
//   /// Fetch a single sheet
//   static Future<List<dynamic>> getSheet(String sheetName) async {
//     final encodedSheet = Uri.encodeComponent(sheetName);
//     final uri = Uri.parse("$baseUrl?sheet=$encodedSheet");

//     final response = await http.get(uri);

//     if (response.statusCode != 200) {
//       throw Exception("Failed to fetch sheet: $sheetName");
//     }

//     return jsonDecode(response.body);
//   }

//   /// Fetch multiple selected sheets (for report pages)
//   static Future<Map<String, dynamic>> getSelectedSheets(
//       List<String> sheets) async {
//     final query = sheets
//         .map((s) => "sheet=${Uri.encodeComponent(s)}")
//         .join("&");

//     final uri = Uri.parse("$baseUrl?$query");

//     final response = await http.get(uri);

//     if (response.statusCode != 200) {
//       throw Exception("Failed to fetch selected sheets");
//     }

//     return Map<String, dynamic>.from(jsonDecode(response.body));
//   }

//   /// Fetch all sheets
//   static Future<Map<String, dynamic>> getAllSheets() async {
//     final response = await http.get(Uri.parse(baseUrl));

//     if (response.statusCode != 200) {
//       throw Exception("Failed to fetch all sheets");
//     }

//     return Map<String, dynamic>.from(jsonDecode(response.body));
//   }
// }
