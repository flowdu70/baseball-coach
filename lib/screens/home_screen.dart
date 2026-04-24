import 'package:flutter/material.dart';
import 'players_screen.dart';
import 'calculator_screen.dart';
import 'video_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    VideoAnalysisScreen(),
    CalculatorScreen(),
    PlayersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.videocam),
            label: 'Analyser',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_baseball),
            label: 'Calculateur',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Joueurs',
          ),
        ],
      ),
    );
  }
}
