import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'items_provider.dart';

import '../data/item_model.dart';

class AddItemScreen extends StatefulWidget {
  final Item? item;
  const AddItemScreen({super.key, this.item});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = 'text'; // 'text' or 'password'
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _contentController.text = widget.item!.description;
      _selectedType = widget.item!.type;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<ItemsProvider>();

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundColor
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add New Note' : 'Edit Note'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Note TYPE',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _typeButton(
                    'text',
                    Icons.description_outlined,
                    'Personal Text',
                  ),
                  const SizedBox(width: 12),
                  _typeButton(
                    'password',
                    Icons.lock_outline_rounded,
                    'Password',
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Text(
                'DETAILS',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name / Title',
                  hintText: _selectedType == 'password'
                      ? 'e.g., Netflix Login'
                      : 'e.g., Personal Note',
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _contentController,
                obscureText: _selectedType == 'password' && _obscurePassword,
                maxLines: _selectedType == 'password' ? 1 : 5,
                decoration: InputDecoration(
                  labelText: _selectedType == 'password'
                      ? 'Password'
                      : 'Information',
                  hintText: _selectedType == 'password'
                      ? 'Enter password'
                      : 'Enter your personal text here...',
                  prefixIcon: Icon(
                    _selectedType == 'password'
                        ? Icons.key_rounded
                        : Icons.notes_rounded,
                  ),
                  suffixIcon: _selectedType == 'password'
                      ? IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        )
                      : null,
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter content' : null,
              ),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _saveItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'SAVE NOTE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton(String type, IconData icon, String label) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.1)
                : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveItem() async {
    if (_formKey.currentState!.validate()) {
      bool success;
      if (widget.item == null) {
        success = await context.read<ItemsProvider>().addItem(
          _nameController.text,
          _contentController.text,
          type: _selectedType,
        );
      } else {
        success = await context.read<ItemsProvider>().updateItem(
          widget.item!.id,
          _nameController.text,
          _contentController.text,
          _selectedType,
        );
      }
      if (success && mounted) {
        Navigator.pop(context);
      }
    }
  }
}
