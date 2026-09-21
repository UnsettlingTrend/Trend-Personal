# Trend Personal

`unsettlingtrend/trend_personal` — the Trend personal-site recipe: the
[`trend_base`](https://github.com/UnsettlingTrend/Trend-Base) foundation plus

| module | adds |
|---|---|
| `unsettlingtrend/ut_journal` | `journal_entry` content type |
| `unsettlingtrend/ut_recipes` | `recipe` content type, fraction filter, ingredient/directions components |

It also puts `recipe` under the editorial workflow (`journal_entry` is not
moderated).

## Install

`trend_base` must sit next to this recipe (`recipes/trend_base`) — Composer does
that when it installs `drupal-recipe` packages.

```bash
drush site:install recipes/trend_personal -y \
  --account-name=admin --account-pass=admin \
  --site-name="My Site" --site-mail="me@example.com"
```

Set the per-site Google Maps geocoding key afterwards; see the `trend_base`
README.

## History

Until 4.0.0 this package also carried `trend_base` and a `trend_default`
composition. `trend_base` is now its own package and installs directly as the
standard site, so `trend_default` is gone: use `recipes/trend_base`.
