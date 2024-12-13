import 'dart:io';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:gemini_flutter/services/gemini_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ingredientsController = TextEditingController();
  final _geminiService = GeminiService();
  final _imagePicker = ImagePicker();
  String? _recipe;
  bool _isLoading = false;
  File? _selectedImage;

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _isLoading = true;
      });

      final ingredients = await _geminiService.identifyIngredientsFromImage(_selectedImage!);
      
      setState(() {
        _isLoading = false;
        _ingredientsController.text = ingredients;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to process image: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade400,
      ),
    );
  }

  Future<void> _generateRecipe() async {
    if (_ingredientsController.text.isEmpty) {
      _showError('Please enter some ingredients first');
      return;
    }

    setState(() {
      _isLoading = true;
      _recipe = null;
    });

    try {
      final recipe = await _geminiService.generateRecipe(_ingredientsController.text);
      setState(() {
        _recipe = recipe;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to generate recipe: $e');
    }
  }

  @override
  void dispose() {
    _ingredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Generator'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImageSection(),
                    const SizedBox(height: 24),
                    _buildIngredientsInput(),
                    const SizedBox(height: 24),
                    _buildGenerateButton(),
                    const SizedBox(height: 24),
                    Expanded(child: _buildRecipeDisplay()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _showImageSourceDialog,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Add Ingredients Photo'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),
        if (_selectedImage != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Image.file(
                  _selectedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedImage = null),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIngredientsInput() {
    return TextField(
      controller: _ingredientsController,
      decoration: InputDecoration(
        labelText: 'Ingredients',
        hintText: 'Enter ingredients or add a photo',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.restaurant),
        suffixIcon: _ingredientsController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _ingredientsController.clear();
                  setState(() {
                    _selectedImage = null;
                    _recipe = null;
                  });
                },
              )
            : null,
      ),
      maxLines: 3,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _generateRecipe(),
    );
  }

  Widget _buildGenerateButton() {
    return FilledButton.icon(
      onPressed: _isLoading ? null : _generateRecipe,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.restaurant_menu),
      label: Text(_isLoading ? 'Generating...' : 'Generate Recipe'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildRecipeDisplay() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing your recipe...'),
          ],
        ),
      );
    }

    if (_recipe == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Add ingredients to generate a recipe',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _recipe!
              .split('\n')
              .map((line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: line.endsWith(':')
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
