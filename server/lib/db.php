<?php

declare(strict_types=1);

require_once __DIR__ . '/../config.php';

function db_connect(): mysqli
{
    if (!extension_loaded('mysqli')) {
        throw new RuntimeException('mysqli extension is required for this backend');
    }

    $connection = mysqli_connect(DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT);
    if ($connection === false) {
        throw new RuntimeException('Failed to connect to database: ' . mysqli_connect_error());
    }

    if (!mysqli_set_charset($connection, 'utf8mb4')) {
        throw new RuntimeException('Failed to set database charset');
    }

    return $connection;
}

function db_close(mysqli $connection): void
{
    mysqli_close($connection);
}

function db_query(mysqli $connection, string $sql, string $types = '', ...$params): mysqli_result
{
    $stmt = mysqli_prepare($connection, $sql);
    if ($stmt === false) {
        throw new RuntimeException('Failed to prepare statement: ' . mysqli_error($connection));
    }

    if ($types !== '') {
        mysqli_stmt_bind_param($stmt, $types, ...$params);
    }

    if (!mysqli_stmt_execute($stmt)) {
        mysqli_stmt_close($stmt);
        throw new RuntimeException('Failed to execute query: ' . mysqli_stmt_error($stmt));
    }

    $result = mysqli_stmt_get_result($stmt);
    if ($result === false && $sql !== '' && strtoupper(substr(trim($sql), 0, 6)) !== 'SELECT') {
        mysqli_stmt_close($stmt);
        return new mysqli_result();
    }

    if ($result === false) {
        mysqli_stmt_close($stmt);
        throw new RuntimeException('Failed to fetch result: ' . mysqli_stmt_error($stmt));
    }

    mysqli_stmt_close($stmt);

    return $result;
}
