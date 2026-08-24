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

Players run a **Prism Launcher** instance whose *pre-launch command* runs
packwiz-installer to auto-sync the pack on every launch. The one catch:
`packwiz-installer-bootstrap.jar` **must live in the instance's `.minecraft`
folder**, or Prism aborts with:

```
Error: Unable to access jarfile packwiz-installer-bootstrap.jar
```

Two ways to set players up. Option A avoids that error entirely.

### Option A — Export once, players import (recommended)

Build one reference instance, then hand out a zip. The bootstrap jar and the
pre-launch command travel *inside* the export, so players place nothing by hand
and the "jar not accessible" error cannot happen.

1. Build a reference instance yourself using **Option B** below, and launch it
   once to confirm it syncs and plays.
2. In Prism: right-click the instance → **Export Instance** → keep `.minecraft`
   checked → save the `.zip`.
3. Send players the zip. They install Prism, then **Add Instance → Import from
   zip** → launch. Done — it self-updates on every launch from then on.

### Option B — Manual setup on a machine

1. Install **Prism Launcher**.
2. **Add Instance → NeoForge → Minecraft `26.2` → loader `26.2.0.32-beta`**
   (tick "show beta versions" in the version list if it's hidden).
3. **Put the bootstrap jar in `.minecraft`** — this is the step that prevents the
   error. Right-click the instance → **Folder** (opens `.minecraft`), and
   download the jar into that folder:
   ```
   https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar
   ```
   Confirm it's ~97 KB (a few hundred bytes means you saved an error page — re-download).
4. **Instance Settings → Custom Commands → enable**, and set the **Pre-launch
   command** — referencing the jar by absolute path via `$INST_MC_DIR` so it's
   found no matter the working directory:
   ```
   "$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" https://raw.githubusercontent.com/rgevers/geverscraft-modpack/master/pack.toml
   ```
5. **Launch.** It downloads the mods/configs/packs, then starts the game.

### Still seeing "Unable to access jarfile"?

The jar isn't where the command is looking. Check, in order:
1. `packwiz-installer-bootstrap.jar` is actually in the instance's `.minecraft`
   folder (right-click → Folder to verify), ~97 KB.
2. The pre-launch command uses `"$INST_MC_DIR/packwiz-installer-bootstrap.jar"`
   (absolute), **not** a bare `packwiz-installer-bootstrap.jar`.
3. On Windows, if the download saved as HTML (tiny file), re-download from the
   direct release URL above rather than a browser "Save link as" on the releases page.

> Alternative for anyone who insists on the Modrinth App: run `packwiz modrinth
> export`, hand them the `.mrpack`, and they import it. No packwiz-installer, but
> updates are manual re-imports rather than automatic.

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
