// lib/data/models/models.dart

// ── Channel ────────────────────────────────────────────────────────────────
class ChannelModel {
  const ChannelModel({
    required this.id,
    required this.name,
    required this.category,
    required this.streamUrl,
    required this.logoUrl,
    required this.description,
    required this.quality,
    this.isPremium = false,
    this.channelNumber = 0,
  });

  final String id;
  final String name;
  final String category;
  final String streamUrl;
  final String logoUrl;
  final String description;
  final String quality;
  final bool   isPremium;
  final int    channelNumber;

  factory ChannelModel.fromJson(Map<String, dynamic> j) => ChannelModel(
        id:            j['id']            as String? ?? '',
        name:          j['name']          as String? ?? '',
        category:      j['category']      as String? ?? '',
        streamUrl:     j['streamUrl']     as String? ?? '',
        logoUrl:       j['logoUrl']       as String? ?? '',
        description:   j['description']   as String? ?? '',
        quality:       j['quality']       as String? ?? 'HD',
        isPremium:     j['isPremium']     as bool?   ?? false,
        channelNumber: j['channelNumber'] as int?    ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'category': category,
        'streamUrl': streamUrl, 'logoUrl': logoUrl,
        'description': description, 'quality': quality,
        'isPremium': isPremium, 'channelNumber': channelNumber,
      };
}

// ── Category ───────────────────────────────────────────────────────────────
class CategoryModel {
  const CategoryModel({required this.name, required this.icon});
  final String name;
  final String icon;

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
        name: j['name'] as String? ?? '',
        icon: j['icon'] as String? ?? '📺',
      );
}

// ── Banner ─────────────────────────────────────────────────────────────────
class BannerModel {
  const BannerModel({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.channelId,
  });
  final String title;
  final String subtitle;
  final String imageUrl;
  final String channelId;

  factory BannerModel.fromJson(Map<String, dynamic> j) => BannerModel(
        title:     j['title']     as String? ?? '',
        subtitle:  j['subtitle']  as String? ?? '',
        imageUrl:  j['imageUrl']  as String? ?? '',
        channelId: j['channelId'] as String? ?? '',
      );
}

// ── Subscription Plan ──────────────────────────────────────────────────────
class PlanModel {
  const PlanModel({
    required this.name,
    required this.price,
    required this.description,
    required this.badge,
    required this.features,
  });
  final String       name;
  final String       price;
  final String       description;
  final String       badge;
  final List<String> features;

  factory PlanModel.fromJson(Map<String, dynamic> j) => PlanModel(
        name:        j['name']        as String? ?? '',
        price:       j['price']       as String? ?? '',
        description: j['description'] as String? ?? '',
        badge:       j['badge']       as String? ?? '',
        features:    List<String>.from(j['features'] as List? ?? []),
      );
}

// ── User Profile ───────────────────────────────────────────────────────────
class UserProfile {
  const UserProfile({required this.email, required this.plan});
  final String email;
  final String plan;

  bool get isPremium => plan.toLowerCase() != 'free';

  factory UserProfile.fromJson(Map<String, dynamic> j) =>
      UserProfile(email: j['email'] as String? ?? '', plan: j['plan'] as String? ?? 'Free');
  Map<String, dynamic> toJson() => {'email': email, 'plan': plan};
}

// ── Catalog ────────────────────────────────────────────────────────────────
class CatalogModel {
  const CatalogModel({
    required this.channels,
    required this.categories,
    required this.banners,
    required this.plans,
  });
  final List<ChannelModel>  channels;
  final List<CategoryModel> categories;
  final List<BannerModel>   banners;
  final List<PlanModel>     plans;

  factory CatalogModel.fromJson(Map<String, dynamic> j) => CatalogModel(
        channels:   _parse(j['channels'],   ChannelModel.fromJson),
        categories: _parse(j['categories'], CategoryModel.fromJson),
        banners:    _parse(j['banners'],    BannerModel.fromJson),
        plans:      _parse(j['plans'],      PlanModel.fromJson),
      );

  static List<T> _parse<T>(dynamic raw, T Function(Map<String, dynamic>) fn) =>
      (raw as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(fn)
          .toList();
}
