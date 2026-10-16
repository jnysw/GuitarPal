import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The persistent top-level navigation used by GuitarPal's four main areas.
///
/// "新建" is intentionally an action rather than a fifth navigation branch.
/// This keeps the user's current branch intact while the creation flow is
/// presented above it.
class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  int get _selectedDestinationIndex {
    return switch (navigationShell.currentIndex) {
      0 => 0,
      1 => 1,
      2 => 3,
      3 => 4,
      _ => 0,
    };
  }

  void _onDestinationSelected(BuildContext context, int destinationIndex) {
    if (destinationIndex == 2) {
      context.push('/create');
      return;
    }

    final branchIndex = switch (destinationIndex) {
      0 => 0,
      1 => 1,
      3 => 2,
      4 => 3,
      _ => 0,
    };

    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('app_navigation_shell'),
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: NavigationBar(
          key: const Key('primary_navigation_bar'),
          selectedIndex: _selectedDestinationIndex,
          onDestinationSelected: (index) =>
              _onDestinationSelected(context, index),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              key: Key('navigation_today'),
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: '今日',
            ),
            NavigationDestination(
              key: Key('navigation_library'),
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: '练习库',
            ),
            NavigationDestination(
              key: Key('navigation_create'),
              icon: _CreateDestinationIcon(),
              selectedIcon: _CreateDestinationIcon(),
              label: '新建',
            ),
            NavigationDestination(
              key: Key('navigation_plans'),
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: '计划',
            ),
            NavigationDestination(
              key: Key('navigation_profile'),
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateDestinationIcon extends StatelessWidget {
  const _CreateDestinationIcon();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.add_rounded, color: colors.onPrimary),
    );
  }
}
