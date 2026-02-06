import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CacheManager {
  static Future<void> clearImageCache() async {
    // Clear cached network images
    await CachedNetworkImage.evictFromCache('');
    
    // Clear Flutter's image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
  
  static void clearMemoryCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
