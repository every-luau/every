# nall

Not Another Luau Lib: small Luau libraries for Roblox, each published on its own as `nall/<name>` to [ember](https://luaupm.com), [pesde](https://pesde.dev) and [wally](https://wally.run).

Documentation: https://not-another-luau-lib.github.io

| Library | |
| --- | --- |
| [Atom](libraries/Atom) | A value that can be observed, derived and updated. |
| [BetterScale](libraries/BetterScale) | Scales a UIScale with the size of its gui, configured with attributes. |
| [Bootstrap](libraries/Bootstrap) | Requires ModuleScripts and calls their hooks in order of priority. |
| [Connection](libraries/Connection) | A handle that cleans up a Void when disconnected. |
| [Future](libraries/Future) | A value available later, with chaining, combinators and cancellation. |
| [Lifecycle](libraries/Lifecycle) | Builds objects whose lifecycle hooks are registered with chainable calls. |
| [Loop](libraries/Loop) | Calls a callback every few seconds, driven by Heartbeat. |
| [Observable](libraries/Observable) | A reactive stream of values to subscribe to, map, filter and dedupe. |
| [Observe](libraries/Observe) | Runs a callback for every player, character, instance, tag or value, now and later. |
| [Ratelimit](libraries/Ratelimit) | Limits how many times something can happen per key within an interval. |
| [Region](libraries/Region) | A box that reports what enters and leaves it, every frame, without physics queries. |
| [Retryer](libraries/Retryer) | Calls a function again until it stops erroring, with different waits. |
| [Signal](libraries/Signal) | A yield-safe signal whose handlers run on a recycled thread. |
| [Thread](libraries/Thread) | Runs callbacks on a recycled thread instead of creating a new one per call. |
| [Timer](libraries/Timer) | A stopwatch or countdown with a speed, updated every frame. |
| [Void](libraries/Void) | Keeps track of things to clean up, and cleans them all at once. |
| [Volume](libraries/Volume) | A box made of a CFrame and a size, with containment checks. |
| [Weight](libraries/Weight) | Picks random keys from a table of weights, with an optional luck factor. |

## Layout

```
libraries/<Name>/   one package: src, tests, examples and its ember/pesde/wally manifests
template/           what `just new <Name>` copies
scripts/lib.luau    versions, scaffolding and sourcemap, run by the justfile
```

Libraries require each other as siblings (`script.Parent.Thread`), the way package managers install them. `just sourcemap` writes a `sourcemap.json` with every library side by side so luau-lsp resolves those requires.

## Commands

Needs [lune](https://github.com/lune-org/lune) (pinned in `ember.toml`) and [just](https://github.com/casey/just).

```sh
just new Name              # scaffold libraries/Name from the template
just test Signal           # run a library's tests
just test-all              # run every library's tests
just docs Signal           # check its Moonwave docs
just versions              # every library's version
just bump Signal minor     # bump it in ember, pesde and wally
just release Signal patch  # bump, test and publish to every registry
```

CI tests and checks the docs of every library on each push, then rebuilds the [documentation site](https://github.com/not-another-luau-lib/not-another-luau-lib.github.io).
