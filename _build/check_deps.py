#!/usr/bin/env python3
"""Cross-check: every module named in a recipe install: list must be a core
module/theme, or belong to a project the trend_project template requires.

  python3 recipes/trend_personal/_build/check_deps.py
"""
import json, os, re, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

def yaml_list(path, key):
    out, grab = [], False
    for ln in open(path):
        if re.match(rf'^{key}:\s*(\[\])?\s*$', ln):
            grab = True; continue
        if grab:
            m = re.match(r'^\s*-\s*(\S+)', ln)
            if m: out.append(m.group(1))
            elif ln.strip() and not ln.startswith((' ', '#')): grab = False
    return out

def info_project(path):
    for ln in open(path):
        m = re.match(r"^project:\s*'?([\w-]+)'?", ln)
        if m: return m.group(1)
    return None

def info_deps(path):
    """module machine names from an .info.yml `dependencies:` list."""
    out, grab = [], False
    for ln in open(path):
        if re.match(r'^dependencies:\s*$', ln): grab = True; continue
        if grab:
            m = re.match(r'^\s*-\s*([\w:]+)', ln)
            if m: out.append(m.group(1).split(':')[-1])
            elif ln.strip() and not ln.startswith((' ', '#')): grab = False
    return out

# modules named across all recipe install: lists
recipes = [os.path.join(ROOT, 'recipes/trend_personal/recipe.yml')] + \
          glob.glob(os.path.join(ROOT, 'recipes/trend_personal/trend_*/recipe.yml'))
needed = set()
for r in recipes:
    needed |= set(yaml_list(r, 'install'))

# core modules + themes
core = set(os.listdir(os.path.join(ROOT, 'web/core/modules'))) | \
       set(os.listdir(os.path.join(ROOT, 'web/core/themes'))) | {'mysql'}
# contrib submodules whose git checkout lacks a `project:` key
SUBMODULE_OF = {'smart_date_starter_kit': 'smart_date'}

# projects the template requires
tp = json.load(open(os.path.join(ROOT, 'recipes/trend_personal/_build/trend_project.composer.json')))
req_projects = {k.split('/', 1)[1] for k in tp['require'] if k.startswith('drupal/')}
req_projects |= {'ut_base', 'ut_utilities', 'ut_recipe'}
# core-recommended pseudo
req_projects -= {'core-recommended', 'core-composer-scaffold', 'core-project-message'}

# machine-name -> owning project + declared deps, from every installed *.info.yml
mod_project, mod_deps = {}, {}
for base in ('web/modules/contrib', 'web/themes/contrib', 'web/modules/custom', 'web/themes/custom'):
    for dirpath, _, files in os.walk(os.path.join(ROOT, base)):
        for f in files:
            if f.endswith('.info.yml'):
                name = f[:-len('.info.yml')]
                fp = os.path.join(dirpath, f)
                mod_project.setdefault(name, info_project(fp) or name)
                mod_deps.setdefault(name, info_deps(fp))

# expand `needed` with the transitive .info.yml dependency closure
seen = set()
queue = list(needed)
while queue:
    m = queue.pop()
    if m in seen: continue
    seen.add(m); needed.add(m)
    queue.extend(mod_deps.get(m, []))

missing = []
for m in sorted(needed):
    if m in core:
        continue
    proj = SUBMODULE_OF.get(m) or mod_project.get(m)
    if proj is None:
        missing.append(f"{m}  (unknown — not found in source repo)")
    elif proj not in req_projects and m not in req_projects:
        missing.append(f"{m}  (project '{proj}' not in template require)")

print(f"recipe install: names   {len(needed)}")
print(f"MISSING ({len(missing)}):")
for m in missing:
    print(f"  {m}")
sys.exit(1 if missing else 0)
