# Trend Personal recipes

`unsettlingtrend/trend_personal` — the recipe set behind a Trend personal site.

## Structure

```
composer.json         requires the three content modules
trend_base/
  recipe.yml          the foundation (content model, theme, glue) + installs
                      ut_default_content and imports its config
  config/             ~446 base config objects
trend_default/
  recipe.yml          recipes: [trend_base] — the create-project default
trend_personal/
  recipe.yml          recipes: [trend_base] + ut_journal + ut_recipes
_build/               extraction toolchain (reference only, not shipped)
```

The content types themselves live in modules, not in these recipes:

| module | content types |
|---|---|
| `unsettlingtrend/ut_default_content` | place, event, quote, issue |
| `unsettlingtrend/ut_journal` | journal_entry |
| `unsettlingtrend/ut_recipes` | recipe (+ fraction filter, SDC components) |

Each module ships its config in `config/optional`, so enabling it on a site that
already has the config is a no-op. A recipe's `config.import` creates the config
on a fresh install (recipes install modules with config-entity installation
disabled).

## Install

```bash
# Standard site
drush site:install recipes/trend_personal/trend_default -y \
  --account-name=admin --account-pass=admin \
  trend_base.site_name="My Site" trend_base.site_mail="me@example.com"

# Full site (adds journal + recipes)
drush site:install recipes/trend_personal/trend_personal -y \
  --account-name=admin --account-pass=admin \
  trend_base.site_name="My Site" trend_base.site_mail="me@example.com"
```

`trend_base.google_maps_api_key=…` is optional; it defaults to the
`GOOGLE_MAPS_API_KEY` environment variable.

## Editorial workflow

`trend_base` moderates `event` and `issue`; `trend_personal` adds `recipe`.
`place`, `quote` and `journal_entry` are not moderated.

## Regenerating `trend_base/config/`

Generated from a reference-site export by `_build/strip_bucket.php` (not run at
install time). The module `config/optional` directories are generated the same
way, in their own repos.
