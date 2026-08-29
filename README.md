# Trend Personal recipes

`unsettlingtrend/trend_personal` — the recipe set behind a Trend personal site.

## Structure

```
recipes/trend_personal/
  recipe.yml          the lean base — install the site FROM this
  config/             ~450 base config objects (content model, theme, glue)
  trend_recipe/       add-on: cooking-recipe content type
  trend_place/        add-on: physical places with maps
  trend_event/        add-on: events (Smart Date, optional place ref)
  trend_issue/        add-on: tracked issues
  trend_journal/      add-on: dated journal entries
  trend_quote/        add-on: quotes + front-page block
  _build/             the extraction toolchain (not shipped to sites)
```

## Install

The **base is the site install**:

```bash
drush site:install recipes/trend_personal -y \
  --account-name=admin --account-pass=admin \
  trend_personal.site_name="My Site" trend_personal.site_mail="me@example.com"
```

Recipes install modules with config-entity installation disabled, so every
config entity the base needs is bundled in `config/` (stripped of `uuid`/`_core`).
Module *settings* that the base customises are applied as `config.actions`.

## Add-ons

Each add-on applies **on top of an installed base** (it does not declare the base
as a dependency — the base is already the site):

```bash
drush recipe recipes/trend_personal/trend_place  -y   # before trend_event
drush recipe recipes/trend_personal/trend_event  -y
drush recipe recipes/trend_personal/trend_recipe -y
drush recipe recipes/trend_personal/trend_issue  -y
drush recipe recipes/trend_personal/trend_journal -y
drush recipe recipes/trend_personal/trend_quote  -y
drush cr && drush cex -y
```

`trend_recipe` / `trend_event` / `trend_issue` extend the editorial workflow to
their content type via the core `add_moderation` config action. After first
apply, manage further changes through config sync, not by re-running the recipe.

## Base module set

The base `recipe.yml` `install:` list is the source of truth. It deliberately
**excludes**: AI modules, `language`/`locale`/`config_translation` (English-only),
`book`, and every chrisferagotti-specific custom module (Strava, Robinhood, race
day, GPS tracking). The `group` module and its `restricted_content` group type
**are** in the base.

## Regenerating `config/`

The base and add-on `config/` directories are generated from a reference site
export by `_build/strip_bucket.php`. It is not run at install time. See
`_build/` for the toolchain (`strip_bucket.php`, `diag.php`, reports).
