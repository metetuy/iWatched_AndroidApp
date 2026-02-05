import 'package:flutter/material.dart';

class FilterDialogUtil {
  static void showFilterDialog({
    required BuildContext context,
    required List<String> availableGenres,
    required Function(String sortBy, bool ascending, String? genreFilter) onApply,
  }) {
    String selectedSort = 'rating';
    bool ascending = false;
    String? selectedGenre;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Filter & Sort',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Genre Filter
              const Text('Filter by Genre:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownMenu<String?>(
                initialSelection: selectedGenre,
                expandedInsets: EdgeInsets.zero,
                textStyle: const TextStyle(color: Colors.white),
                hintText: 'All Genres',
                menuStyle: const MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(Color(0xFF2E2E2E)),
                ),
                inputDecorationTheme: const InputDecorationTheme(
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'All Genres'),
                  ...availableGenres.map((genre) => 
                    DropdownMenuEntry(value: genre, label: genre),
                  ),
                ],
                onSelected: (value) {
                  setState(() => selectedGenre = value);
                },
              ),
              const SizedBox(height: 16),
              // Sort By
              const Text('Sort by:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownMenu<String>(
                initialSelection: selectedSort,
                expandedInsets: EdgeInsets.zero,
                textStyle: const TextStyle(color: Colors.white),
                menuStyle: const MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(Color(0xFF2E2E2E)),
                ),
                inputDecorationTheme: const InputDecorationTheme(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'rating', label: 'Rating'),
                  DropdownMenuEntry(value: 'year', label: 'Year'),
                  DropdownMenuEntry(value: 'title', label: 'Title'),
                ],
                onSelected: (value) {
                  setState(() => selectedSort = value!);
                },
              ),
              const SizedBox(height: 16),
              // Order
              const Text('Order:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownMenu<bool>(
                initialSelection: ascending,
                expandedInsets: EdgeInsets.zero,
                textStyle: const TextStyle(color: Colors.white),
                menuStyle: const MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(Color(0xFF2E2E2E)),
                ),
                inputDecorationTheme: const InputDecorationTheme(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: false, label: 'Descending'),
                  DropdownMenuEntry(value: true, label: 'Ascending'),
                ],
                onSelected: (value) {
                  setState(() => ascending = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onApply(selectedSort, ascending, selectedGenre);
              },
              child: const Text('Apply', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
