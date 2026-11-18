set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

script := "lune run scripts/lib"

# List recipes
default:
    @just --list --unsorted

# Scaffold libraries/<Name> from the template (keeps existing non-empty files)
new name:
    {{script}} new {{name}}

# Show a library's version, or set it in ember/pesde/wally manifests
version lib version="":
    {{script}} version {{lib}} {{version}}

# Bump a library's version: major, minor or patch
bump lib kind="patch":
    {{script}} bump {{lib}} {{kind}}

# Show every library's version
versions:
    {{script}} versions

# Write sourcemap.json so luau-lsp resolves requires between libraries
sourcemap:
    {{script}} sourcemap

# Run a library's tests
test lib:
    {{script}} run {{lib}} lest

# Run every library's tests
test-all:
    {{script}} each lest

# Check a library's Moonwave docs with fumablox
docs lib:
    {{script}} run {{lib}} npx --yes @metricsrb/fumablox@1 check

# Generate every library's docs and run the site locally
[working-directory('every-luau.github.io')]
site:
    npm run generate -- ../libraries
    npm run dev

# Show what each registry would publish, without uploading
dry-run lib:
    {{script}} run {{lib}} embr publish --dry-run
    {{script}} run {{lib}} pesde publish --dry-run

# Test then publish a library to ember, pesde and wally
publish lib: (test lib)
    {{script}} run {{lib}} embr publish
    {{script}} run {{lib}} pesde publish
    {{script}} run {{lib}} wally publish

# Bump, then publish
release lib kind="patch": (bump lib kind) (publish lib)
