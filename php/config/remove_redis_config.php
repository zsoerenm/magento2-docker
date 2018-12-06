<?php

$env_file = 'app/etc/env.php';

if (is_file($env_file)) {
    $config = include $env_file;

    if (isset($config['cache']))
        unset($config['cache']);

    if (isset($config['session']) && isset($config['session']['save']) && $config['session']['save'] == 'redis')
        unset($config['session']);

    $config_string = '<?php return ' . var_export($config, true) . ';';
    file_put_contents($env_file, $config_string);
}
