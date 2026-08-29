<?php

/**
 * @file
 * Phase C helper: derive recipe config/ files from the live chrisferagotti.com
 * config export.
 *
 *   lando drush php:script /app/recipes/trend_personal/_build/strip_bucket.php
 *
 * Reads:
 *   C = /app/config/sync/default/*.yml   (chrisferagotti.com full config)
 *   B = /app/config/baseline/*.yml       (bare-base defaults = this recipe minus config/)
 *
 * Model (recipe installs modules with config-entity install DISABLED, so):
 *   - config that exists in B (module simple config): ship ONLY as a config.action
 *     if it differs from B; otherwise leave it (report -> report.actions.todo.yml).
 *   - config NOT in B (config entities + core-created): ship bundled in config/,
 *     stripped of uuid/_core, routed to base or an add-on.
 *   - skip site-specific / secret / excluded-feature config entirely.
 */

use Drupal\Component\Serialization\Yaml;

$ROOT   = '/app';
$C_DIR  = "$ROOT/config/sync/default";
$B_DIR  = "$ROOT/config/baseline";
$RECIPE = "$ROOT/recipes/trend_personal";
$BUILD  = "$RECIPE/_build";
@mkdir($BUILD, 0777, TRUE);

// Core modules that are always present in any install.
$CORE_ALWAYS = array_flip([
  'system','user','node','field','text','filter','path','path_alias','options',
  'datetime','datetime_range','link','image','file','views','user','taxonomy',
  'menu_link_content','menu_ui','block','block_content','editor','ckeditor5',
  'comment','contextual','help','history','toolbar','update','breakpoint',
  'responsive_image','media','media_library','layout_builder','layout_discovery',
  'workflows','content_moderation','serialization','telephone','big_pipe',
  'page_cache','dynamic_page_cache','automated_cron','dblog','basic_auth',
  'inline_form_errors','field_ui','views_ui','book','config',
]);
// Add-on modules (installed by an add-on recipe, so their config may be routed there).
$ADDON_DEPS = array_flip([
  'ut_recipe','physical','address','geofield','geocoder','geocoder_field',
  'geocoder_address','geocoder_geofield','geolocation','geolocation_geofield',
  'geolocation_address','geolocation_google_maps','geolocation_google_static_maps',
  'geolocation_leaflet','geolocation_geometry','geolocation_geometry_data',
  'leaflet','leaflet_more_maps','leaflet_more_markers','leaflet_markercluster',
  'leaflet_views','smart_date','smart_date_calendar_kit','smart_date_starter_kit',
  'fullcalendar_view','auto_entitylabel','search_api_location',
  'search_api_location_geocoder','search_api_location_views','facets_map_widget',
]);

// ---- SKIP ----
$SKIP_EXACT = array_flip([
  'core.extension','system.site','update.settings','system.file',
  'search_api.server.solr','search_api.index.content',
  'environment_indicator.indicator','environment_indicator.settings',
  'social_auth.settings','social_auth_google.settings','recaptcha.settings',
  'honeypot.settings','system.performance','system.logging',
  // modules not in the base install list
  'dashboard.dashboard.default','ajax_comments.settings',
]);
// Config that IS shipped but with a secret scrubbed to empty.
$SCRUB_SECRET = [
  'geocoder.geocoder_provider.googlemaps' => ['configuration', 'apiKey'],
];
$SKIP_PREFIX = [
  'config_split.config_split.','environment_indicator.switcher.',
  'metatag.metatag_defaults.','ai.','ai_','language.','locale.',
  'search_api_solr.','geolocation_google_maps.','geolocation_google_static_maps.',
  'geolocation_leaflet.',
];
$SKIP_CONTAINS = [
  'strava','robinhood','race_day','race_team','race_leg','race_admin','race_map',
  'race_teams','ut_tracking','ut_robinhood','cove','data_visualization',
  'gps_location','gps_device','private_message','feeds','automator','.race.',
  'field_race','pattern.races','field_message_pm','field_message_private',
  'message.template.private','message.private_message','location_access',
  'node_book_form','book.settings','views.view.test',
];
$SKIP_VIEWS = array_flip([
  'views.view.ai_logs','views.view.social_auth_profiles','views.view.symfony_mailer_log',
  'views.view.feeds_feed','views.view.message','views.view.blog',
  'views.view.webform_submissions','views.view.dashboard_content','views.view.test',
  'views.view.races','views.view.race_leg','views.view.race_leg_admin',
  'views.view.race_leg_map','views.view.race_map','views.view.race_admin',
]);
// Theme block placements: keep only these themes' blocks; drop the rest.
$KEEP_BLOCK_THEMES = ['gin','claro','ut_material','ut_base'];

// Simple-config overrides that are just noise (leave as the module default).
$OVERRIDE_IGNORE_PREFIX = ['core.entity_view_mode.'];
$OVERRIDE_IGNORE = array_flip([
  'core.menu.static_menu_link_overrides','filter.format.webform_default',
  'material_base.settings','material_base_mdc.settings',
]);

// ---- ADD-ON ROUTING ----
$ADDON_RULES = [
  ['~(^|\.)node\.type\.recipe$~','trend_recipe'],
  ['~\.node\.recipe\.~','trend_recipe'],
  ['~taxonomy\.vocabulary\.(food_tags|ingredients|ingredient_denominations)$~','trend_recipe'],
  ['~\.paragraph\.(ingredient|precise_datetime)\.~','trend_recipe'],
  ['~paragraphs\.paragraphs_type\.(ingredient|precise_datetime)$~','trend_recipe'],
  ['~\.paragraph\.field_(denomination|ingredient|note|number|volume|weight|precise_date|precise_time)$~','trend_recipe'],
  ['~\.node\.field_(cook_time|prep_time|servings|directions|ingredients)$~','trend_recipe'],
  ['~views\.view\.recipes$~','trend_recipe'],
  ['~pathauto\.pattern\.recipes$~','trend_recipe'],

  ['~(^|\.)node\.type\.place$~','trend_place'],
  ['~\.node\.place\.~','trend_place'],
  ['~taxonomy\.vocabulary\.location_type$~','trend_place'],
  ['~\.taxonomy_term\.location_type\.~','trend_place'],
  ['~\.taxonomy_term\.field_(map_marker|geometry_data_geometry)$~','trend_place'],
  ['~\.node\.field_(address|geolocation_coordinates|location_type)$~','trend_place'],
  ['~pathauto\.pattern\.places$~','trend_place'],
  ['~^geocoder\.~','trend_place'],

  ['~(^|\.)node\.type\.event$~','trend_event'],
  ['~\.node\.event\.~','trend_event'],
  ['~\.node\.field_(when|where)$~','trend_event'],
  ['~views\.view\.events(_calendar)?$~','trend_event'],
  ['~pathauto\.pattern\.events$~','trend_event'],
  ['~^smart_date\.smart_date_format\.~','trend_event'],

  ['~(^|\.)node\.type\.issue$~','trend_issue'],
  ['~\.node\.issue\.~','trend_issue'],
  ['~taxonomy\.vocabulary\.issues$~','trend_issue'],
  ['~\.paragraph\.record\.~','trend_issue'],
  ['~paragraphs\.paragraphs_type\.record$~','trend_issue'],
  ['~\.paragraph\.field_date$~','trend_issue'],
  ['~\.node\.field_(issues|take_aways)$~','trend_issue'],
  ['~pathauto\.pattern\.issues$~','trend_issue'],

  ['~(^|\.)node\.type\.journal_entry$~','trend_journal'],
  ['~\.node\.journal_entry\.~','trend_journal'],
  ['~^auto_entitylabel\.settings\.node\.journal_entry$~','trend_journal'],

  ['~(^|\.)node\.type\.quote$~','trend_quote'],
  ['~\.node\.quote\.~','trend_quote'],
  ['~\.node\.field_source$~','trend_quote'],
  ['~views\.view\.quotes$~','trend_quote'],
  ['~block\.block\..*quotes?(_|$)~','trend_quote'],
  ['~pathauto\.pattern\.quotes?$~','trend_quote'],
];

$FORCE_BASE = array_flip([
  'field.storage.node.body','field.storage.node.field_paragraphs',
  'field.storage.node.field_paragraph','field.storage.node.field_tags',
  'field.storage.node.field_image','field.storage.node.field_subtitle',
  'field.storage.node.field_comments','field.storage.node.layout_builder__layout',
  'field.storage.node.webform','field.storage.node.field_files_over_ajax',
  'field.storage.node.field_image_browser','field.storage.node.field_take_aways',
  'field.storage.paragraph.field_text_area','field.storage.paragraph.field_media',
  'field.storage.paragraph.field_caption','field.storage.paragraph.field_paragraphs',
  'field.storage.paragraph.field_section_title','field.storage.paragraph.field_hide_title',
  'field.storage.paragraph.field_text_list','field.storage.paragraph.field_view',
  'field.storage.paragraph.field_block','field.storage.paragraph.field_reusable_paragraph',
  'user.role.administrator','user.role.content_editor','user.role.content_creator',
]);
// Permission strings that reference add-on content types / excluded features.
$PERM_DROP_RE = '~(recipe|place|event|issue|journal_entry|quote|strava_route|race_day|race_day_leg_assignment|gps location|private messaging|ai ckeditor|ai content suggestion)~i';
// Config names that must never be relocated by the closure pass — strip the
// dangling dep instead (roles legitimately reference every content type).
$CLOSURE_STRIP_ONLY = fn(string $n): bool =>
  str_starts_with($n, 'user.role.') ||
  in_array($n, ['workflows.workflow.editorial'], TRUE);

// ---------------------------------------------------------------------------
// Modules that no recipe installs — scrub them from dependency lists.
$DROP_MODULES = array_flip([
  'book','ai','ai_automators','ai_ckeditor','ai_content_suggestions','ai_logging',
  'language','locale','config_translation','private_message','private_message_notify',
  'feeds','race_day','ut_tracking','strava_api','ut_robinhood','cove',
  'ut_data_visualization','smsframework','oauth_login_oauth2','dashboard',
  'migrate_plus','migrate_tools','background_image_formatter',
]);
$strip = function (array $d) use ($DROP_MODULES): array {
  unset($d['uuid'], $d['_core'], $d['default_config_hash']);
  foreach (['dependencies', 'dependencies.enforced'] as $path) {
    $ref = &$d;
    foreach (explode('.', $path) as $k) { if (!isset($ref[$k])) { unset($ref); $ref = NULL; break; } $ref = &$ref[$k]; }
    if (is_array($ref) && isset($ref['module']) && is_array($ref['module'])) {
      $ref['module'] = array_values(array_filter($ref['module'], fn($m) => !isset($DROP_MODULES[$m])));
      if (!$ref['module']) unset($ref['module']);
    }
    unset($ref);
  }
  if (isset($d['dependencies']['enforced']) && !$d['dependencies']['enforced']) unset($d['dependencies']['enforced']);

  // Drop stale keys that fail current module schemas (chris's export predates
  // some module updates; these are cosmetic but noisy at cim time).
  $walk = function (&$x) use (&$walk) {
    if (!is_array($x)) return;
    unset($x['swiftmailer']);
    if (($x['provider'] ?? NULL) === 'book') unset($x['provider']);
    // Drop Layout Builder components whose block plugin left with `book`.
    if (isset($x['components']) && is_array($x['components'])) {
      foreach ($x['components'] as $cid => $comp) {
        $bid = $comp['configuration']['id'] ?? '';
        if (str_starts_with($bid, 'book_') || ($comp['configuration']['provider'] ?? '') === 'book') {
          unset($x['components'][$cid]);
        }
      }
    }
    // stale views field-formatter keys (chris's export predates schema tightening)
    if (($x['type'] ?? NULL) === 'timestamp_ago' && isset($x['settings']) && is_array($x['settings'])) {
      unset($x['settings']['date_format'], $x['settings']['custom_date_format'], $x['settings']['timezone']);
    }
    if (($x['plugin_id'] ?? NULL) === 'user_roles') {
      foreach (['click_sort_column','settings','group_column','group_columns','group_rows',
                'delta_limit','delta_offset','delta_reversed','delta_first_last','multi_type',
                'field_api_classes'] as $k) unset($x[$k]);
    }
    if (isset($x['time_diff']) && is_array($x['time_diff'])) unset($x['time_diff']['description']);
    // field_group: `tabs`/`tab` formatters don't take html_element keys
    if (in_array($x['format_type'] ?? NULL, ['tabs', 'tab'], TRUE) && isset($x['format_settings']) && is_array($x['format_settings'])) {
      foreach (['element','show_label','label_element','label_element_classes','attributes','effect','speed'] as $k) {
        unset($x['format_settings'][$k]);
      }
    }
    // smart_date views sort: stale `granularity` key when plugin_id got numeric
    if (($x['plugin_id'] ?? NULL) === '1' || ($x['plugin_id'] ?? NULL) === 1) unset($x['granularity']);
    // fullcalendar_view: color_bundle should be a mapping, drop if scalar
    if (isset($x['color_bundle']) && !is_array($x['color_bundle'])) unset($x['color_bundle']);
    // stale layout_builder component config keys
    foreach (['block_mode','show_top_item','use_top_level_title'] as $k) {
      if (array_key_exists($k, $x) && isset($x['id']) && str_contains((string) $x['id'], 'entity_field')) unset($x[$k]);
    }
    foreach ($x as &$v) $walk($v);
  };
  $walk($d);
  return $d;
};
$load = function (string $p): array {
  $r = @file_get_contents($p);
  if ($r === FALSE) return [];
  $d = Yaml::decode($r);
  return is_array($d) ? $d : [];
};
$canon = function (array $d): string {
  $s = function (&$x) use (&$s) { if (is_array($x)) { ksort($x); foreach ($x as &$v) $s($v); } };
  $c = $d; $s($c); return json_encode($c);
};
$renameUtMaterial = function (array $d, string &$name): array {
  if (!str_contains($name, 'ut_material')) return $d;
  $name = str_replace('ut_material', 'ut_base', $name);
  $j = str_replace('ut_material', 'ut_base', json_encode($d));
  return json_decode($j, TRUE);
};
$ADDON_TYPES = [
  'recipe' => 'trend_recipe', 'place' => 'trend_place', 'event' => 'trend_event',
  'issue' => 'trend_issue', 'journal_entry' => 'trend_journal', 'quote' => 'trend_quote',
];
$routeAddon = function (string $name, array $data) use ($ADDON_RULES, $FORCE_BASE, $ADDON_TYPES): ?string {
  if (isset($FORCE_BASE[$name])) return NULL;
  // group.relationship_type.*: route by the node type its content_plugin targets.
  if (str_starts_with($name, 'group.relationship_type.') && !empty($data['content_plugin'])) {
    if (preg_match('~^group_node:(.+)$~', $data['content_plugin'], $mm)) {
      return $ADDON_TYPES[$mm[1]] ?? NULL;
    }
    return NULL;
  }
  foreach ($ADDON_RULES as [$re, $a]) if (preg_match($re, $name)) return $a;
  return NULL;
};

$report = array_fill_keys(
  ['base','trend_recipe','trend_place','trend_event','trend_issue','trend_journal','trend_quote',
   'skip_default','skip_rule','override','override_ignored','missing_dep','dep_issue'], []);
$actions = [];
$skipped = [];        // config name => TRUE  (never shipped anywhere)
$baseProvided = [];   // config name => TRUE  (present in base via default/override/action)
$bundled = [];        // config name => ['data'=>..., 'target'=>'base'|addon]

$recipeYml = Yaml::decode(file_get_contents("$RECIPE/recipe.yml"));
$known = $CORE_ALWAYS + $ADDON_DEPS;
foreach ($recipeYml['install'] ?? [] as $m) $known[$m] = TRUE;

foreach (['config','trend_recipe/config','trend_place/config','trend_event/config',
          'trend_issue/config','trend_journal/config','trend_quote/config'] as $d) {
  @array_map('unlink', glob("$RECIPE/$d/*.yml") ?: []);
}

$files = glob("$C_DIR/*.yml"); sort($files);
foreach ($files as $file) {
  $name = basename($file, '.yml');

  if (isset($SKIP_EXACT[$name])) { $report['skip_rule'][] = "$name (exact)"; continue; }
  $sk = FALSE;
  foreach ($SKIP_PREFIX as $p) if (str_starts_with($name, $p)) { $sk = "prefix $p"; break; }
  if (!$sk) foreach ($SKIP_CONTAINS as $s) if (str_contains($name, $s)) { $sk = "contains $s"; break; }
  if (!$sk && isset($SKIP_VIEWS[$name])) $sk = 'excluded view';
  if (!$sk && preg_match('~^block\.block\.([a-z0-9_]+?)_[a-z0-9_]+$~', $name, $m)) {
    // crude theme extraction: block.block.<theme>_<region/plugin>
    $matchedTheme = NULL;
    foreach (['material_base_mdc','material_base','ut_material','ut_base','gin','claro','stark','olivero'] as $t) {
      if (str_starts_with($name, "block.block.$t" . '_')) { $matchedTheme = $t; break; }
    }
    if ($matchedTheme && !in_array($matchedTheme, $KEEP_BLOCK_THEMES, TRUE)) $sk = "block theme $matchedTheme";
  }
  if ($sk) { $report['skip_rule'][] = "$name ($sk)"; $skipped[$name] = TRUE; continue; }

  $cData = $strip($load($file));

  if (isset($SCRUB_SECRET[$name])) {
    $ref = &$cData;
    foreach ($SCRUB_SECRET[$name] as $k) { if (!isset($ref[$k])) break; $ref = &$ref[$k]; }
    if (is_string($ref)) $ref = '';
    unset($ref);
  }

  $bFile = "$B_DIR/$name.yml";
  if (file_exists($bFile)) {
    $bData = $strip($load($bFile));
    if ($canon($cData) === $canon($bData)) { $report['skip_default'][] = $name; $baseProvided[$name] = TRUE; continue; }
    $ignored = isset($OVERRIDE_IGNORE[$name]);
    foreach ($OVERRIDE_IGNORE_PREFIX as $p) if (str_starts_with($name, $p)) $ignored = TRUE;
    if ($ignored) { $report['override_ignored'][] = $name; $baseProvided[$name] = TRUE; continue; }
    $report['override'][] = $name;
    $actions[$name] = $cData;
    $baseProvided[$name] = TRUE;
    continue;
  }

  // only in C -> ship bundled
  $cData = $renameUtMaterial($cData, $name);

  // Special-case: base editorial workflow covers article + page only; add-ons
  // extend it via the add_moderation config action.
  if ($name === 'workflows.workflow.editorial') {
    $keep = ['article', 'page'];
    $cData['type_settings']['entity_types']['node'] = $keep;
    $cData['dependencies']['config'] = array_values(array_filter(
      $cData['dependencies']['config'] ?? [],
      fn($d) => !preg_match('~^node\.type\.~', $d) || in_array(substr($d, 10), $keep, TRUE)
    ));
  }

  $addon = $routeAddon($name, $cData);
  $target = $addon ?? 'base';

  foreach ($cData['dependencies']['module'] ?? [] as $dep) {
    if (!isset($known[$dep])) $report['missing_dep'][] = "$name -> $dep";
  }

  $bundled[$name] = ['data' => $cData, 'target' => $target];
  if ($target === 'base') $baseProvided[$name] = TRUE;
}

// ---------------------------------------------------------------------------
// Dependency-closure pass.
//   - base module simple config (baseline B) also counts as "provided in base".
//   - a base file whose config-dep points at an add-on bucket -> move to that add-on.
//   - a base file whose config-dep points at skipped config -> strip that dep.
// ---------------------------------------------------------------------------
foreach (glob("$B_DIR/*.yml") as $bf) $baseProvided[basename($bf, '.yml')] = TRUE;

$addonOf = [];
foreach ($bundled as $n => $info) if ($info['target'] !== 'base') $addonOf[$n] = $info['target'];

for ($pass = 0; $pass < 6; $pass++) {
  $changed = FALSE;
  foreach ($bundled as $n => &$info) {
    $deps = $info['data']['dependencies']['config'] ?? [];
    foreach ($deps as $i => $dep) {
      if ($info['target'] === 'base') {
        if (isset($addonOf[$dep]) && !$CLOSURE_STRIP_ONLY($n)) {
          // base config depends on add-on config -> relocate to that add-on
          $info['target'] = $addonOf[$dep];
          $addonOf[$n] = $info['target'];
          unset($baseProvided[$n]);
          $report['dep_issue'][] = "MOVED $n -> {$info['target']} (needs $dep)";
          $changed = TRUE;
          continue 2;
        }
        $depMissing = !isset($baseProvided[$dep]) && !isset($bundled[$dep]);
        if (!$depMissing) continue;

        $isDisplay = (bool) preg_match('~^core\.entity_(form|view)_display\.~', $n);
        $isFieldDep = str_starts_with($dep, 'field.field.') || str_starts_with($dep, 'field.storage.');

        if ($CLOSURE_STRIP_ONLY($n) && isset($addonOf[$dep])) {
          unset($info['data']['dependencies']['config'][$i]);
          $info['data']['dependencies']['config'] = array_values($info['data']['dependencies']['config']);
          $report['dep_issue'][] = "STRIPPED add-on dep $dep from $n";
          $changed = TRUE;
          continue;
        }
        if ($isDisplay && $isFieldDep && preg_match('~\.field\.[^.]+\.[^.]+\.([^.]+)$~', $dep, $fm)) {
          $fld = $fm[1];
          unset($info['data']['content'][$fld], $info['data']['hidden'][$fld]);
          unset($info['data']['dependencies']['config'][$i]);
          $info['data']['dependencies']['config'] = array_values($info['data']['dependencies']['config']);
          $report['dep_issue'][] = "STRIPPED field $fld (dep $dep) from display $n";
          $changed = TRUE;
          continue;
        }
        // otherwise: cannot safely keep this base file
        unset($bundled[$n]);
        unset($baseProvided[$n]);
        $report['dep_issue'][] = "DROPPED $n (unmet dep $dep)";
        $changed = TRUE;
        continue 2;
      }
    }
  }
  unset($info);
  if (!$changed) break;
}

// write
foreach ($bundled as $n => $info) {
  $data = $info['data'];
  // Filter add-on / excluded-feature permission strings out of bundled roles.
  if (str_starts_with($n, 'user.role.') && !empty($data['permissions'])) {
    $data['permissions'] = array_values(array_filter(
      $data['permissions'], fn($p) => !preg_match($PERM_DROP_RE, $p)
    ));
  }
  $dir = $info['target'] === 'base' ? "$RECIPE/config" : "$RECIPE/{$info['target']}/config";
  @mkdir($dir, 0777, TRUE);
  file_put_contents("$dir/$n.yml", Yaml::encode($data));
  $report[$info['target']][] = $n;
}

// ---- reports ----
$sum = '';
foreach (['base','trend_recipe','trend_place','trend_event','trend_issue','trend_journal','trend_quote'] as $k)
  $sum .= sprintf("%-15s %4d bundled\n", $k, count($report[$k]));
$sum .= sprintf("%-15s %4d identical-to-default (skipped)\n", 'skip_default', count($report['skip_default']));
$sum .= sprintf("%-15s %4d site-specific/excluded (skipped)\n", 'skip_rule', count($report['skip_rule']));
$sum .= sprintf("%-15s %4d differ-from-default -> config.action needed\n", 'override', count($report['override']));
$sum .= sprintf("%-15s %4d differ-from-default -> ignored as noise\n", 'override_ignored', count($report['override_ignored']));
$sum .= sprintf("%-15s %4d module-dep-not-in-base\n", 'missing_dep', count(array_unique($report['missing_dep'])));
$sum .= sprintf("%-15s %4d closure-pass relocations/strips\n", 'dep_issue', count($report['dep_issue']));

file_put_contents("$BUILD/report.summary.txt", $sum);
file_put_contents("$BUILD/report.override.txt", implode("\n", $report['override']) . "\n");
file_put_contents("$BUILD/report.skip_rule.txt", implode("\n", $report['skip_rule']) . "\n");
file_put_contents("$BUILD/report.missing_dep.txt", implode("\n", array_unique($report['missing_dep'])) . "\n");
file_put_contents("$BUILD/report.dep_issue.txt", implode("\n", $report['dep_issue']) . "\n");
file_put_contents("$BUILD/report.actions.todo.yml", Yaml::encode(['_desired_values_for_overrides' => $actions]));
file_put_contents("$BUILD/report.full.json", json_encode($report, JSON_PRETTY_PRINT));

print "\n$sum\nDetails: $BUILD/report.*\n";
