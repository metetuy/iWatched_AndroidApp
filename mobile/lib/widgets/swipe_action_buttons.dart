import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

class SwipeActionButtons extends StatelessWidget {
  final CardSwiperController controller;

  const SwipeActionButtons({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.close_rounded,
            color: Colors.red,
            size: 30,
            onPressed: () => controller.swipe(CardSwiperDirection.left),
          ),
          _ActionButton(
            icon: Icons.undo,
            color: Colors.white,
            iconColor: Colors.black,
            size: 30,
            onPressed: () => controller.undo(),
          ),
          _ActionButton(
              icon: Icons.favorite,
              color: const Color.fromARGB(255, 107, 21, 245),
              size: 35,
              onPressed: () => controller.swipe(CardSwiperDirection.bottom)),
          _ActionButton(
            icon: Icons.alarm_add,
            color: const Color.fromARGB(255, 21, 118, 245),
            size: 30,
            onPressed: () => controller.swipe(CardSwiperDirection.top),
          ),
          _ActionButton(
            icon: Icons.check_rounded,
            color: Colors.green,
            size: 30,
            onPressed: () => controller.swipe(CardSwiperDirection.right),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.iconColor = Colors.white,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(13),
      ),
      child: Icon(icon, size: size, color: iconColor),
    );
  }
}
