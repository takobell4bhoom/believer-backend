import 'package:flutter/material.dart';

import '../../navigation/app_routes.dart';
import 'app_bottom_nav.dart';

enum MainAppTab {
  home,
  discover,
  notifications,
  services,
}

class MainBottomNavBar extends StatelessWidget {
  const MainBottomNavBar({
    super.key,
    required this.activeTab,
  });

  final MainAppTab activeTab;

  @override
  Widget build(BuildContext context) {
    return AppBottomNav(
      activeIndex: activeTab.index,
      items: [
        AppBottomNavItem(
          icon: Icons.home_outlined,
          label: 'Home',
          onTap: () => _openTab(context, MainAppTab.home),
        ),
        AppBottomNavItem(
          icon: Icons.travel_explore_outlined,
          label: 'Mosques & Events',
          onTap: () => _openTab(context, MainAppTab.discover),
        ),
        AppBottomNavItem(
          icon: Icons.notifications_none,
          label: 'Notifications',
          onTap: () => _openTab(context, MainAppTab.notifications),
        ),
        AppBottomNavItem(
          icon: Icons.miscellaneous_services_outlined,
          label: 'Services',
          onTap: () => _openTab(context, MainAppTab.services),
        ),
      ],
    );
  }

  void _openTab(BuildContext context, MainAppTab tab) {
    if (tab == activeTab) {
      return;
    }

    Navigator.of(context).pushNamed(_routeFor(tab));
  }

  String _routeFor(MainAppTab tab) {
    switch (tab) {
      case MainAppTab.home:
        return AppRoutes.home;
      case MainAppTab.discover:
        return AppRoutes.mosqueSearch;
      case MainAppTab.notifications:
        return AppRoutes.notifications;
      case MainAppTab.services:
        return AppRoutes.services;
    }
  }
}
