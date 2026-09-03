#!/usr/bin/env bash
#
# Phase F, step 1: carve the four packages out of this repo into standalone
# branches (full history for each subtree). Then push each branch to its new
# gitlab repo's `main`, tag, and register.
#
#   bash recipes/trend_personal/_build/phase_f_split.sh
#
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

declare -A SUBTREES=(
  [trend_personal]="recipes/trend_personal"
  [ut_base]="web/themes/custom/ut_base"
  [ut_utilities]="web/modules/custom/ut_utilities"
  [ut_recipe]="web/modules/custom/ut_recipe"
)

for name in "${!SUBTREES[@]}"; do
  prefix="${SUBTREES[$name]}"
  branch="split/$name"
  echo "== $name  ($prefix)"
  git branch -D "$branch" 2>/dev/null || true
  git subtree split --prefix="$prefix" -b "$branch"
  echo "   -> branch $branch  ($(git rev-list --count "$branch") commits, tip $(git rev-parse --short "$branch"))"
done

cat <<'NEXT'

Branches created: split/trend_personal, split/ut_base, split/ut_utilities, split/ut_recipe

Next (needs your gitlab account):
  1. Create empty repos:
       gitlab.com/unsettlingtrend/{trend_personal,ut_base,ut_utilities,ut_recipe}
  2. Push each split branch as main, e.g.:
       git push git@gitlab.com:unsettlingtrend/trend_personal.git split/trend_personal:main
  3. In a fresh clone of each, tag and push:
       trend_personal -> 2.0.0   (breaking: was a drupal-profile at ^1.0.2)
       ut_base ut_utilities ut_recipe -> 1.0.0
  4. Point the template at them: rebuild trend_project WITHOUT LOCAL_PATHS
     (the four `vcs` repos in trend_project.composer.json are already there),
     set the four unsettlingtrend/* constraints to ^2.0 / ^1.0, push
     trend_project to gitlab.com/unsettlingtrend/trend_project.
  5. `composer create-project unsettlingtrend/trend_project ttest` end-to-end.
     (Packagist registration optional — vcs repos in composer.json suffice.)
NEXT
