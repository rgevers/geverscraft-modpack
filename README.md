# geverscraft-modpack

Version-controlled NeoForge modpack (Minecraft **26.2**), authored with
[packwiz](https://packwiz.infra.link/) and distributed to players via
auto-sync. The pack is the single source of truth for both the **client** and
the **dedicated server** — they can't drift.

Only *metadata* lives here (mod slugs, versions, hashes, and shared configs).
No mod jars are committed, so this repo is safe to keep **public** — clients and
the server download the actual mods straight from Modrinth. That's what makes
public raw-URL hosting legal and painless.

---

## One-time setup (author machine)

1. **Install packwiz.** On Windows the easiest is Scoop:
   ```
   scoop install packwiz
   ```
   (or grab the binary from https://github.com/packwiz/packwiz/releases and put
   it on your PATH.)

2. **Seed the pack from your Modrinth App profile.** In the Modrinth App,
   right-click the `NeoForge 26.2` profile -> **Export** to produce a `.mrpack`.
   Then, from the repo root:
   ```
   packwiz init            # name it, author = you, MC version 26.2, loader = neoforge, pick the build
   packwiz modrinth import "C:\path\to\your-export.mrpack"
   packwiz refresh
   ```
   This generates `pack.toml`, `index.toml`, and a `mods/*.pw.toml` file per mod,
   plus copies your `config/` into `overrides/`.

3. **Fix the client/server split.** `import` sets each mod's `side` from Modrinth
   metadata, which is mostly right but not always. Review [docs/SIDE_FLAGS.md](docs/SIDE_FLAGS.md)
   and correct any with `packwiz env set <mod> <client|server|both>`.

4. **Commit and push** to a **public** GitHub repo:
   ```
   git add -A && git commit -m "Initial pack import"
   git remote add origin https://github.com/rgevers/geverscraft-modpack.git
   git push -u origin main
   ```

Your pack.toml is now reachable at:
`https://raw.githubusercontent.com/rgevers/geverscraft-modpack/master/pack.toml`
— that URL is what both players and the server point at.

---

## Day-to-day: changing the pack

```
packwiz mr add <modrinth-slug>     # add a mod (e.g. packwiz mr add sodium)
packwiz update <mod>               # bump one mod
packwiz update --all               # bump everything
packwiz remove <mod>               # remove a mod
packwiz refresh                    # rebuild index.toml after editing overrides/
git commit -am "..." && git push   # ship it
```

`git log` is your changelog; tag releases you care about: `git tag v1.1.0 && git push --tags`.
A bad update is just `git revert`.

---

## Distributing to players

Give each player a **Prism Launcher** instance (best) or the **Modrinth App**:

- **Prism (auto-sync, recommended):** create an instance on NeoForge 26.2, then
  add a pre-launch command running packwiz-installer against the pack URL. On
  every launch it pulls only what changed — you push, they relaunch, done.
  See https://packwiz.infra.link/tutorials/installing/prism/
- **Modrinth App (simple):** hand them a `packwiz modrinth export` `.mrpack` to
  import. Fine for occasional updates; less automatic than the Prism flow.

---

## Deploying to the server

The server is bootstrapped from this same pack and slots into the `mcctl` /
`minecraft@.service` setup on the EC2 box. See [server/install-server.sh](server/install-server.sh):

1. Copy the script to the box, edit the variables at the top (server name,
   exact NeoForge build, the pack.toml URL, heap size).
2. Run it as the `minecraft` user — it installs the NeoForge server, does the
   first mod sync, and writes the `start` script the systemd template calls.
3. Configure `server.properties` (**enable RCON with a password** so `mcctl`
   can save-and-stop gracefully), then add the server to `robobobot`'s
   `servers.json` and `mcctl start <name>`.

The generated `start` script re-syncs mods from the pack on every launch, so
`/mc start <name>` always boots the current pack version. Comment that line out
if you'd rather pin the server and update it deliberately.
