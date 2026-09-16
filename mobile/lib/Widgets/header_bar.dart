import 'package:flutter/material.dart';

import '../Services/app_controller.dart';
import '../Pages/perfil_screen.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({
    super.key,
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.avatarColor,
  });

  final AppController controller;
  final String title;
  final String subtitle;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/IMG_4803.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Haven',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: avatarColor.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: avatarColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${user?.nombre ?? title} ${user?.apellidos ?? ''}'
                              .trim(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PerfilScreen(controller: controller),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 16,
                          color: Color(0xFF1D4ED8),
                        ),
                        if (MediaQuery.sizeOf(context).width > 500) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'Mi Perfil',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: controller.logout,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout,
                          size: 16,
                          color: Color(0xFF475569),
                        ),
                        if (MediaQuery.sizeOf(context).width > 400) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'Cerrar sesión',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ADMIN SCREENS
// ==========================================
