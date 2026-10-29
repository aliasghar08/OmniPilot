import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Reusable top AppBar for OmniPilot with brand icon, refresh action, and optional mobile TabBar.
class OmniPilotAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isWide;
  final TabController tabController;
  final VoidCallback onRefreshPermissions;

  const OmniPilotAppBar({
    super.key,
    required this.isWide,
    required this.tabController,
    required this.onRefreshPermissions,
  });

  @override
  Size get preferredSize => Size.fromHeight(isWide ? kToolbarHeight : kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      title: const Row(
        children: [
          AppBrandIcon(size: 32, borderRadius: 8),
          SizedBox(width: 10),
          Text(
            AppConstants.appName,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh permissions & status',
          onPressed: onRefreshPermissions,
        ),
      ],
      bottom: isWide
          ? null
          : TabBar(
              controller: tabController,
              tabs: const [
                Tab(icon: Icon(Icons.settings_system_daydream), text: 'Cross-App AI'),
                Tab(icon: Icon(Icons.assignment_turned_in), text: 'Period Form'),
                Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Assistant'),
              ],
            ),
    );
  }
}
