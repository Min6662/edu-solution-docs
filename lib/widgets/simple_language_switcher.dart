import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

class SimpleLanguageSwitcher extends StatefulWidget {
  const SimpleLanguageSwitcher({super.key});

  @override
  State<SimpleLanguageSwitcher> createState() => _SimpleLanguageSwitcherState();
}

class _SimpleLanguageSwitcherState extends State<SimpleLanguageSwitcher> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return GestureDetector(
          onTapDown: (_) {
            setState(() => _isTapped = true);
            print('Language switcher tapped down');
          },
          onTapUp: (_) {
            setState(() => _isTapped = false);
          },
          onTapCancel: () {
            setState(() => _isTapped = false);
          },
          onTap: () {
            print('Language switcher onTap triggered');

            // Toggle between English and Khmer
            final currentCode = languageService.currentLocale.languageCode;
            final newLocale =
                currentCode == 'en' ? const Locale('km') : const Locale('en');

            print('Switching from $currentCode to ${newLocale.languageCode}');
            languageService.changeLanguage(newLocale);

            // Show a snackbar for user feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Language switched to ${languageService.getLanguageName(newLocale.languageCode)}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isTapped
                  ? Colors.white.withOpacity(0.8)
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isTapped
                    ? Colors.blue.withOpacity(0.5)
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: _isTapped ? 4 : 8,
                  offset: Offset(0, _isTapped ? 1 : 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  languageService.getLanguageFlag(
                      languageService.currentLocale.languageCode),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  languageService.getLanguageName(
                      languageService.currentLocale.languageCode),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
