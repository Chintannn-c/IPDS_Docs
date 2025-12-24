import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../../../../core/presentation/theme/app_theme.dart';

class ImageCropScreen extends StatefulWidget {
  final Uint8List image;

  const ImageCropScreen({super.key, required this.image});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Adjust Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (!_isCropping)
            TextButton(
              onPressed: () {
                setState(() => _isCropping = true);
                _controller.crop();
              },
              child:  Text(
                'Done',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          if (_isCropping)
             Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.image,
              controller: _controller,
              onCropped: (image) {
                Navigator.pop(context, image);
              },
              aspectRatio: 1 / 1,
              initialSize: 0.5,
              baseColor: Colors.black,
              maskColor: Colors.black.withOpacity(0.5),
              cornerDotBuilder: (size, edgeAlignment) => Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Drag corners to adjust',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
