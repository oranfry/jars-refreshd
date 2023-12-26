#!/usr/bin/env php
<?php

$command = array_shift($argv);

$etc = '/etc';

foreach ($argv as $i => $value) {
    if (preg_match('/^--etc-dir=(.*)/', $value, $matches)) {
        $etc = $matches[1];
        unset($argv[$i]);
    }
}

$confname = @array_shift($argv);

if (
    is_file($file = $etc . '/' . $confname . '.json')
    && $config = json_decode(file_get_contents($file))
) {
    if (isset($config->autoload)) {
        echo 'PORTAL_AUTOLOAD=' . $config->autoload . "\n";
    }

    if (isset($config->connection_string)) {
        echo 'CONNECTION_STRING=' . $config->connection_string . "\n";
    }
}
