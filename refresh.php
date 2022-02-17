#!/usr/bin/php
<?php

use jars\Jars;

require __DIR__ . '/vendor/autoload.php';

$command = array_shift($argv);
$confname = @array_shift($argv);
$expect = ['PORTAL_HOME', 'DB_HOME', 'AUTH_TOKEN'];
$found = [];

foreach ($expect as $i => $option) {
    if ($value = @$_SERVER[$option]) {
        define($option, $value);
        $found[] = $option;
    }
}

if (count($expect) > count($found)) {
    if (!$confname) {
        error_log('Please specify config name as first argument or specify all config options in environment variables');
        die(1);
    }

    if (!file_exists($config_file = __DIR__ . '/conf.d/' . $confname . '.conf')) {
        error_log('Config file missing for portal "' . $confname . '" (' . $config_file . ')');
        die(1);
    }

    foreach (explode("\n", file_get_contents($config_file)) as $i => $line) {
        if (preg_match('/^\s*([A-Z_]+)\s*=(.*)/', $line, $matches)) {
            if (!in_array($option = $matches[1], $expect)) {
                error_log('Unrecognised option in config: ' . $option);
                die(1);
            }

            $found[] = $option;

            define($option, trim($matches[2]));
        } elseif (!preg_match('/^\s*(#.*)?$/', $line, $matches)) {
            error_log('Invalid config on line ' . $i);
            die(1);
        }
    }
}

if (count($missing = array_filter($expect, fn ($option) => !in_array($option, $found)))) {
    error_log('Missing config options: ' . implode(', ', $missing));
    die(1);
}

$jars = Jars::of(PORTAL_HOME, DB_HOME);
$jars->token(AUTH_TOKEN);
$jars->refresh();
