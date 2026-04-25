import 'package:flutter/material.dart';
import '../models/article.dart';
import 'news_card.dart';

class GridLayout extends StatelessWidget {
  final List<Article> articles;
  const GridLayout({super.key, required this.articles});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth > 1200
              ? 3
              : constraints.maxWidth > 700
                  ? 2
                  : 1;
          return Wrap(
            spacing: 8,
            runSpacing: 0,
            children: articles.map((a) {
              final width = (constraints.maxWidth - 8 * (cols - 1)) / cols - 1;
              return SizedBox(
                width: width,
                child: NewsCard(article: a),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
