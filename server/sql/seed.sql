USE ottking_app;

INSERT INTO categories (name, icon, sort_order)
VALUES
    ('Sports', '🏈', 1),
    ('News', '📰', 2),
    ('Movies', '🎬', 3)
ON DUPLICATE KEY UPDATE icon = VALUES(icon), sort_order = VALUES(sort_order);

INSERT INTO channels (id, name, category_id, stream_url, logo_url, description, quality, sort_order)
VALUES
    ('ch-001', 'Sports Arena', 1, 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8', 'https://cdn.example.com/logos/sports-arena.png', 'Live sports and highlights in HD', 'HD', 1),
    ('ch-002', 'News Live', 2, 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8', 'https://cdn.example.com/logos/news-live.png', '24/7 breaking news coverage', 'HD', 2),
    ('ch-003', 'Cinema Prime', 3, 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8', 'https://cdn.example.com/logos/cinema-prime.png', 'Premium movie channel for your home screen', '4K', 3)
ON DUPLICATE KEY UPDATE name = VALUES(name), category_id = VALUES(category_id), stream_url = VALUES(stream_url), logo_url = VALUES(logo_url), description = VALUES(description), quality = VALUES(quality), sort_order = VALUES(sort_order);

INSERT INTO banners (title, subtitle, image_url, channel_id, sort_order)
VALUES
    ('Secure Live TV', 'Smart TV and mobile unified experience', 'https://cdn.example.com/banners/hero-1.jpg', 'ch-001', 1),
    ('Premium Channel Lineup', 'Fortified APIs with HMAC-protected responses', 'https://cdn.example.com/banners/hero-2.jpg', 'ch-003', 2)
ON DUPLICATE KEY UPDATE subtitle = VALUES(subtitle), image_url = VALUES(image_url), channel_id = VALUES(channel_id), sort_order = VALUES(sort_order);

INSERT INTO plans (name, price, description, badge, sort_order)
VALUES
    ('Free', '$0', 'Basic access with limited channels', 'Starter', 1),
    ('Premium', '$9.99', 'Full HD, smart TV boot, and cloud sync', 'Recommended', 2)
ON DUPLICATE KEY UPDATE price = VALUES(price), description = VALUES(description), badge = VALUES(badge), sort_order = VALUES(sort_order);

INSERT INTO plan_features (plan_id, feature, sort_order)
SELECT id, '1 device', 1 FROM plans WHERE name = 'Free'
ON DUPLICATE KEY UPDATE feature = VALUES(feature), sort_order = VALUES(sort_order);

INSERT INTO plan_features (plan_id, feature, sort_order)
SELECT id, 'standard quality', 2 FROM plans WHERE name = 'Free'
ON DUPLICATE KEY UPDATE feature = VALUES(feature), sort_order = VALUES(sort_order);

INSERT INTO plan_features (plan_id, feature, sort_order)
SELECT id, 'Multi-device access', 1 FROM plans WHERE name = 'Premium'
ON DUPLICATE KEY UPDATE feature = VALUES(feature), sort_order = VALUES(sort_order);

INSERT INTO plan_features (plan_id, feature, sort_order)
SELECT id, '4K streams', 2 FROM plans WHERE name = 'Premium'
ON DUPLICATE KEY UPDATE feature = VALUES(feature), sort_order = VALUES(sort_order);

INSERT INTO plan_features (plan_id, feature, sort_order)
SELECT id, 'priority support', 3 FROM plans WHERE name = 'Premium'
ON DUPLICATE KEY UPDATE feature = VALUES(feature), sort_order = VALUES(sort_order);
