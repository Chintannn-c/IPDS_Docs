import 'package:flutter/material.dart';

class NoteEditorScreen extends StatefulWidget {
  final String initialContent;
  final String title;

  const NoteEditorScreen({
    super.key,
    required this.initialContent,
    required this.title,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _controller;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() {
      if (!_hasChanges && _controller.text != widget.initialContent) {
        setState(() {
          _hasChanges = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: () {
                // Save functionality - you can add backend save here
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Saved successfully!')));
                setState(() {
                  _hasChanges = false;
                });
              },
              child: Text(
                'Save',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          hintText: 'Start typing...',
        ),
        style: TextStyle(fontSize: 16, height: 1.6, fontFamily: 'monospace'),
      ),
    );
  }
}
