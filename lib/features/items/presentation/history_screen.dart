import 'package:file_stroage_system/core/presentation/widgets/responsive_center.dart';
import 'package:file_stroage_system/features/dashboard/presentation/summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SummaryProvider>().fetchHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<SummaryProvider>();

    final filteredItems = provider.summaries.where((item) {
      final query = _searchQuery.toLowerCase();
      return item.documentName.toLowerCase().contains(query) ||
          item.summary.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analysis History"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search history...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark
                        ? theme.colorScheme.surface
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              // Filtered List
              Expanded(
                child: provider.isLoading && provider.summaries.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filteredItems.isEmpty
                    ? _buildEmptyState(context, _searchQuery.isNotEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredItems.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final item = filteredItems[i];
                          return _buildHistoryCard(context, item, provider);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isSearching) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSearching
                ? Icons.search_off_rounded
                : Icons.history_toggle_off_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? "No matching items found" : "No history yet",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    Summary item,
    SummaryProvider provider,
  ) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Item?"),
            content: const Text(
              "Are you sure you want to delete this from history?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Delete"),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        // provider.deleteSummary(item.id);
      },
      background: Container(
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/document_analysis',
                arguments: {
                  'fileId': item.documentId,
                  'filename': item.documentName,
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.documentName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'v${item.version}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(item.summarizedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        if (item.riskFlags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.riskFlags.length} Risks detected',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
