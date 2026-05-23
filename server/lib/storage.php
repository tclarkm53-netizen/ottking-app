<?php

declare(strict_types=1);

require_once __DIR__ . '/db.php';

function fetch_catalog(): array
{
    $connection = db_connect();

    try {
        $categoriesResult = db_query(
            $connection,
            'SELECT id, name, icon FROM categories WHERE is_active = 1 ORDER BY sort_order, name'
        );
        $categories = [];
        while ($row = mysqli_fetch_assoc($categoriesResult)) {
            $categories[] = [
                'name' => $row['name'],
                'icon' => $row['icon'],
            ];
        }

        $channelsResult = db_query(
            $connection,
            'SELECT c.id, c.name, cat.name AS category, c.stream_url, c.logo_url, c.description, c.quality
             FROM channels c
             INNER JOIN categories cat ON cat.id = c.category_id
             WHERE c.is_active = 1
             ORDER BY c.sort_order, c.name'
        );
        $channels = [];
        while ($row = mysqli_fetch_assoc($channelsResult)) {
            $channels[] = [
                'id' => $row['id'],
                'name' => $row['name'],
                'category' => $row['category'],
                'streamUrl' => $row['stream_url'],
                'logoUrl' => $row['logo_url'],
                'description' => $row['description'],
                'quality' => $row['quality'],
            ];
        }

        $bannersResult = db_query(
            $connection,
            'SELECT title, subtitle, image_url, channel_id FROM banners WHERE is_active = 1 ORDER BY sort_order, title'
        );
        $banners = [];
        while ($row = mysqli_fetch_assoc($bannersResult)) {
            $banners[] = [
                'title' => $row['title'],
                'subtitle' => $row['subtitle'],
                'imageUrl' => $row['image_url'],
                'channelId' => $row['channel_id'],
            ];
        }

        $plansResult = db_query(
            $connection,
            'SELECT id, name, price, description, badge FROM plans WHERE is_active = 1 ORDER BY sort_order'
        );
        $plans = [];
        while ($row = mysqli_fetch_assoc($plansResult)) {
            $plans[] = [
                'id' => (int) $row['id'],
                'name' => $row['name'],
                'price' => $row['price'],
                'description' => $row['description'],
                'badge' => $row['badge'],
                'features' => [],
            ];
        }

        $featuresResult = db_query(
            $connection,
            'SELECT plan_id, feature FROM plan_features ORDER BY plan_id, sort_order'
        );
        $featureMap = [];
        while ($row = mysqli_fetch_assoc($featuresResult)) {
            $featureMap[(int) $row['plan_id']][] = $row['feature'];
        }

        foreach ($plans as &$plan) {
            $plan['features'] = $featureMap[(int) $plan['id']] ?? [];
            unset($plan['id']);
        }
        unset($plan);

        return [
            'channels' => $channels,
            'categories' => $categories,
            'banners' => $banners,
            'plans' => $plans,
        ];
    } finally {
        db_close($connection);
    }
}

function find_user_by_email(string $email): ?array
{
    $connection = db_connect();

    try {
        $result = db_query(
            $connection,
            'SELECT id, email, password_hash, plan FROM users WHERE email = ? LIMIT 1',
            's',
            strtolower(trim($email))
        );
        $user = mysqli_fetch_assoc($result);

        return $user === null ? null : $user;
    } finally {
        db_close($connection);
    }
}

function register_user(string $email, string $password): array
{
    $email = strtolower(trim($email));
    $connection = db_connect();

    try {
        $existing = find_user_by_email($email);
        if ($existing !== null) {
            throw new InvalidArgumentException('Email already registered');
        }

        $passwordHash = password_hash($password, PASSWORD_BCRYPT);

        db_query(
            $connection,
            'INSERT INTO users (email, password_hash, plan, created_at) VALUES (?, ?, ?, NOW())',
            'sss',
            $email,
            $passwordHash,
            'Premium'
        );

        return [
            'email' => $email,
            'plan' => 'Premium',
            'token' => bin2hex(random_bytes(24)),
        ];
    } finally {
        db_close($connection);
    }
}

function authenticate_user(string $email, string $password): array
{
    $user = find_user_by_email(strtolower(trim($email)));
    if ($user === null || !password_verify($password, $user['password_hash'] ?? '')) {
        throw new InvalidArgumentException('Invalid credentials');
    }

    return [
        'email' => $user['email'],
        'plan' => $user['plan'] ?? 'Premium',
        'token' => bin2hex(random_bytes(24)),
    ];
}
