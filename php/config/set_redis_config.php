<?php

$env_file = 'app/etc/env.php';

if (is_file($env_file)) {
    $config = include $env_file;
    if (isset($_ENV["DEFAULT_CACHE_REDIS_SERVER"])) {
        $default_cache = array(
            'cache' => array(
                'frontend' => array(
                    'default' => array(
                        'backend' => 'Cm_Cache_Backend_Redis',
                        'backend_options' => array(
                            'server' => $_ENV["DEFAULT_CACHE_REDIS_SERVER"],
                            'database' => $_ENV["DEFAULT_CACHE_REDIS_DATABASE"] ?? '0',
                            'port' => $_ENV["DEFAULT_CACHE_REDIS_PORT"] ?? '6379'
                        )
                    )
                )
            )
        );
        $config = array_replace_recursive($config, $default_cache);
    }
    if (isset($_ENV["PAGE_CACHE_REDIS_SERVER"])) {
        $page_cache = array(
            'cache' => array(
                'frontend' => array(
                    'page_cache' => array(
                        'backend' => 'Cm_Cache_Backend_Redis',
                        'backend_options' => array(
                            'server' => $_ENV["PAGE_CACHE_REDIS_SERVER"],
                            'port' => $_ENV["PAGE_CACHE_REDIS_PORT"] ?? '6379',
                            'database' => $_ENV["PAGE_CACHE_REDIS_DATABASE"] ?? '1',
                            'compress_data' => $_ENV["PAGE_CACHE_REDIS_COMPRESS"] ?? '0'
                        )
                    )
                )
            )
        );
        $config = array_replace_recursive($config, $page_cache);
    }
    if (isset($_ENV["SESSION_REDIS_SERVER"])) {
        $session = array(
            'session' => array (
                'save' => 'redis',
                'redis' => array (
                    'host' => $_ENV["SESSION_REDIS_SERVER"],
                    'port' => $_ENV["SESSION_REDIS_PORT"] ?? '6379',
                    'password' => $_ENV["SESSION_REDIS_PASSWORD"] ?? '',
                    'timeout' => $_ENV["SESSION_REDIS_TIMEOUT"] ?? '2.5',
                    'persistent_identifier' => $_ENV["SESSION_REDIS_PERSISTENT_IDENTIFIER"] ?? '',
                    'database' => $_ENV["SESSION_REDIS_DATABASE"] ?? '2',
                    'compression_threshold' => $_ENV["SESSION_REDIS_COMPRESSION_THRESHOLD"] ?? '2048',
                    'compression_library' => $_ENV["SESSION_REDIS_COMPRESSION_LIBRARY"] ?? 'gzip',
                    'log_level' => $_ENV["SESSION_REDIS_LOG_LEVEL"] ?? '1',
                    'max_concurrency' => $_ENV["SESSION_REDIS_MAX_CONCURRENCY"] ?? '6',
                    'break_after_frontend' => $_ENV["SESSION_REDIS_BREAK_AFTER_FRONTEND"] ?? '5',
                    'break_after_adminhtml' => $_ENV["SESSION_REDIS_BREAK_AFTER_ADMINHTML"] ?? '30',
                    'first_lifetime' => $_ENV["SESSION_REDIS_FIRST_LIFETIME"] ?? '600',
                    'bot_first_lifetime' => $_ENV["SESSION_REDIS_BOT_FIRST_LIFETIME"] ?? '60',
                    'bot_lifetime' => $_ENV["SESSION_REDIS_BOT_LIFETIME"] ?? '7200',
                    'disable_locking' => $_ENV["SESSION_REDIS_DISABLE_LOCKING"] ?? '0',
                    'min_lifetime' => $_ENV["SESSION_REDIS_MIN_LIFETIME"] ?? '60',
                    'max_lifetime' => $_ENV["SESSION_REDIS_MAX_LIFETIME"] ?? '2592000'
                )
            )
        );
        $config = array_replace_recursive($config, $session);
    }
    $config_string = '<?php return ' . var_export($config, true) . ';';
    file_put_contents($env_file, $config_string);
}
