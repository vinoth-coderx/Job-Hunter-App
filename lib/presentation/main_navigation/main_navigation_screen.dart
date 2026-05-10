import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../applications/applications_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../widgets/custom_bottom_nav.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // 4-tab seeker layout: Home, Search, Applied, Profile.
  // Messages was promoted out of the bottom nav into the Home top-header
  // (next to the notification bell) — keeps the bar lean and matches the
  // pattern most messaging-rich apps use.
  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(embedded: true),
    ApplicationsScreen(),
    ProfileScreen(),
  ];

  static const _tabs = [
    NavTabItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    NavTabItem(
      label: 'Search',
      icon: Icons.search_rounded,
      activeIcon: Icons.search_rounded,
    ),
    NavTabItem(
      label: 'Applied',
      icon: Icons.work_outline_rounded,
      activeIcon: Icons.work_rounded,
    ),
    NavTabItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      extendBody: false,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          final wasOnDifferentTab = _currentIndex != i;
          setState(() => _currentIndex = i);
          // Returning to Home from any other tab should silently refresh
          // the discovery feed if the cached data is stale (controlled by
          // JobProvider's auto-refresh window). Without this, IndexedStack
          // keeps the Home screen mounted indefinitely and the user sees
          // the same matched jobs across the whole session.
          if (i == 0 && wasOnDifferentTab) {
            final isGuest = context.read<AuthProvider>().isGuest;
            context.read<JobProvider>().maybeAutoRefresh(asGuest: isGuest);
          }
        },
        items: _tabs,
      ),
    );
  }
}
