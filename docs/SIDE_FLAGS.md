# Client / server side flags

`packwiz modrinth import` sets each mod's `side` from Modrinth metadata. It's
mostly correct, but a few mods are commonly mistagged, and getting them wrong
either bloats/crashes the server (client mods it can't load) or breaks features
(server component missing). After importing, verify against this list and fix
with:

```
packwiz env set <mod> client     # client-only: never installed on the server
packwiz env set <mod> both       # installed on client AND server
packwiz env set <mod> server     # server-only (none in this pack)
```

`packwiz-installer ... -s server` then installs only `server` + `both` mods, so
the server stays lean automatically once these are right.

## Must be CLIENT (exclude from the server)

Rendering, input, UI, and map mods — the server neither needs nor can load them:

- sodium, iris, better-clouds, DistantHorizons, ImmediatelyFast
- entity_model_features (EMF), entity_texture_features (ETF)
- xaerominimap, xaeroworldmap
- MouseTweaks, controlify, freecam
- AmbientSounds, CreativeCore  *(CreativeCore is only here as AmbientSounds' dependency)*
- yet_another_config_lib (YACL)
- **JEI** — client-only recipe viewer. The `jei-server.toml` config is just a stub; the mod itself does not belong on the server.
- EasyShulkerBoxes — client-side visual (verify; low risk either way)
- PlayerAnimationLib — client animation lib **(verify: if bettercombat errors on the server without it, set to `both`)**

## Must be BOTH (client and server)

Worldgen, content, gameplay, and the libs they need server-side:

- BiomesOPlenty, TerraBlender, Terralith, lithostitched, cristellib, GlitchCore, PuzzlesLib
- dungeons-and-taverns, towns_and_towers (t_and_t)
- bettercombat, sophisticatedbackpacks, sophisticatedcore, BundleUpgrade
- NaturesCompass, waystones, balm, shogi
- cloth-config *(used for server-side config too)*
- ferritecore *(memory optimization — beneficial on the server)*

## Watch out — the two everyone gets wrong

- **Simple Voice Chat (`voicechat`) → `both`.** It has a required *server*
  component; if it's client-only, in-game voice silently won't work.
- **Lithium (`lithium`) → `both`.** It's a *server-tick* performance mod. People
  assume "optimization = client" and exclude it, losing the biggest server perf
  win in the pack. Keep it on the server.

## Sanity check after fixing

```
packwiz list --side server     # should show content/worldgen/libs, NOT sodium/iris/xaero/JEI
packwiz list --side client     # should show the rendering/UI/map mods
```
