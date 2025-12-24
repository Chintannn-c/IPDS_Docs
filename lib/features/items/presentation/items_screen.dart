import 'package:file_stroage_system/features/items/presentation/add_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'items_provider.dart';
import '../data/item_model.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ItemsProvider>();
      await provider.fetchItems();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundColor
          : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Notes',
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textPrimary : AppTheme.textPrimary,
                    fontSize: 20,
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Builder(
                builder: (context) {
                  if (provider.isLoading && provider.items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Show authentication prompt if not authenticated
                  if (provider.items.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildItemsList(provider.items);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'items_fab',
        onPressed: () => Navigator.pushNamed(context, '/items/add'),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No items yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your items will appear here',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<Item> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildItemCard(item);
      },
    );
  }

  Widget _buildItemCard(Item item) {
    final bool isPassword = item.type == 'password';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddItemScreen(item: item)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isPassword ? Colors.orange : Colors.blue).withOpacity(
                  0.1,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                isPassword
                    ? Icons.lock_outline_rounded
                    : Icons.description_outlined,
                color: isPassword ? Colors.orange : Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPassword ? '••••••••' : item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppTheme.errorColor.withOpacity(0.7),
              onPressed: () {
                context.read<ItemsProvider>().deleteItem(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
