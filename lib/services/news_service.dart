import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NewsHeadline {
  final String title;
  final String summary;
  final String source;
  final DateTime publishedAt;

  NewsHeadline({
    required this.title,
    required this.summary,
    required this.source,
    required this.publishedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'source': source,
        'publishedAt': publishedAt.toIso8601String(),
      };

  factory NewsHeadline.fromJson(Map<String, dynamic> json) => NewsHeadline(
        title: json['title'] ?? '',
        summary: json['summary'] ?? '',
        source: json['source'] ?? '',
        publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
      );
}

/// Fetches news headlines when online and caches them for fully offline use.
class NewsService extends GetxService {
  static const _boxName = 'news_cache';
  static const _headlinesKey = 'headlines';
  static const _lastSyncKey = 'last_sync';

  late Box _box;

  final isSyncing = false.obs;
  final lastSyncTime = Rxn<DateTime>();
  final headlines = <NewsHeadline>[].obs;

  // Free RSS feeds — no API key needed
    final List<Map<String, String>> _feeds = [
      {'name': 'BBC World', 'url': 'https://feeds.bbci.co.uk/news/world/rss.xml'},
      {'name': 'BBC Asia', 'url': 'https://feeds.bbci.co.uk/news/world/asia/rss.xml'},
      {'name': 'TechCrunch', 'url': 'https://techcrunch.com/feed/'},
      {'name': 'NDTV Top Stories', 'url': 'https://feeds.feedburner.com/ndtvnews-top-stories'},
      {'name': 'NDTV India', 'url': 'https://feeds.feedburner.com/ndtvnews-india-news'},
      {'name': 'Times of India', 'url': 'https://timesofindia.indiatimes.com/rssfeedstopstories.cms'},
      {'name': 'Hindustan Times', 'url': 'https://www.hindustantimes.com/feeds/rss/india-news/rssfeed.xml'},
    ];

  Future<NewsService> init() async {
    _box = await Hive.openBox(_boxName);
    _loadFromCache();
    return this;
  }

  void _loadFromCache() {
    final raw = _box.get(_headlinesKey);
    if (raw != null) {
      final List list = jsonDecode(raw);
      headlines.value = list.map((e) => NewsHeadline.fromJson(e)).toList();
    }
    final lastSync = _box.get(_lastSyncKey);
    if (lastSync != null) {
      lastSyncTime.value = DateTime.tryParse(lastSync);
    }
  }

  /// Fetch fresh headlines. Safe to call anytime — fails silently offline.
  Future<void> syncNews() async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    try {
      final List<NewsHeadline> allHeadlines = [];
      for (final feed in _feeds) {
        try {
          final response = await http
              .get(Uri.parse(feed['url']!))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            allHeadlines.addAll(_parseRss(response.body, feed['name']!));
          }
        } catch (_) {
          // Skip this one feed, keep going with the others
        }
      }

      if (allHeadlines.isNotEmpty) {
        allHeadlines.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        final top = allHeadlines.take(80).toList();
        headlines.value = top;
        await _box.put(_headlinesKey, jsonEncode(top.map((e) => e.toJson()).toList()));
        final now = DateTime.now();
        lastSyncTime.value = now;
        await _box.put(_lastSyncKey, now.toIso8601String());
      }
    } finally {
      isSyncing.value = false;
    }
  }

  List<NewsHeadline> _parseRss(String xmlString, String sourceName) {
    final results = <NewsHeadline>[];
    try {
      final document = XmlDocument.parse(xmlString);
      for (final item in document.findAllElements('item')) {
        final titleEls = item.findElements('title');
        final descEls = item.findElements('description');
        final dateEls = item.findElements('pubDate');
        final title = titleEls.isNotEmpty ? titleEls.first.innerText : '';
        final description = descEls.isNotEmpty ? descEls.first.innerText : '';
        final pubDateStr = dateEls.isNotEmpty ? dateEls.first.innerText : '';

        DateTime pubDate;
        try {
          pubDate = HttpDate.parse(pubDateStr);
        } catch (_) {
          pubDate = DateTime.now();
        }

        if (title.isNotEmpty) {
          results.add(NewsHeadline(
            title: title,
            summary: _stripHtml(description),
            source: sourceName,
            publishedAt: pubDate,
          ));
        }
      }
    } catch (_) {}
    return results;
  }

  String _stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  /// Text block to inject into the model's prompt when relevant.
    String buildNewsContext({int maxItems = 12}) {
    if (headlines.isEmpty) {
      return 'No cached news is available yet. Tell the user to sync news while online.';
    }
    final buffer = StringBuffer();
    buffer.writeln('Recent news headlines (cached from last sync, may be a bit old):');
    for (final h in headlines.take(maxItems)) {
      buffer.writeln('- [${h.source}] ${h.title}');
      if (h.summary.isNotEmpty) buffer.writeln('  ${h.summary}');
    }
    return buffer.toString();
  }

  bool isNewsQuery(String text) {
    final lower = text.toLowerCase();
    const keywords = ['news', 'latest', 'recent', 'today', 'happening', 'current event', "what's new"];
    return keywords.any(lower.contains);
  }
}