import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import 'package:file_stroage_system/core/presentation/widgets/notification_listener.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
    : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NotificationListenerWidget(child: navigationShell),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.8),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF00F0FF).withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: const Color(0xFF00F0FF).withOpacity(0.2),
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (int index) => _onTap(context, index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded, color: Colors.grey),
                  selectedIcon: Icon(
                    Icons.grid_view_rounded,
                    color: Color(0xFF00F0FF),
                  ),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_open_rounded, color: Colors.grey),
                  selectedIcon: Icon(
                    Icons.folder_open_rounded,
                    color: Color(0xFF00F0FF),
                  ),
                  label: 'Files',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined, color: Colors.grey),
                  selectedIcon: Icon(Icons.notes, color: Color(0xFF00F0FF)),
                  label: 'Notes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.devices_rounded, color: Colors.grey),
                  selectedIcon: Icon(
                    Icons.devices_rounded,
                    color: Color(0xFF00F0FF),
                  ),
                  label: 'Devices',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
