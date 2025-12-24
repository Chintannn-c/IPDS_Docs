import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../api/api_client.dart';

class SecureAvatar extends StatefulWidget {
  final String? imageUrl;
  final String fallbackInitials;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const SecureAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackInitials,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<SecureAvatar> createState() => _SecureAvatarState();
}

class _SecureAvatarState extends State<SecureAvatar> {
  Uint8List? _imageBytes;
  String? _lastUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SecureAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.imageUrl == null) {
      if (mounted) setState(() => _imageBytes = null);
      return;
    }

    _lastUrl = widget.imageUrl;
    // Construct full URL if needed, but ApiClient usually expects relative or handles absolute
    final url = widget.imageUrl!.startsWith('http')
        ? widget.imageUrl!
        : '${ApiClient().baseUrl}${widget.imageUrl}';

    final bytes = await ApiClient().fetchImageBytes(url);
    if (mounted && bytes != null) {
      setState(() => _imageBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? Colors.blue.withOpacity(0.2),
      backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
      child: _imageBytes == null
          ? Text(
              widget.fallbackInitials.isNotEmpty
                  ? widget.fallbackInitials[0].toUpperCase()
                  : 'U',
              style: TextStyle(
                color: widget.textColor ?? Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: widget.radius * 0.8,
              ),
            )
          : null,
    );
  }
}
