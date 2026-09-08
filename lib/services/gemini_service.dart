import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../models/receipt.dart';

class GeminiService {
  // Pass your key via flutter build --dart-define=GEMINI_API_KEY="AIza..."
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
  );

  static Future<ReceiptData> parseReceiptImage(File imageFile) async {
    // 1. Compress image to prevent timeouts and reduce latency
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 1200,
      minHeight: 1200,
      quality: 80,
    );

    if (compressedBytes == null) {
      throw Exception('Failed to compress image.');
    }

    final base64Image = base64Encode(compressedBytes);
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
    );

    // 2. Structured JSON system prompt
    final prompt = '''
    Analyze this receipt image. Extract all line items, tax, service fees, and totals.
    Return strictly a valid JSON object matching this schema:
    {
      "currency": "INR",
      "items": [
        {"id": "1", "name": "Burger", "qty": 1, "total_price": 250.0}
      ],
      "subtotal": 250.0,
      "tax": 12.5,
      "service_charge": 10.0,
      "grand_total": 272.5
    }
    Rules:
    - Omit markdown backticks (```json). Return ONLY pure parsable JSON.
    - Remove currency symbols from numerical amounts.
    - Sum all GST/VAT/taxes into 'tax'.
    ''';

    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Image,
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "response_mime_type": "application/json"
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API failed [${response.statusCode}]: ${response.body}');
    }

    final responseJson = jsonDecode(response.body);
    final candidates = responseJson['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Empty response from model.');
    }

    final rawContent = candidates[0]['content']['parts'][0]['text'] as String;
    final parsedMap = jsonDecode(rawContent);

    return ReceiptData.fromJson(parsedMap);
  }
}
