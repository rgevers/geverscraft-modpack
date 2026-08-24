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
   git push -u origin master
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

## Bumping versions

Three kinds of version live in this repo. Each bumps a different way.

### Mods (packwiz-managed)

Most mods carry an `[update.modrinth]` block, so packwiz bumps them for you:

```
packwiz update --all               # or: packwiz update <mod>
packwiz refresh
git commit -am "Update mods" && git push
```

Clients pick up the new mods on their next launch. The server picks them up on
its next restart (its `start` script re-syncs every launch).

### Matcha Flavoured (manual pin, TWO files)

Matcha Flavoured ships as one zip that acts as both a resource pack and a
datapack, so it lives in the pack **twice**. Both files must point at the same
version, or the server and client drift:

- `resourcepacks/matcha-resourcepack.pw.toml` — `side = "client"`.
- `datapacks/matcha-datapack.pw.toml` — `side = "both"` (this is the copy the
  **server** syncs).

Both are **hand-written** pins with no `[update]` block, so `packwiz update` skips
them. The Modrinth project (id `QI0EmgZ1`) blocks third-party downloads, so
`packwiz modrinth add` refuses it. Bump both by hand:

1. On the Modrinth project page, copy the new version's download URL. It looks
   like `https://cdn.modrinth.com/data/QI0EmgZ1/versions/<VERSION_ID>/<file>.zip`.
2. Get the file hash without downloading the zip: open
   `https://api.modrinth.com/v2/version/<VERSION_ID>` and copy the file's
   **sha512** value. (The Modrinth API gives sha1 and sha512, not sha256.)
3. Edit **both** `resourcepacks/matcha-resourcepack.pw.toml` **and**
   `datapacks/matcha-datapack.pw.toml`: set `filename`, `url` (drop any
   `?mr_download_reason=...` query), `hash-format = "sha512"`, and `hash`. Keep
   each file's own `side` value.
4. `packwiz refresh`, then commit and push.

### NeoForge loader (manual, three places that must match)

packwiz does **not** manage the loader. Its version lives in three spots, and all
three must hold the same build:

1. `pack.toml` → `[versions] neoforge` — drives each **client** install.
2. `server/install-server.sh` → `NEOFORGE_VERSION` — drives the **server** install.
3. This README, "Option B" step 2 — the number a new player types in Prism.

To bump the loader:

1. Confirm the build exists at
   `https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml`.
2. Edit all three places above to the new build. Run `packwiz refresh`. Commit and
   push.
3. If the bump also changes Minecraft, edit `minecraft` in `pack.toml` too, then
   run `packwiz update --all` and check every mod has a build for the new version
   before you ship.
4. Update each **running client** — see "Updating an existing instance to a new
   loader" below.
5. Update the **server** — see "Upgrading the loader on a running server" below.

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
2. **Add Instance → NeoForge → Minecraft `26.2` → loader `26.2.0.67`**
   (this must match `neoforge` in `pack.toml`; tick "show beta versions" in the
   version list only if you pin a beta build).
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

### Updating an existing instance to a new loader

`packwiz-installer` syncs mods and configs only — it never changes NeoForge. When
the pack moves to a new loader build, update each instance by hand:

1. Right-click the instance → **Edit**.
2. Open the **Version** tab.
3. Select the **NeoForge** row → **Change version** → pick the new build (match
   `neoforge` in `pack.toml`) → **OK**.
4. **Launch.** `packwiz-installer` then syncs mods on top of the new loader.

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

### Upgrading the loader on a running server

Mods auto-sync every restart, but the **NeoForge loader does not**. The loader is
installed only at bootstrap, and its version is baked into the generated `start`
script. So a loader bump needs a re-run of `install-server.sh` on the box. Push
the repo change first (the script is fetched from `master`), then, as the
`ec2-user`, with `<name>` = the live server (for example `server26adv`):

```
# Find the Java 25 path (MC 26.2 needs Java 25).
J="$(ls -d /usr/lib/jvm/java-25-amazon-corretto*/bin/java 2>/dev/null | head -1)"; "$J" -version

mcctl stop <name>

# Fetch the current script and confirm it carries the new loader build.
curl -fSL -o /tmp/install-server.sh https://raw.githubusercontent.com/rgevers/geverscraft-modpack/master/server/install-server.sh
grep -E '^NEOFORGE_VERSION=' /tmp/install-server.sh

# Set the two variables and run it.
sed -i "s#^SERVER_NAME=.*#SERVER_NAME=\"<name>\"#; s#^JAVA_BIN=.*#JAVA_BIN=\"$J\"#" /tmp/install-server.sh
sudo bash /tmp/install-server.sh

# The run uses sudo, so hand the files back to the service user, then start.
sudo chown -R minecraft:minecraft /opt/minecraft/<name>
mcctl start <name>

# Confirm the log names the new loader build.
grep -i "neoforge" /opt/minecraft/<name>/logs/latest.log | head
```

The re-run installs the new loader and rewrites `start` to point at it. The world
and `server.properties` are not touched.
