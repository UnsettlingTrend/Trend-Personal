# Trend Project

A Composer template for spinning up a **Trend personal site** — a Drupal 11 site
built from the `unsettlingtrend/trend_personal` recipe, with the `ut_base` theme
and `ut_utilities` glue module. Each site created from this template is its own
git repo, its own Platform.sh/Upsun project, and diverges freely after creation.

## Create a new site

Once the packages are published (Packagist / private Satis):

```bash
composer create-project unsettlingtrend/trend_project my-site
```

Before then, clone this template repo (it carries the four `unsettlingtrend/*`
packages under `_local_packages/` and resolves them via path repos):

```bash
git clone <this-repo> my-site && rm -rf my-site/.git
```

Then, either way:

```bash
cd my-site
lando start            # creates web/sites/default/settings.local.php on first run
lando composer install
lando build            # compiles material_base + ut_base theme assets

lando si               # = drush site:install recipes/trend_personal -y --account-name=admin --account-pass=admin
#   (or the full form to pass site_name / site_mail:)
# lando drush site:install recipes/trend_personal -y \
#   --account-name=admin --account-pass=admin \
#   trend_personal.site_name="My Site" trend_personal.site_mail="me@example.com"

lando drush cex -y     # seed config/sync/default from the installed site
git init && git add -A && git commit -m "Initial install from trend_project"
```

## Add-on content types (optional, à la carte)

The base gives you `article`, `page`, `landing_page`, `webform`. Apply any of
these on top for the personal content types — order matters only where noted:

```bash
lando drush recipe recipes/trend_personal/trend_place   -y   # physical locations w/ maps
lando drush recipe recipes/trend_personal/trend_event   -y   # events (apply trend_place first for the place ref)
lando drush recipe recipes/trend_personal/trend_recipe  -y   # cooking recipes
lando drush recipe recipes/trend_personal/trend_issue   -y   # tracked issues
lando drush recipe recipes/trend_personal/trend_journal -y   # dated journal entries
lando drush recipe recipes/trend_personal/trend_quote   -y   # quotes + front-page block
lando drush cr && lando drush cex -y
```

Recipes are apply-once. After the first apply, manage further changes through
config sync (`drush cex` / `drush cim`), not by re-running the recipe.

## Connecting to Platform.sh / Upsun

1. `platform project:create` (or `upsun project:create`), then
   `platform project:set-remote <id>`.
2. Set the credential variables the site expects (all optional; unset ones fall
   back to `<environment-variable>` placeholders):
   `CREDS_RECAPTCHA_SITE_KEY`, `CREDS_RECAPTCHA_SECRET_KEY`,
   `CREDS_GOOGLE_MAPS_PLATFORM_API_KEY`, `CREDS_GOOGLE_MAPS_PLATFORM_SERVER_KEY`,
   `CREDS_OAUTH_CLIENT_ID`, `CREDS_OAUTH_CLIENT_SECRET`.
3. `git push platform main`.

`config_split` is wired per branch in `web/sites/default/settings.platformsh.php`:
`main` → `production`, `develop` → `non_production` + `develop`, else
`develop` + `local`.

## Theme development

The theme lives at `web/themes/contrib/ut_base` (installed by Composer). It is a
`material_base_mdc` subtheme with a webpack build:

```bash
cd web/themes/contrib/ut_base
lando npm install
lando npm run develop      # watch build
```

To customise the look, override the SCSS variables in
`scss/theme/variables.scss` or add your own libraries — or fork `ut_base` into
`web/themes/custom/` for site-specific work.

## What's a per-site decision

- `system.date` (country / timezone) — set it after install for your locale.
- Search backend — base ships `search_api_db`. Switch the index to Solr in
  `search_api.server.*` if the site needs it (the Platform.sh service is defined
  in `.platform/services.yaml`).
- `user.settings:register` defaults to `visitors_admin_approval`; loosen if you
  want open registration.
