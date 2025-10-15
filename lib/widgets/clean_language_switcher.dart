import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

class CleanLanguageSwitcher extends StatelessWidget {
  const CleanLanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return GestureDetector(
          onTap: () {
            print('CleanLanguageSwitcher tapped!'); // Debug log
            final currentCode = languageService.currentLocale.languageCode;
            final newLocale =
                currentCode == 'en' ? const Locale('km') : const Locale('en');
            print('Switching from $currentCode to ${newLocale.languageCode}');
            languageService.changeLanguage(newLocale);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  languageService.getLanguageFlag(
                      languageService.currentLocale.languageCode),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  languageService.getLanguageName(
                      languageService.currentLocale.languageCode),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
