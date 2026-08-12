import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../main.dart'; // For AppConfig
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/student_model.dart';

class ExtractionService {
  final List<String> apiKeys;

  ExtractionService({required this.apiKeys});

  /// Ultra-fast extraction sending cropped native JPEG directly to Gemini Vision
  Future<StudentModel> extractFromImage({
    required String imagePath,
    required Uint8List imageBytes,
    required String selectedHostel,
  }) async {
    try {
      final sw = Stopwatch()..start();
      
      final imagePart = DataPart('image/jpeg', imageBytes);

      String name = 'Unknown';
      String rollNo = 'Unknown';
      String dob = 'Unknown';
      String dept = 'Unknown';
      String contact = 'Unknown';
      String email = 'Unknown';

      // Fast Multimodal JSON Extraction via Gemini
      if (AppConfig.scannerKeys.isNotEmpty) {
        for (final geminiKey in AppConfig.scannerKeys) {
          try {
            final model = GenerativeModel(
              model: 'gemini-flash-latest',
              apiKey: geminiKey,
              generationConfig: GenerationConfig(
                temperature: 0.1,
                responseMimeType: 'application/json',
              ),
            );

            final prompt = TextPart('Extract the student details from this form or ID card image. Read handwriting and printed text carefully. Return ONLY a valid JSON object with the exact keys: "name", "rollNo", "dob", "department", "semester", "contact", "email". If a field is missing, use "Unknown".');

            final response = await model.generateContent([
              Content.multi([prompt, imagePart])
            ]).timeout(const Duration(seconds: 15));

            if (response.text != null && response.text!.isNotEmpty) {
              String content = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
              final parsed = jsonDecode(content);
              
              name = parsed['name']?.toString() ?? 'Unknown';
              rollNo = parsed['rollNo']?.toString() ?? 'Unknown';
              dob = parsed['dob']?.toString() ?? 'Unknown';
              dept = parsed['department']?.toString() ?? 'Unknown';
              String extractedSem = parsed['semester']?.toString() ?? parsed['year']?.toString() ?? '';
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
          } catch (e) {
            debugPrint('Gemini Vision parsing failed for key: $e');
          }
        }
      }

      throw Exception('All Gemini keys failed to extract the image.');

    } catch (e) {
      debugPrint('Local Extraction Error: $e');
      throw Exception('Failed to process image locally: $e');
    }
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
