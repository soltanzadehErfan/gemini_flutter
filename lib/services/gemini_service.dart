import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  late final model = GenerativeModel(
    model: 'gemini-1.5-flash-latest',
    apiKey: dotenv.env['GEMINI_API_KEY']!,
    safetySettings: [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.high),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.high),
    ],
  );

  Future<String> generateRecipe(String ingredients) async {
    try {
      final prompt = '''Create a recipe using these ingredients: $ingredients.
Please format the response as follows:
Recipe Name:
Cooking Time:
Ingredients:
Instructions:''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? 'Failed to generate recipe';
    } catch (e) {
      return 'Error generating recipe: $e';
    }
  }

  Future<String> identifyIngredientsFromImage(File imageFile) async {
    try {
      final imageData = await imageFile.readAsBytes();
      const prompt = '''Identify all the ingredients you can see in this image. 
List them in a clear, comma-separated format.
Only include visible ingredients, and be specific but concise.''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/', imageData),
        ])
      ];

      final response = await model.generateContent(content);
      return response.text ?? 'No ingredients identified';
    } catch (e) {
      return 'Error analyzing image: $e';
    }
  }
}
