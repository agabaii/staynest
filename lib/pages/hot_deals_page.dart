import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/property.dart';
import 'property_detail_page.dart';
import '../providers/app_state.dart';
import '../widgets/change_notifier_provider.dart';

class HotDealsPage extends StatelessWidget {
  final List<dynamic> discounts;
  final String category;

  const HotDealsPage({
    Key? key, 
    required this.discounts, 
    this.category = 'Все'
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = ChangeNotifierProvider.of<AppState>(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          category == 'Все' ? 'Горящие предложения' : 'Горящие: $category',
          style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: discounts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Пока нет горящих предложений',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: discounts.length,
              itemBuilder: (context, index) {
                final item = discounts[index];
                final p = item['property'];
                final price = (item['price'] ?? 0.0).toDouble();
                final datesList = item['dates'] as List?;
                final dates = (datesList ?? []).map((d) => DateTime.tryParse(d.toString()) ?? DateTime.now()).toList();
                dates.sort();
                final property = Property.fromJson(p);

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              child: CachedNetworkImage(
                                imageUrl: property.images.isNotEmpty ? property.images[0] : '',
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.grey[100]),
                                errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.error)),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ВЫГОДА',
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      property.title,
                                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    state.getFormattedPrice(price),
                                    style: GoogleFonts.inter(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.w900, 
                                      color: Colors.red[700]
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (dates.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Даты: ${DateFormat('dd.MM').format(dates.first)}${dates.length > 1 ? ' - ${DateFormat('dd.MM').format(dates.last)}' : ''}',
                                    style: GoogleFonts.inter(color: Colors.orange[800], fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${property.city}, ${property.country}',
                                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildInfoTag(Icons.king_bed_outlined, '${property.bedrooms} сп'),
                                  const SizedBox(width: 12),
                                  _buildInfoTag(Icons.square_foot, '${property.area ?? 0} м²'),
                                  const Spacer(),
                                  Text(
                                    'вместо ${state.getFormattedPrice(property.price)}',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[400], 
                                      fontSize: 12, 
                                      decoration: TextDecoration.lineThrough
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoTag(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
      ],
    );
  }
}
