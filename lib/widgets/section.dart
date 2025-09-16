import 'package:flutter/material.dart';

class Section extends StatelessWidget {
  final String title;
  final String text;
  const Section({super.key, required this.title, required this.text});
  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );
  }
}
