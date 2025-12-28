import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iwatched/controllers/swipe_controller.dart';
import 'package:iwatched/homepage/profile_screen.dart';
import 'package:iwatched/homepage/swipe_page.dart';
import 'package:iwatched/homepage/watch_later_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController(initialPage: 1);
  int _selectedIndex = 1;

  late final SwipeController _swipeController;

  @override
  void initState() {
    super.initState();
    _swipeController = Get.put(SwipeController());
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomNav(),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const WatchLaterPage(),
          SwipePage(),
          Obx(() {
            final user = _swipeController.user.value;
            if (user == null) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              );
            }
            return ProfileScreen(user: user);
          }),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color.fromARGB(197, 0, 0, 0),
        iconSize: 20,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.red,
        selectedIconTheme: const IconThemeData(size: 28, color: Colors.red),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm_add, color: Colors.white),
            label: 'Watch Later',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.vibration, color: Colors.white),
            label: 'Swipe',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: Colors.white),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
