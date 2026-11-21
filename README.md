# Every

Small Luau libraries for Roblox, each published on its own as `every/<name>` to [ember](https://luaupm.com).

Documentation: https://every-luau.github.io

| Library | |
| --- | --- |
| [Atom](libraries/Atom) | Atom is a value that can be observed, derived and updated. |
| [BetterScale](libraries/BetterScale) | BetterScale scales a UIScale with the size of its gui, configured with attributes. |
| [Bootstrap](libraries/Bootstrap) | Bootstrap requires ModuleScripts and calls their hooks in order of priority. |
| [Connection](libraries/Connection) | Connection is like Roblox's RBXScriptConnection, but for your own code. |
| [Future](libraries/Future) | Future is a value available later, with chaining, combinators and cancellation. |
| [Lifecycle](libraries/Lifecycle) | Lifecycle builds objects whose lifecycle hooks are registered with chainable calls. |
| [Loop](libraries/Loop) | Loop calls a callback every few seconds, driven by Heartbeat. |
| [Observable](libraries/Observable) | Observable is a reactive stream of values to subscribe to, map, filter and dedupe. |
| [Observe](libraries/Observe) | Observe runs a callback for every player, character, instance, tag or value, now and later. |
| [Ratelimit](libraries/Ratelimit) | Ratelimit limits how many times something can happen per key within an interval. |
| [Region](libraries/Region) | Region is a box that reports what enters and leaves it, every frame, without physics queries. |
| [Retryer](libraries/Retryer) | Retryer calls a function again until it stops erroring, with different waits. |
| [Signal](libraries/Signal) | Signal is a yield-safe signal whose handlers run on a recycled thread. |
| [Thread](libraries/Thread) | Thread runs callbacks on a recycled thread instead of creating a new one per call. |
| [Timer](libraries/Timer) | Timer is a stopwatch or countdown with a speed, updated every frame. |
| [Void](libraries/Void) | Void keeps track of things to clean up, and cleans them all at once. |
| [Volume](libraries/Volume) | Volume is a box made of a CFrame and a size, with containment checks. |
| [Weight](libraries/Weight) | Weight picks random keys from a table of weights, with an optional luck factor. |

## Layout

```
libraries/<Name>/   one package: src, tests, examples and its ember manifest
template/           what `just new <Name>` copies
scripts/lib.luau    versions, scaffolding and sourcemap, run by the justfile
```

Each library's `fumablox.toml` holds the `title` and `description` shown on the documentation site and in the table above.

Libraries require each other as siblings (`script.Parent.Thread`), the way package managers install them. `just sourcemap` writes a `sourcemap.json` with every library side by side so luau-lsp resolves those requires.

## Commands

Needs [lune](https://github.com/lune-org/lune) (pinned in `ember.toml`) and [just](https://github.com/casey/just).

```sh
just new Name              # scaffold libraries/Name from the template
just test Signal           # run a library's tests
just test-all              # run every library's tests
just docs Signal           # check its Moonwave docs
just versions              # every library's version
just bump Signal minor     # bump its version
just release Signal patch  # bump, test and publish to ember
```

CI tests and checks the docs of every library on each push, then rebuilds the [documentation site](https://github.com/every-luau/every-luau.github.io).
