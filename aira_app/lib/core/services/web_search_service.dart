import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service for conducting live real-time web searches.
/// Uses DuckDuckGo and Wikipedia public APIs for fast, zero-auth, real-time web browsing.
class WebSearchService {
  static final WebSearchService _instance = WebSearchService._internal();
  factory WebSearchService() => _instance;
  WebSearchService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ),
  );

  /// Checks if a user prompt requires live web searching.
  bool shouldSearchWeb(String prompt) {
    final lower = prompt.toLowerCase();
    final triggers = [
      'search the web',
      'search web',
      'search online',
      'google this',
      'latest news',
      'today news',
      'current weather',
      'weather today',
      'who won',
      'live score',
      'hackathons 202',
      'internships 202',
      'open registration',
      'what happened today',
      'released this week',
      'latest release',
      'current stock price',
      'is it true that',
    ];

    return triggers.any((t) => lower.contains(t));
  }

  /// Extracts the search query from a user prompt.
  String cleanQuery(String prompt) {
    var q = prompt;
    final removals = [
      RegExp(r'^search the web for\s*', caseSensitive: false),
      RegExp(r'^search web for\s*', caseSensitive: false),
      RegExp(r'^search online for\s*', caseSensitive: false),
      RegExp(r'^google for\s*', caseSensitive: false),
      RegExp(r'^google\s*', caseSensitive: false),
      RegExp(r'^search for\s*', caseSensitive: false),
      RegExp(r'^please search\s*', caseSensitive: false),
      RegExp(r'^look up\s*', caseSensitive: false),
    ];

    for (final r in removals) {
      q = q.replaceAll(r, '');
    }
    return q.trim();
  }

  /// Conducts a live web search and returns formatted research context with source URLs.
  Future<String> search(String query) async {
    final cleanQ = cleanQuery(query);
    debugPrint('[WebSearchService] Searching web for: "$cleanQ"...');

    final results = <Map<String, String>>[];

    // 1. Try DuckDuckGo Instant Answer API
    try {
      final ddgResp = await _dio.get(
        'https://api.duckduckgo.com/',
        queryParameters: {
          'q': cleanQ,
          'format': 'json',
          'no_html': '1',
          'skip_disambig': '1',
        },
      );

      if (ddgResp.data is Map) {
        final data = ddgResp.data as Map;
        final abstractText = data['AbstractText'] as String? ?? '';
        final abstractUrl = data['AbstractURL'] as String? ?? '';
        final heading = data['Heading'] as String? ?? '';

        if (abstractText.isNotEmpty) {
          results.add({
            'title': heading.isNotEmpty ? heading : 'DuckDuckGo Summary',
            'snippet': abstractText,
            'url': abstractUrl.isNotEmpty ? abstractUrl : 'https://duckduckgo.com/?q=${Uri.encodeComponent(cleanQ)}',
          });
        }

        final relatedTopics = data['RelatedTopics'] as List? ?? [];
        for (final topic in relatedTopics.take(3)) {
          if (topic is Map && topic['Text'] != null) {
            final text = topic['Text'] as String;
            final url = topic['FirstURL'] as String? ?? '';
            if (text.isNotEmpty) {
              results.add({
                'title': text.split(' - ').first,
                'snippet': text,
                'url': url.isNotEmpty ? url : 'https://duckduckgo.com/?q=${Uri.encodeComponent(cleanQ)}',
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[WebSearchService] DuckDuckGo API error: $e');
    }

    // 2. Try DuckDuckGo HTML search for fresh real-time web results if needed
    if (results.length < 2) {
      try {
        final htmlResp = await _dio.get(
          'https://html.duckduckgo.com/html/',
          queryParameters: {'q': cleanQ},
        );

        if (htmlResp.data is String) {
          final html = htmlResp.data as String;
          // Extract result snippets using regex
          final snippetMatches = RegExp(r'class="result__snippet[^>]*>(.*?)<\/a>', dotAll: true).allMatches(html);
          final titleMatches = RegExp(r'class="result__title[^>]*>.*?<a[^>]*>(.*?)<\/a>', dotAll: true).allMatches(html);
          final urlMatches = RegExp(r'class="result__url[^>]*>(.*?)<\/span>', dotAll: true).allMatches(html);

          final titles = titleMatches.map((m) => _cleanHtml(m.group(1) ?? '')).toList();
          final snippets = snippetMatches.map((m) => _cleanHtml(m.group(1) ?? '')).toList();
          final urls = urlMatches.map((m) => _cleanHtml(m.group(1) ?? '')).toList();

          for (int i = 0; i < snippets.length && i < 4; i++) {
            final t = i < titles.length ? titles[i] : 'Web Result ${i + 1}';
            final s = snippets[i];
            final u = i < urls.length ? 'https://${urls[i].trim()}' : 'https://duckduckgo.com/?q=${Uri.encodeComponent(cleanQ)}';

            if (s.isNotEmpty) {
              results.add({
                'title': t,
                'snippet': s,
                'url': u,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[WebSearchService] DuckDuckGo HTML scraper error: $e');
      }
    }

    // 3. Fallback: Wikipedia OpenSearch API
    if (results.isEmpty) {
      try {
        final wikiResp = await _dio.get(
          'https://en.wikipedia.org/w/api.php',
          queryParameters: {
            'action': 'opensearch',
            'search': cleanQ,
            'limit': '3',
            'namespace': '0',
            'format': 'json',
          },
        );

        if (wikiResp.data is List && (wikiResp.data as List).length >= 4) {
          final titles = (wikiResp.data[1] as List).cast<String>();
          final snippets = (wikiResp.data[2] as List).cast<String>();
          final urls = (wikiResp.data[3] as List).cast<String>();

          for (int i = 0; i < titles.length; i++) {
            if (snippets[i].isNotEmpty) {
              results.add({
                'title': titles[i],
                'snippet': snippets[i],
                'url': urls[i],
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[WebSearchService] Wikipedia API error: $e');
      }
    }

    if (results.isEmpty) {
      return '';
    }

    // Format into LLM Research Context
    final buffer = StringBuffer();
    buffer.writeln('\n[LIVE WEB SEARCH RESULTS FOR: "$cleanQ"]');
    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      buffer.writeln('${i + 1}. Title: ${r['title']}');
      buffer.writeln('   Snippet: ${r['snippet']}');
      buffer.writeln('   Source: ${r['url']}');
    }
    buffer.writeln('[INSTRUCTION: Use the above live web search results to answer the user accurately. Include clickable markdown links in your response to cite sources.]\n');

    return buffer.toString();
  }

  String _cleanHtml(String str) {
    return str
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
