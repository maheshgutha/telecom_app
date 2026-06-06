import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'dashboard_screen.dart';
import 'leads_screen.dart';
import 'my_calls_screen.dart';
import 'followups_screen.dart';
import 'campaigns_screen.dart';
import 'reports_screen.dart';
import 'users_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  // Admin/SuperAdmin: NO My Calls (admins don't make calls)
  List<_NavItem> _adminNavItems() => [
    _NavItem(Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
    _NavItem(Icons.people_rounded, Icons.people_outline, 'Leads'),
    _NavItem(Icons.event_note_rounded, Icons.event_note_outlined, 'Tasks'),
    _NavItem(Icons.campaign_rounded, Icons.campaign_outlined, 'Campaigns'),
    _NavItem(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Reports'),
    _NavItem(Icons.manage_accounts_rounded, Icons.manage_accounts_outlined, 'Users'),
    _NavItem(Icons.person_rounded, Icons.person_outline, 'Profile'),
  ];

  List<Widget> _adminScreens() => [
    const DashboardScreen(),
    const LeadsScreen(),
    const FollowUpsScreen(),
    const CampaignsScreen(),
    const ReportsScreen(),
    const UsersScreen(),
    const ProfileScreen(),
  ];

  // Caller: has My Calls
  List<_NavItem> _callerNavItems() => [
    _NavItem(Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
    _NavItem(Icons.people_rounded, Icons.people_outline, 'Leads'),
    _NavItem(Icons.phone_rounded, Icons.phone_outlined, 'My Calls'),
    _NavItem(Icons.event_note_rounded, Icons.event_note_outlined, 'Tasks'),
    _NavItem(Icons.campaign_rounded, Icons.campaign_outlined, 'Campaigns'),
    _NavItem(Icons.person_rounded, Icons.person_outline, 'Profile'),
  ];

  List<Widget> _callerScreens() => [
    const DashboardScreen(),
    const LeadsScreen(),
    const MyCallsScreen(),
    const FollowUpsScreen(),
    const CampaignsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isAdmin = auth.user?.isAdmin ?? false;

    final items = isAdmin ? _adminNavItems() : _callerNavItems();
    final screens = isAdmin ? _adminScreens() : _callerScreens();
    final safeIdx = _idx.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(index: safeIdx, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorder)),
          color: Colors.white,
        ),
        child: BottomNavigationBar(
          currentIndex: safeIdx,
          onTap: (i) => setState(() => _idx = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: kPurple,
          unselectedItemColor: Colors.grey.shade500,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          backgroundColor: Colors.white,
          elevation: 0,
          items: items.map((item) => BottomNavigationBarItem(
            icon: Icon(item.iconOff, size: 22),
            activeIcon: Icon(item.icon, size: 22),
            label: item.label,
          )).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, iconOff;
  final String label;
  _NavItem(this.icon, this.iconOff, this.label);
}