<?php

use jars\Jars;
use jars\Link;

function classifier_value($classify, $line) {
    if (is_array($classify)) {
        return $classify;
    }

    if (is_string($classify)) {
        return [$classify];
    }

    if (is_callable($classify)) {
        $groups = ($classify)($line);

        if (!is_array($groups) || array_filter($groups, function ($group) { return !is_string($group) || !$group; })) {
            error_response('Invalid classication result');
        }

        return $groups;
    }

    error_response('Invalid classifier');
}

function load_children_r(object $jars, object $line, array $children, array &$childsets)
{
    foreach ($children as $property => $child) {
        if (is_numeric($property)) {
            $property = $child;
            $child = (object) [];
        }

        if (!isset($childsets[$line->type])) {
            $childsets[$line->type] = [];
        }

        $linetype_childsets = &$childsets[$line->type];

        if (!isset($linetype_childsets[$line->id])) {
            $linetype_childsets[$line->id] = [];
        }

        $line_childsets = &$linetype_childsets[$line->id];

        if (!isset($line_childsets[$property])) {
            $line_childsets[$property] = $jars->get_childset($line->type, $line->id, $property);
        }

        $childset = $line_childsets[$property];

        if (property_exists($child, 'filter')) {
            if (!is_callable($child->filter)) {
                error_response('Invalid filter');
            }

            $childset = array_filter($childset, $child->filter);
        }

        if (property_exists($child, 'sorter')) {
            if (!is_callable($child->sorter)) {
                error_response('Invalid sorter');
            }

            usort($childset, $child->sorter);
        }

        $line->$property = $childset;

        if (property_exists($child, 'children')) {
            if (!is_array($child->children)) {
                error_response('Invalid children');
            }

            foreach ($childset as $childline) {
                load_children_r($jars, $childline, $child->children, $childsets);
            }
        }
    }
}

function propagate_r(Jars $jars, string $linetype, string $id, string $version, array &$changes = [], array &$seen = [])
{
    $linetype = $jars->linetype($linetype);

    $relatives = array_merge(
        $linetype->find_incoming_links(),
        $linetype->find_incoming_inlines(),
    );

    foreach ($relatives as $relative) {
        $links = [
            Link::of($jars, $relative->tablelink, $id, !@$relative->reverse, $version),
            Link::of($jars, $relative->tablelink, $id, !@$relative->reverse)
        ];

        foreach ($links as $link) {
            foreach ($link->relatives() as $relative_id) {
                $table = $jars->linetype($relative->parent_linetype)->table;

                $change = (object) [
                    'type' => $table,
                    'sign' => '*',
                ];

                if (!isset($changes[$relative_id])) {
                    $changes[$relative_id] = $change;
                }

                if (!isset($seen[$key = $relative->parent_linetype . ':' . $relative_id])) {
                    $seen[$key] = true;

                    propagate_r($jars, $relative->parent_linetype, $relative_id, $version, $changes, $seen);
                }
            }
        }
    }
}

function identity($value)
{
    return $value;
}
