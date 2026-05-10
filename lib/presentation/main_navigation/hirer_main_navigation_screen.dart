import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../hirer/applicants_screen.dart';
import '../hirer/hirer_dashboard_screen.dart';
import '../hirer/manage_jobs_screen.dart';
import '../profile/profile_screen.dart';
import '../widgets/custom_bottom_nav.dart';

/// Hirer-mode tab shell. Mirrors `MainNavigationScreen` but with the
/// hirer-specific destinations + a purple accent so users know visually
/// they're in the employer side of the app.
class HirerMainNavigationScreen extends StatefulWidget {
  const HirerMainNavigationScreen({super.key});

  @override
  State<HirerMainNavigationScreen> createState() =>
      _HirerMainNavigationScreenState();
}

class _HirerMainNavigationScreenState extends State<HirerMainNavigationScreen> {
  int _currentIndex = 0;

  // 4-tab hirer layout. Messages was promoted out of the bottom nav into
  // the dashboard top-header (next to the notification bell) — keeps the
  // bar lean and groups system-level alerts (notifications + chat) in one
  // visual cluster.
  final List<Widget> _screens = const [
    HirerDashboardScreen(),
    ManageJobsScreen(),
    ApplicantsScreen(),
    ProfileScreen(),
  ];

  static const _tabs = [
    NavTabItem(
      label: 'Hirer',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    NavTabItem(
      label: 'Jobs',
      icon: Icons.post_add_outlined,
      activeIcon: Icons.post_add,
    ),
    NavTabItem(
      label: 'Applicants',
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_alt_rounded,
    ),
    NavTabItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  // Purple gradient — visual cue that we're on the hirer side.
  static const _purpleGradient = [
    Color(0xFF6D5BD0),
    Color(0xFF4B3C9F),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _tabs,
        pillGradient: _purpleGradient,
      ),
    );
  }
}
