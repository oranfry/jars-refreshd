<?php

use jars\contract\JarsConnector;

const REQUIRED = ['CONNECTION_STRING', 'AUTH_TOKEN', 'BIN_HOME'];
const OPTIONAL = ['PORTAL_AUTOLOAD'];

$command = array_shift($argv);

$etc = '/etc';
$etc_arg = null;

foreach ($argv as $i => $value) {
    if (preg_match('/^--etc-dir=(.*)/', $value, $matches)) {
        $etc = $matches[1];
        $etc_arg = ' ' . $value;
        unset($argv[$i]);
    }
}

$confname = @array_shift($argv);
$config = [];

if ($confname) {
    $command = __DIR__ . '/read-portal.php' . $etc_arg . ' ' . $confname;

    $config += load_conf(`$command` ?? '');
    $config += load_conf_file('refresh/conf.d/' . $confname . '.conf');
}

$config += load_conf_file('refresh/global.conf');

foreach (array_merge(REQUIRED, OPTIONAL) as $i => $option) {
    if ($value = $_SERVER[$option] ?? null) {
        $config[$option] = $value;
    }
}

$missing = array_filter(REQUIRED, fn ($option) => !array_key_exists($option, $config));

if (count($missing)) {
    error_log('Missing config options: ' . implode(', ', $missing));
    die(1);
}

if ($autoload = $config['PORTAL_AUTOLOAD'] ?? null) {
    require $autoload;
}

$jars = JarsConnector::connect($config['CONNECTION_STRING']);
$jars->token($config['AUTH_TOKEN']);
$jars->refresh();

function load_conf_file(string $config_file): array
{
    // echo $config_file . '? ' . (is_file($config_file) ? 'Yes' : 'No') . "\n";

    if (!is_file($config_file)) {
        return [];
    }

    return load_conf(file_get_contents($config_file));
}

function load_conf(string $raw_config): array
{
    $loaded = [];

    foreach (explode("\n", $raw_config) as $i => $line) {
        if (preg_match('/^\s*([A-Z_]+)\s*=(.*)/', $line, $matches)) {
            if (!in_array($option = $matches[1], array_merge(REQUIRED, OPTIONAL))) {
                error_log('Unrecognised config option: ' . $option);
                die(1);
            }

            $loaded[$option] = trim($matches[2]);
            // echo '>> ' . $option . ' = ' . $loaded[$option] . "\n";
        } elseif (!preg_match('/^\s*(?:#.*)?$/', $line)) {
            error_log('Invalid config line in [' . $config_file . '] on line [' . $i . ']');
            die(1);
        }
    }

    return $loaded;
}
