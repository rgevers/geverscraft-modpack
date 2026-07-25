#!/usr/bin/env bash
#
# One-time bootstrap of a NeoForge dedicated server for the geverscraft modpack.
# Produces /opt/minecraft/<SERVER_NAME>/ with a `start` script that the
# minecraft@.service systemd template launches (ExecStart=/opt/minecraft/%i/start).
#
# Run as the `minecraft` user (or chown -R minecraft:minecraft afterwards).
#
set -euo pipefail

# ------------------------- fill these in -------------------------
SERVER_NAME="modpack"                # -> /opt/minecraft/<name>, and `mcctl start <name>`
NEOFORGE_VERSION="26.2.0.32-beta"    # EXACT loader build (from the .mrpack dependencies)
PACK_URL="https://raw.githubusercontent.com/rgevers/geverscraft-modpack/master/pack.toml"
XMX="10G"                            # Java heap. Your 1.21.1 server uses 12G; 10G leaves a bit
                                     # more off-heap headroom for this heavier modded pack
JAVA_BIN="java"                      # MC 26.2 needs Java 25! set to the Corretto 25 path,
                                     # e.g. /usr/lib/jvm/java-25-amazon-corretto/bin/java
# -----------------------------------------------------------------

ROOT="/opt/minecraft/${SERVER_NAME}"
INSTALLER="neoforge-${NEOFORGE_VERSION}-installer.jar"
BOOTSTRAP_URL="https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar"

echo ">> Creating ${ROOT}"
mkdir -p "${ROOT}"
cd "${ROOT}"

echo ">> Installing NeoForge server ${NEOFORGE_VERSION}"
curl -fSL -o "${INSTALLER}" \
  "https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/${INSTALLER}"
"${JAVA_BIN}" -jar "${INSTALLER}" --installServer
rm -f "${INSTALLER}" "${INSTALLER}.log"

echo ">> Fetching packwiz-installer bootstrap"
curl -fSL -o packwiz-installer-bootstrap.jar "${BOOTSTRAP_URL}"

echo ">> Syncing server-side mods from the pack"
"${JAVA_BIN}" -jar packwiz-installer-bootstrap.jar -g -s server "${PACK_URL}"

echo ">> Writing JVM args and accepting the Minecraft EULA"
# Tuned G1GC ("Aikar's flags"), matching the existing 1.21.1 server; heap = $XMX
echo "-Xmx${XMX} -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1" > user_jvm_args.txt
echo "eula=true" > eula.txt          # you are accepting https://aka.ms/MinecraftEULA

echo ">> Writing start script"
cat > start <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "\$(dirname "\$0")"

# Auto-update mods from the pack on every start. Comment out to pin the server
# and update only when you deliberately re-run the sync.
"${JAVA_BIN}" -jar packwiz-installer-bootstrap.jar -g -s server "${PACK_URL}"

# Launch the NeoForge dedicated server.
exec "${JAVA_BIN}" @user_jvm_args.txt @libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt nogui
EOF
chmod +x start

cat <<EOF

Done. Next steps:
  1. Start once to generate server.properties, then stop it.
  2. Edit ${ROOT}/server.properties:
       server-port=25565
       enable-rcon=true
       rcon.port=25575
       rcon.password=<a strong password>       # required for mcctl graceful stop
     then: chmod 600 server.properties
  3. Confirm it appears:  mcctl list      (should show: ${SERVER_NAME})
  4. Add it to robobobot's servers.json, redeploy the bot, and:
       mcctl start ${SERVER_NAME}
EOF
