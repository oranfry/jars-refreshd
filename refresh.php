<?php

use jars\Jars;

const EXPECT = ['PORTAL_HOME', 'DB_HOME', 'AUTH_TOKEN', 'BIN_HOME'];

$command = array_shift($argv);
$confname = @array_shift($argv);
$found = [];

foreach (EXPECT as $i => $option) {
    if ($value = @$_SERVER[$option]) {
        define($option, $value);
        $found[] = $option;
    }
}

if (count(EXPECT) > count($found) && file_exists($config_file = 'global.conf')) {
    load_conf_file($config_file, $found);
}

if (count(EXPECT) > count($found)) {
    if (!$confname) {
        error_log('Please specify config name as first argument or specify all config options in environment variables or global config');
        die(1);
    }

    if (!file_exists($config_file = 'conf.d/' . $confname . '.conf')) {
        error_log('Config file missing for portal "' . $confname . '" (' . $config_file . ')');
        die(1);
    }

    load_conf_file($config_file, $found);
}

if (count($missing = array_filter(EXPECT, fn ($option) => !in_array($option, $found)))) {
    error_log('Missing config options: ' . implode(', ', $missing));
    die(1);
}

$jars = Jars::of(PORTAL_HOME, DB_HOME);
$jars->token(AUTH_TOKEN);
$jars->refresh();

function load_conf_file($config_file, &$found)
{
    foreach (explode("\n", file_get_contents($config_file)) as $i => $line) {
        if (preg_match('/^\s*([A-Z_]+)\s*=(.*)/', $line, $matches)) {
            if (!in_array($option = $matches[1], EXPECT)) {
                error_log('Unrecognised config option in [' . $config_file . ']: ' . $option);
                die(1);
            }

            $found[] = $option;

            define($option, trim($matches[2]));
        } elseif (!preg_match('/^\s*(#.*)?$/', $line, $matches)) {
            error_log('Invalid config line in [' . $config_file . '] on line [' . $i . ']');
            die(1);
        }
    }
}
