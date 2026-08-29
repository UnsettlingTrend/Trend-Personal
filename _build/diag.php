<?php

/**
 * @file
 * Post-install diagnostics for the trend_personal recipe.
 *   lando drush php:script /app/recipes/trend_personal/_build/diag.php
 */

$etm = \Drupal::entityTypeManager();

$nt = array_keys($etm->getStorage('node_type')->loadMultiple());
print 'node types: ' . implode(',', $nt) . "\n";
$vc = array_keys($etm->getStorage('taxonomy_vocabulary')->loadMultiple());
print 'vocabs: ' . implode(',', $vc) . "\n";
$pt = array_keys($etm->getStorage('paragraphs_type')->loadMultiple());
print 'paragraph types: ' . implode(',', $pt) . "\n";
print 'theme default: ' . \Drupal::config('system.theme')->get('default') . "\n";
print 'roles: ' . implode(',', array_keys($etm->getStorage('user_role')->loadMultiple())) . "\n";

try {
  $code = \Drupal::httpClient()->get('http://localhost/', ['http_errors' => FALSE])->getStatusCode();
  print "front page HTTP: $code\n";
}
catch (\Throwable $e) {
  print 'front page ERR: ' . $e->getMessage() . "\n";
}

// Config validation sweep.
$bad = [];
$typed = \Drupal::service('config.typed');
foreach (\Drupal::configFactory()->listAll() as $n) {
  try {
    $v = $typed->get($n)->validate();
    foreach ($v as $x) {
      $bad[] = "$n :: " . $x->getPropertyPath() . ' :: ' . strip_tags((string) $x->getMessage());
    }
  }
  catch (\Throwable $e) {
    $bad[] = "$n :: EXC :: " . $e->getMessage();
  }
}
print "\n" . count($bad) . " config validation problems:\n";
print implode("\n", array_slice($bad, 0, 70)) . "\n";

// Watchdog errors.
$rows = \Drupal::database()->select('watchdog', 'w')
  ->fields('w', ['type', 'severity', 'message', 'variables'])
  ->condition('severity', 3, '<=')
  ->orderBy('wid', 'DESC')
  ->range(0, 20)
  ->execute();
print "\nwatchdog (err/crit):\n";
foreach ($rows as $r) {
  $vars = @unserialize($r->variables) ?: [];
  $msg = strtr($r->message, is_array($vars) ? $vars : []);
  print '  [' . $r->type . '] ' . mb_substr(strip_tags($msg), 0, 180) . "\n";
}
