#!/usr/bin/php
<?php

use jars\Jars;

require __DIR__ . '/vendor/autoload.php';
require __DIR__ . '/vendor/oranfry/subsimple/src/php/script/lib.php';
require __DIR__ . '/lib.php';

$command = array_shift($argv);
$confname = @array_shift($argv);

if (!$confname) {
    error_log('Please specify config name as first argument');
    die(1);
}

if (!file_exists($config_file = __DIR__ . '/conf.d/' . $confname . '.conf')) {
    error_log('Config file missing for portal "' . $confname . '" (' . $config_file . ')');
    die(1);
}

$expect = ['PORTAL_HOME', 'DB_HOME', 'AUTH_TOKEN'];
$found = [];

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

if (count($missing = array_filter($expect, fn ($option) => !in_array($option, $found)))) {
    error_log('Missing config options: ' . implode(', ', $missing));
    die(1);
}

require PORTAL_HOME . '/vendor/autoload.php';

$jars = Jars::of(PORTAL_HOME, DB_HOME);
$jars->token(AUTH_TOKEN);

const REPORTS_DIR = DB_HOME . '/reports';
const LINES_DIR = REPORTS_DIR . '/.refreshd/lines';

if (!is_dir(LINES_DIR)) {
    mkdir(LINES_DIR, 0777, true);
}

$bunny = file_get_contents(DB_HOME . "/version.dat");
$bunny_number = (int) file_get_contents(DB_HOME . '/versions/' . $bunny);

$greyhound = null;
$greyhound_number = 0;

if (file_exists($greyhound_file = REPORTS_DIR . "/version.dat")) {
    $greyhound = file_get_contents($greyhound_file);
    $greyhound_number = (int) file_get_contents(DB_HOME . '/versions/' . $greyhound);
}

if ($bunny == $greyhound) {
    // echo $greyhound . "\n";
    return ['version' => $greyhound];
}

if ($bunny_number > $greyhound_number) {
    $from = $greyhound_number + 1;
    $direction = 'forward';
    $sorter = 'identity';
} else {
    $from = $bunny_number + 1;
    $direction = 'back';
    $sorter = 'array_reverse';
}

$length = abs($bunny_number - $greyhound_number);
$master_meta_file = DB_HOME . '/master.dat.meta';
$metas = $sorter(explode("\n", trim(`cat '$master_meta_file' | tail -n +$from | head -n $length | cut -c66- | sed 's/ /\\n/g'`)));
$changes = [];

foreach ($metas as $meta) {
    if (!preg_match('/^([+-~])([a-z]+):([A-Z0-9]+)$/', $meta, $matches)) {
        error_response('Invalid meta line: ' . $meta);
    }

    list(, $sign, $type, $id) = $matches;

    if (!isset($changes[$id])) {
        $changes[$id] = (object) [
            'type' => $type,
        ];
    }

    $changes[$id]->sign = $sign;
}

$lines = [];
$childsets = [];

// propagate

if ($greyhound) {
    foreach ($changes as $id => $change) {
        propagate_r($jars, $change->type, $id, $greyhound, $changes);
    }
}

foreach (array_keys($jars->config()->reports) as $report_name) {
    $report = $jars->report($report_name);

    foreach ($changes as $id => $change) {
        foreach ($report->listen as $linetype => $listen) {
            if (is_numeric($linetype)) {
                $linetype = $listen;
                $listen = (object) [];
            }

            $table = $jars->linetype($linetype)->table;

            if ($change->type != $table) {
                continue;
            }

            $current_groups = [];
            $past_groups = [];

            if (in_array($change->sign, ['+', '~', '*'])) {
                if (!isset($lines[$linetype])) {
                    $lines[$linetype] = [];
                }

                $linetype_lines = &$lines[$linetype];

                if (!isset($linetype_lines[$id])) {
                    $linetype_lines[$id] = $jars->get($linetype, $id);
                }

                $line = clone $lines[$linetype][$id];

                load_children_r($jars, $line, @$listen->children ?? [], $childsets);

                if (property_exists($listen, 'classify')) {
                    $current_groups = classifier_value($listen->classify, $line);
                } elseif (property_exists($report, 'classify')) {
                    $current_groups = classifier_value($report->classify, $line);
                } elseif (property_exists($line, '_groups') && is_string($line->_group)) {
                    $current_groups = explode(',', $line->_groups);
                } else {
                    $current_groups = ['all'];
                }
            }

            $groups_file = LINES_DIR . '/' . $report_name . '/' . $id . '.json';

            if (!is_dir(dirname($groups_file))) {
                mkdir(dirname($groups_file));
            }

            if (in_array($change->sign, ['-', '~', '*'])) {
                $past_groups = file_exists($groups_file) ? json_decode(file_get_contents($groups_file))->groups : [];
            }

            // remove

            if (!is_array($current_groups)) {
                error_response($current_groups);
            }

            foreach (array_diff($past_groups, $current_groups) as $group) {
                $report->delete($group, $id);
            }

            // upsert

            foreach ($current_groups as $group) {
                $report->upsert($group, $line, @$report->sorter);
            }

            if ($current_groups) {
                file_put_contents($groups_file, json_encode(['groups' => $current_groups]));
            } elseif (file_exists($groups_file)) {
                unlink($groups_file);
            }
        }
    }
}

$past_dir = DB_HOME . '/past';

`rm -rf "$past_dir"`;

file_put_contents($greyhound_file, $bunny); // the greyhound has caught the bunny!

// echo $bunny . "\n";
return ['version' => $bunny];
