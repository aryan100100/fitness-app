// [HEALTH APP] — In-Memory Nutrition Cache
// LRU (Least Recently Used) cache for food search and barcode results.
// Prevents redundant API calls for repeated queries.
//
// Cache tiers:
//   Search results  — 50 entry cap, 10-minute TTL
//   Barcode results — 100 entry cap, 24-hour TTL
//
// No external packages — pure Dart LinkedHashMap ordered by insertion.
// Thread-safe for single-isolate Flutter apps.

import 'dart:collection';
import 'unified_food.dart';

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  _CacheEntry(this.value, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class NutritionCache {
  NutritionCache._();
  static final NutritionCache instance = NutritionCache._();

  // ── Search cache ─────────────────────────────────────────────────────────────
  static const int _searchCap = 50;
  static const Duration _searchTtl = Duration(minutes: 10);
  final LinkedHashMap<String, _CacheEntry<List<UnifiedFood>>> _searchCache =
      LinkedHashMap();

  // ── Barcode cache ─────────────────────────────────────────────────────────────
  static const int _barcodeCap = 100;
  static const Duration _barcodeTtl = Duration(hours: 24);
  final LinkedHashMap<String, _CacheEntry<UnifiedFood?>> _barcodeCache =
      LinkedHashMap();

  // ── Search cache API ──────────────────────────────────────────────────────────

  /// Returns cached search results for [query], or null on miss/expiry.
  List<UnifiedFood>? getSearch(String query) {
    final key = _searchKey(query);
    final entry = _searchCache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _searchCache.remove(key);
      return null;
    }
    // Move to end (most recently used)
    _searchCache.remove(key);
    _searchCache[key] = entry;
    return entry.value;
  }

  /// Stores [results] for [query] with the search TTL.
  void putSearch(String query, List<UnifiedFood> results) {
    if (results.isEmpty) return; // don't cache empty results
    final key = _searchKey(query);
    _evictIfNeeded(_searchCache, _searchCap);
    _searchCache[key] = _CacheEntry(
      List.unmodifiable(results),
      DateTime.now().add(_searchTtl),
    );
  }

  // ── Barcode cache API ─────────────────────────────────────────────────────────

  /// Returns the cached [UnifiedFood] for [barcode], or null if not in cache.
  /// Use [hasBarcode] to distinguish "not cached" from "confirmed not found".
  UnifiedFood? getBarcode(String barcode) {
    final entry = _barcodeCache[barcode];
    if (entry == null) return null;
    if (entry.isExpired) {
      _barcodeCache.remove(barcode);
      return null;
    }
    _barcodeCache.remove(barcode);
    _barcodeCache[barcode] = entry;
    return entry.value;
  }

  /// True if [barcode] has a cache entry (even if the product was not found).
  bool hasBarcode(String barcode) {
    final entry = _barcodeCache[barcode];
    if (entry == null) return false;
    if (entry.isExpired) {
      _barcodeCache.remove(barcode);
      return false;
    }
    return true;
  }

  /// Stores a barcode → product mapping. Pass null for "confirmed not found".
  void putBarcode(String barcode, UnifiedFood? product) {
    _evictIfNeeded(_barcodeCache, _barcodeCap);
    _barcodeCache[barcode] = _CacheEntry(
      product,
      DateTime.now().add(_barcodeTtl),
    );
  }

  // ── Manual invalidation ───────────────────────────────────────────────────────

  void invalidateSearch(String query) => _searchCache.remove(_searchKey(query));
  void invalidateBarcode(String barcode) => _barcodeCache.remove(barcode);
  void clearAll() {
    _searchCache.clear();
    _barcodeCache.clear();
  }

  // ── Internals ─────────────────────────────────────────────────────────────────

  String _searchKey(String query) => query.toLowerCase().trim();

  void _evictIfNeeded<T>(LinkedHashMap<String, _CacheEntry<T>> cache, int cap) {
    while (cache.length >= cap) {
      cache.remove(cache.keys.first); // LRU: first = oldest
    }
  }
}
