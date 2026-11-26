set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

script := "lune run scripts/lib"

# List recipes
default:
    @just --list --unsorted

# Scaffold libraries/<Name> from the template (keeps existing non-empty files)
new name:
    {{script}} new {{name}}

# Show a library's version, or set it in its ember manifest
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

# Generate every library's docs and run the site locally (the site repo is cloned next to libraries/).
# The gh token keeps the generator above the 60 GitHub API calls an hour it gets without one.
site:
    cd *.github.io; if (Get-Command gh -ErrorAction SilentlyContinue) { $env:GH_TOKEN = gh auth token }; npm run generate -- ../libraries; npm run dev

# Show what ember would publish, without uploading
dry-run lib:
    {{script}} run {{lib}} embr publish --dry-run

# Test then publish a library to ember
publish lib: (test lib)
    {{script}} run {{lib}} embr publish

# Bump, then publish
release lib kind="patch": (bump lib kind) (publish lib)
