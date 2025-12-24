import 'package:flutter/material.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';

class ChatSidebar extends StatefulWidget {
  const ChatSidebar({super.key});

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  int _selectedIndex = 0;

  // Mock chat sessions - in real app this would come from a provider
  final List<Map<String, dynamic>> _chatSessions = [
    {'title': 'PDF Summary Analysis', 'time': '2 min ago', 'isActive': true},
    {'title': 'Document Q&A Session', 'time': '1 hour ago', 'isActive': false},
    {
      'title': 'Image Text Extraction',
      'time': '3 hours ago',
      'isActive': false,
    },
    {'title': 'File Security Check', 'time': 'Yesterday', 'isActive': false},
    {'title': 'Invoice Processing', 'time': '2 days ago', 'isActive': false},
    {'title': 'Contract Review', 'time': '3 days ago', 'isActive': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          right: BorderSide(color: AppTheme.textSecondary.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // Header with gradient
          _buildHeader(),

          // New Chat Button
          _buildNewChatButton(),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              color: AppTheme.textSecondary.withOpacity(0.1),
              height: 1,
            ),
          ),

          // Section Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Chats',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Chat Sessions List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _chatSessions.length,
              itemBuilder: (context, index) {
                return _buildChatItem(index, _chatSessions[index]);
              },
            ),
          ),

          // Footer with settings
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.15),
            AppTheme.surfaceColor,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Powered by Gemini',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewChatButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Create new chat
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.primaryColor.withOpacity(0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'New Chat',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(int index, Map<String, dynamic> chat) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppTheme.primaryColor.withOpacity(0.2))
                  : null,
            ),
            child: Row(
              children: [
                // Chat Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.15)
                        : AppTheme.textSecondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                // Chat Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.textPrimary
                              : AppTheme.textPrimary.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chat['time'],
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active indicator
                if (chat['isActive'] == true)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.textSecondary.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Settings Button
          Expanded(
            child: _buildFooterButton(
              Icons.settings_outlined,
              'Settings',
              () {},
            ),
          ),
          const SizedBox(width: 8),
          // Clear History Button
          Expanded(
            child: _buildFooterButton(
              Icons.delete_outline_rounded,
              'Clear',
              () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
