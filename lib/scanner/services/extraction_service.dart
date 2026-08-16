import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../../main.dart'; // For AppConfig
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/student_model.dart';

class ExtractionService {
  final List<String> apiKeys;

  ExtractionService({required this.apiKeys});

  /// Shrinks oversized scans before Gemini for faster first-token latency.
  /// OCR accuracy is preserved by staying at 1200px width / decent quality.
  Uint8List _optimizeForGemini(Uint8List bytes) {
    if (bytes.length <= 220 * 1024) return bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final resized =
          decoded.width > 1200 ? img.copyResize(decoded, width: 1200) : decoded;
      int quality = 80;
      var out = img.encodeJpg(resized, quality: quality);
      while (out.length > 300 * 1024 && quality > 55) {
        quality -= 7;
        out = img.encodeJpg(resized, quality: quality);
      }
      return Uint8List.fromList(out);
    } catch (e) {
      debugPrint('Image optimize failed, sending original: $e');
      return bytes;
    }
  }

  /// Ultra-fast extraction sending optimized JPEG to Gemini Vision
  Future<StudentModel> extractFromImage({
    required String imagePath,
    required Uint8List imageBytes,
    required String selectedHostel,
  }) async {
    try {
      final sw = Stopwatch()..start();
      final optimizedBytes = _optimizeForGemini(imageBytes);
      final base64Image = base64Encode(optimizedBytes);

      String name = 'Unknown';
      String rollNo = 'Unknown';
      String dob = 'Unknown';
      String dept = 'Unknown';
      String contact = 'Unknown';
      String email = 'Unknown';
      String extractedSem = 'Semester 1';

      final keys = (AppConfig.scannerKeys.isNotEmpty)
          ? AppConfig.scannerKeys
          : apiKeys;

      if (keys.isNotEmpty) {
        const promptText = 'Extract the student details from this form or ID card image. Read handwriting and printed text carefully. Return ONLY a valid JSON object with the exact keys: "name", "rollNo", "dob", "department", "semester", "contact", "email". If a field is missing, use "Unknown".';

        // 1. Try parallel Google Generative AI with gemini-2.5-flash & gemini-flash-latest
        final futures = <Future<Map<String, dynamic>?>>[];
        for (final geminiKey in keys) {
          futures.add(_extractViaRest(geminiKey, base64Image, promptText));
          futures.add(_extractViaSdk(geminiKey, optimizedBytes, promptText));
        }

        final parsedResults = await Future.wait(futures);
        for (final parsed in parsedResults) {
          if (parsed != null && (parsed['name'] != null || parsed['rollNo'] != null)) {
            name = parsed['name']?.toString() ?? 'Unknown';
            rollNo = parsed['rollNo']?.toString() ?? 'Unknown';
            dob = parsed['dob']?.toString() ?? 'Unknown';
            dept = parsed['department']?.toString() ?? 'Unknown';
            extractedSem = parsed['semester']?.toString() ?? parsed['year']?.toString() ?? 'Semester 1';
            contact = parsed['contact']?.toString() ?? 'Unknown';
            email = parsed['email']?.toString() ?? 'Unknown';

            sw.stop();
            debugPrint('[SCANNER LATENCY] Total Vision Extraction: ${sw.elapsedMilliseconds}ms ✅');

            final defaultRoom = '';
            String gender = selectedHostel.contains('Girls') ? 'Female' : 'Male';

            return StudentModel(
              id: 'STU${DateTime.now().millisecondsSinceEpoch}',
              name: name.trim().isEmpty ? 'Unknown' : name.trim(),
              rollNo: rollNo.trim().isEmpty ? 'Unknown' : rollNo.trim(),
              department: dept.trim().isEmpty ? 'Unknown' : dept.trim(),
              semester: (extractedSem.trim().isEmpty || extractedSem.trim().toLowerCase() == 'unknown')
                  ? 'Semester 1'
                  : extractedSem.trim(),
              dateOfBirth: dob.trim().isEmpty ? 'Unknown' : dob.trim(),
              gender: gender,
              contactNo: contact.trim().isEmpty ? 'Unknown' : contact.trim(),
              emailId: email.trim().isEmpty ? 'Unknown' : email.trim(),
              roomNo: defaultRoom,
              hostel: selectedHostel,
              photoPath: imagePath,
              createdAt: DateTime.now(),
            );
          }
        }
      }

      throw Exception('All Gemini keys failed to extract the image.');
    } catch (e) {
      debugPrint('Local Extraction Error: $e');
      throw Exception('Failed to process image: $e');
    }
  }

  Future<Map<String, dynamic>?> _extractViaSdk(
      String geminiKey, Uint8List bytes, String promptText) async {
    try {
      final imagePart = DataPart('image/jpeg', bytes);
      final prompt = TextPart(promptText);
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: geminiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          responseMimeType: 'application/json',
        ),
      );
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]).timeout(const Duration(seconds: 12));

      if (response.text != null && response.text!.isNotEmpty) {
        String content = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('SDK extraction error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _extractViaRest(
      String geminiKey, String base64Image, String promptText) async {
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$geminiKey');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': promptText},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'response_mime_type': 'application/json'
          }
        }),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawText =
            data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString() ?? '';
        if (rawText.isNotEmpty) {
          String content = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('REST extraction error: $e');
    }
    return null;
  }



  // Keeping this for the Rules PDF parsing feature since ML Kit doesn't parse PDFs easily
  Future<String> extractRulesFromDocument({
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    final prompt = TextPart(
        'You are an expert document transcription assistant. Your task is to precisely transcribe the provided Rules & Regulations document (which could be a PDF or an Image). Extract all rules verbatim. Do not omit any rules. If it contains numbered lists, maintain them. Return ONLY the transcribed text. Do not wrap in JSON.');
    
    final filePart = DataPart(mimeType, fileBytes);

    GenerateContentResponse? response;
    int maxRetries = 2;
    bool success = false;

    for (String currentKey in apiKeys) {
      if (success) break;

      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: currentKey,
      );

      int retryCount = 0;
      while (retryCount < maxRetries) {
        try {
          response = await model.generateContent([
            Content.multi([prompt, filePart])
          ]).timeout(const Duration(seconds: 45)); 
          success = true;
          break;
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) break;
          await Future.delayed(Duration(seconds: 2 * retryCount));
        }
      }
    }

    if (!success || response == null || response.text == null || response.text!.isEmpty) {
      throw Exception("Failed to extract rules: API keys exhausted or returned empty.");
    }
    return response.text!;
  }
}
