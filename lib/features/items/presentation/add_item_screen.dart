import 'dart:async';
import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'items_provider.dart';
import '../data/item_model.dart';
import '../../../core/api/api_client.dart';
import 'widgets/note_summarizing_animation.dart';

class AddItemScreen extends StatefulWidget {
  final Item? item;
  const AddItemScreen({super.key, this.item});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = 'text'; // 'text' or 'password'
  bool _hasChanges = false;
  bool _isSummarizing = false;
  bool _isViewingOriginal = false;
  String? _originalContent;
  String? _summaryContent;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _contentController.text = widget.item!.description;
      _selectedType = widget.item!.type;

      // Load original if exists (note is summarized)
      if (widget.item!.isSummarized) {
        _originalContent = widget.item!.originalContent;
        _summaryContent = widget.item!.description;
      }
    }

    _nameController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    // Mark as changed
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF0F172A) : Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header (Matched to design image)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Pure deep navy
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Back button (Left aligned)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 24,
                    ),
                  ),

                  // Title (Centrally aligned)
                  const Text(
                    'Notes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontFamily: 'Outfit', // Premium font if available
                    ),
                  ),

                  // Actions (Right aligned)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // View toggle (only if summarized)
                        if (_originalContent != null && _selectedType == 'text')
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: IconButton(
                              onPressed: _toggleView,
                              icon: Icon(
                                _isViewingOriginal
                                    ? Icons.auto_awesome
                                    : Icons.description,
                                color: _isViewingOriginal
                                    ? const Color(0xFFB794F4)
                                    : Colors.blue.shade300,
                                size: 24,
                              ),
                              tooltip: _isViewingOriginal
                                  ? 'Summary'
                                  : 'Original',
                            ),
                          ),

                        // Summarize button (AI Sparkles)
                        if (_selectedType == 'text' &&
                            !_isSummarizing &&
                            !provider.isLoading &&
                            _originalContent == null)
                          IconButton(
                            icon: const Icon(
                              Icons.auto_awesome,
                              color: Color(
                                0xFFB794F4,
                              ), // Premium lavender sparkles
                              size: 26,
                            ),
                            onPressed: _summarizeNote,
                            tooltip: 'Summarize',
                            splashRadius: 24,
                          ),

                        // Save button (only if changes exist)
                        if (_hasChanges && !provider.isLoading)
                          IconButton(
                            icon: Icon(
                              Icons.check_circle_outline,
                              color: Colors.green.shade400,
                              size: 26,
                            ),
                            onPressed: _saveNote,
                            tooltip: 'Save',
                            splashRadius: 24,
                          ),

                        // Autosaving/Loading indicator
                        if (provider.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFB794F4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Title Field
            Container(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Note Title',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Color(0xFF1E293B).withOpacity(0.5)
                      : Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),

            // Type Selector
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = 'text';
                          _hasChanges = true;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'text'
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedType == 'text'
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_rounded,
                              size: 20,
                              color: _selectedType == 'text'
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Text',
                              style: TextStyle(
                                color: _selectedType == 'text'
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                                fontWeight: _selectedType == 'text'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = 'password';
                          _hasChanges = true;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'password'
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedType == 'password'
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 20,
                              color: _selectedType == 'password'
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Password',
                              style: TextStyle(
                                color: _selectedType == 'password'
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                                fontWeight: _selectedType == 'password'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // AI Summarization Header (Conditional)
            if (_originalContent != null && !_isViewingOriginal)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB794F4).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFFB794F4),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'AI Summarization',
                      style: TextStyle(
                        color: Color(0xFFB794F4),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

            // Content Field
            Expanded(
              child: provider.isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Saving...',
                            style: TextStyle(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Color(0xFF1E293B).withOpacity(0.5)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        key: ValueKey(
                          'content_${_isViewingOriginal ? 'original' : 'summary'}',
                        ),
                        controller: _contentController,
                        maxLines: _selectedType == 'password' ? 1 : null,
                        expands: _selectedType != 'password',
                        obscureText: _selectedType == 'password',
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: _selectedType == 'password'
                              ? 'Enter your password here...'
                              : 'Start writing your note...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.outline.withOpacity(0.4),
                            fontSize: 16,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
            ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Manual save for notes
  Future<void> _saveNote() async {
    final provider = context.read<ItemsProvider>();
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Please enter a title'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Please enter some content'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    bool success;

    // Determine what to save based on viewing state
    String contentToSave = _contentController.text;
    String? originalToSave = _originalContent;
    bool isSummarized = _originalContent != null;

    // If we're viewing original, we need to swap what gets saved
    if (_isViewingOriginal && _originalContent != null) {
      // User is viewing (and possibly editing) original
      // So current text is the original, and summary is what's in _summaryContent
      // We want to save: description = _summaryContent, original_content = _contentController.text
      contentToSave =
          _summaryContent ?? _contentController.text; // This is the summary
      originalToSave = _contentController.text; // This is the original
    }

    if (widget.item == null) {
      success = await provider.addItem(
        name,
        contentToSave,
        type: _selectedType,
        isSummarized: isSummarized,
        summaryParagraph: isSummarized ? contentToSave : null,
        originalContent: originalToSave,
      );
    } else {
      success = await provider.updateItem(
        widget.item!.id,
        name,
        contentToSave,
        _selectedType,
        isSummarized: isSummarized,
        summaryParagraph: isSummarized ? contentToSave : null,
        originalContent: originalToSave,
      );
    }

    if (success && mounted) {
      setState(() {
        _hasChanges = false;
      });
      NotificationService().success("Note saved successfully");
    }
  }

  void _toggleView() {
    if (_isViewingOriginal) {
      // Switching BACK to summary view
      final summaryText = _summaryContent ?? '';
      setState(() {
        _isViewingOriginal = false;
        _contentController.value = TextEditingValue(
          text: summaryText,
          selection: TextSelection.collapsed(offset: summaryText.length),
        );
      });
    } else {
      // Switching TO original view
      // First, ensure we store the current content as summary if not already stored
      if (_summaryContent == null || _summaryContent!.isEmpty) {
        _summaryContent = _contentController.text;
      }
      final originalText = _originalContent ?? '';
      setState(() {
        _isViewingOriginal = true;
        _contentController.value = TextEditingValue(
          text: originalText,
          selection: TextSelection.collapsed(offset: originalText.length),
        );
      });
    }
  }

  void _summarizeNote() async {
    // Validate content length
    if (_contentController.text.trim().length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Note is too short to summarize (minimum 50 characters)',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Check if already has summary
    if (_originalContent != null) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Re-summarize Note?'),
          content: Text(
            'This note already has an AI summary. Do you want to create a new summary from the original content?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Re-summarize'),
            ),
          ],
        ),
      );

      if (shouldReplace != true) return;
    }

    setState(() {
      _isSummarizing = true;
    });

    // Show animation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: NoteSummarizingAnimation(),
      ),
    );

    try {
      // Store current content as original
      final originalText = _contentController.text;

      // Call AI API
      final result = await ApiClient().summarizeNoteContent(originalText);
      final summary = result['summary_paragraph'] as String? ?? '';

      // Close animation dialog
      if (mounted) Navigator.pop(context);

      if (summary.isEmpty) {
        throw Exception("AI returned empty summary");
      }

      // Replace content with summary and store original
      setState(() {
        _originalContent = originalText;
        _summaryContent = summary;
        _contentController.text = summary;
        _isSummarizing = false;
        _hasChanges = true;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white),
                SizedBox(width: 12),
                Text('Summary added successfully!'),
              ],
            ),
            backgroundColor: Colors.purple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // Close animation dialog
      if (mounted) Navigator.pop(context);

      setState(() {
        _isSummarizing = false;
      });

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to summarize: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
