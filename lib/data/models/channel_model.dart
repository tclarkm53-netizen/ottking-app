class ChannelModel {
  final String id;
  final String name;
  final String category;
  final String streamUrl;
  final String logoUrl;
  final String description;
  final String quality;

  const ChannelModel({
    required this.id,
    required this.name,
    required this.category,
    required this.streamUrl,
    required this.logoUrl,
    required this.description,
    required this.quality,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      streamUrl: json['streamUrl'] as String,
      logoUrl: json['logoUrl'] as String,
      description: json['description'] as String,
      quality: json['quality'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'streamUrl': streamUrl,
      'logoUrl': logoUrl,
      'description': description,
      'quality': quality,
    };
  }
}

class CategoryModel {
  const CategoryModel({required this.name, required this.icon});

  final String name;
  final String icon;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      name: json['name'] as String,
      icon: json['icon'] as String,
    );
  }
}

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

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      imageUrl: json['imageUrl'] as String,
      channelId: json['channelId'] as String,
    );
  }
}

class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.name,
    required this.price,
    required this.description,
    required this.badge,
    required this.features,
  });

  final String name;
  final String price;
  final String description;
  final String badge;
  final List<String> features;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      name: json['name'] as String,
      price: json['price'] as String,
      description: json['description'] as String,
      badge: json['badge'] as String,
      features: List<String>.from(json['features'] as List<dynamic>),
    );
  }
}

class UserProfileModel {
  const UserProfileModel({required this.email, required this.plan});

  final String email;
  final String plan;

  Map<String, dynamic> toJson() => {'email': email, 'plan': plan};

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      email: json['email'] as String,
      plan: json['plan'] as String,
    );
  }
}

class ChannelCatalogModel {
  const ChannelCatalogModel({
    required this.channels,
    required this.categories,
    required this.banners,
    required this.plans,
  });

  final List<ChannelModel> channels;
  final List<CategoryModel> categories;
  final List<BannerModel> banners;
  final List<SubscriptionPlanModel> plans;

  factory ChannelCatalogModel.fromJson(Map<String, dynamic> json) {
    return ChannelCatalogModel(
      channels: (json['channels'] as List<dynamic>)
          .map((item) => ChannelModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>)
          .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      banners: (json['banners'] as List<dynamic>)
          .map((item) => BannerModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      plans: (json['plans'] as List<dynamic>)
          .map((item) => SubscriptionPlanModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
