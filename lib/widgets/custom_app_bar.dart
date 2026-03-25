import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final VoidCallback? onAvatarTap;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onMenuTap,
    this.onAvatarTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /// Menu Icon
          Builder(
            builder: (context) => IconButton(
              onPressed: onMenuTap ?? () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu, color: Colors.greenAccent),
            ),
          ),
          /// App Title
          Text(
            title,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 18,
            ),
          ),
          /// Profile Avatar
          GestureDetector(
            onTap: onAvatarTap ?? () => debugPrint("Avatar clicked"),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.greenAccent,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.black87,
                backgroundImage: const NetworkImage(
                  "https://static.vecteezy.com/system/resources/thumbnails/048/216/761/small/modern-male-avatar-with-black-hair-and-hoodie-illustration-free-png.png",
                ),
                onBackgroundImageError: (exception, stackTrace) {
                  debugPrint("Avatar image failed to load: $exception");
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}