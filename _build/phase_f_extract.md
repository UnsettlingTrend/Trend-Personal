# Phase F — split the 4 packages into their own repos & publish

Do this once the in-repo build is validated end to end. All four are currently
developed in-tree under `feature/recipe-based-install`:

| package | in-tree path | target repo | first tag |
|---|---|---|---|
| `unsettlingtrend/trend_personal` (drupal-recipe) | `recipes/trend_personal/` | `gitlab.com/unsettlingtrend/trend_personal` | `2.0.0` |
| `unsettlingtrend/ut_base` (drupal-theme) | `web/themes/custom/ut_base/` | `gitlab.com/unsettlingtrend/ut_base` | `1.0.0` |
| `unsettlingtrend/ut_utilities` (drupal-module) | `web/modules/custom/ut_utilities/` | `gitlab.com/unsettlingtrend/ut_utilities` | `1.0.0` |
| `unsettlingtrend/ut_recipe` (drupal-module) | `web/modules/custom/ut_recipe/` | `gitlab.com/unsettlingtrend/ut_recipe` | `1.0.0` |

`trend_personal` is `2.0.0` (not `1.x`) because the existing `unsettlingtrend/trend_personal`
package is a `drupal-profile` at `^1.0.2` — changing `type` to `drupal-recipe` is a
breaking change.

## 1. Prep each package for extraction

- **`recipes/trend_personal/`**: add `.gitattributes` with `/_build export-ignore`
  so the toolchain doesn't ship to sites. Add a `composer.json`:
  ```json
  { "name": "unsettlingtrend/trend_personal", "type": "drupal-recipe",
    "license": "GPL-2.0-or-later", "require": { "drupal/core": ">=11.1" } }
  ```
  (Recipe `install:` modules are provided by the project, not required here —
  matches how core/drupal_cms recipes are packaged.)
- **`ut_base/`**, **`ut_utilities/`**, **`ut_recipe/`**: composer.json already written.
  Confirm `.gitignore` in `ut_base` ignores `dist/` and `node_modules/`.

## 2. subtree split (run from the repo root)

```bash
git subtree split --prefix=recipes/trend_personal        -b split/trend_personal
git subtree split --prefix=web/themes/custom/ut_base      -b split/ut_base
git subtree split --prefix=web/modules/custom/ut_utilities -b split/ut_utilities
git subtree split --prefix=web/modules/custom/ut_recipe    -b split/ut_recipe
```

Then for each: create the empty gitlab repo, and

```bash
git push git@gitlab.com:unsettlingtrend/trend_personal.git split/trend_personal:main
# clone it fresh, tag, push --tags
```

(If history isn't worth keeping, simpler: `rsync` each dir into a fresh
`git init` repo and push. subtree keeps the commit history.)

## 3. Point the template at the published packages

In `unsettlingtrend/trend_project`'s `composer.json`, the `repositories` block
already has the four `vcs` entries. Nothing to change — once the repos exist and
are tagged, `composer create-project` resolves them.

For **local iteration before publishing**, swap the four `vcs` entries for `path`
repos:

```json
{ "type": "path", "url": "../com.chrisferagotti.unsettlingtrend/recipes/trend_personal" },
{ "type": "path", "url": "../com.chrisferagotti.unsettlingtrend/web/themes/custom/ut_base" },
{ "type": "path", "url": "../com.chrisferagotti.unsettlingtrend/web/modules/custom/ut_utilities" },
{ "type": "path", "url": "../com.chrisferagotti.unsettlingtrend/web/modules/custom/ut_recipe" }
```

and set the four `unsettlingtrend/*` version constraints to `@dev` or `*`.

## 4. End-to-end test

```bash
cd ~/projects
composer create-project unsettlingtrend/trend_project ttest --repository='{"type":"path","url":"..."}' ...
cd ttest && lando start && lando composer install && lando build
lando drush site:install recipes/trend_personal -y \
  --account-name=admin --account-pass=admin \
  trend_personal.site_name="TT" trend_personal.site_mail="t@example.com"
```

Expect: the same green install as the in-repo `trend-test`, but now from a
`composer create-project` skeleton with the packages pulled by Composer.

## 5. Publish

- Tag each package repo; register on Packagist (or a private Satis) so
  `composer create-project unsettlingtrend/trend_project` works without the
  `repositories` overrides.
- Publish `unsettlingtrend/trend_project` itself the same way.
