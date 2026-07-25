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
XMX="6G"                             # Java heap; size to the box (leave headroom for the OS)
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
java -jar "${INSTALLER}" --installServer
rm -f "${INSTALLER}" "${INSTALLER}.log"

echo ">> Fetching packwiz-installer bootstrap"
curl -fSL -o packwiz-installer-bootstrap.jar "${BOOTSTRAP_URL}"

echo ">> Syncing server-side mods from the pack"
java -jar packwiz-installer-bootstrap.jar -g -s server "${PACK_URL}"

echo ">> Writing JVM args and accepting the Minecraft EULA"
echo "-Xmx${XMX}" > user_jvm_args.txt
echo "eula=true" > eula.txt          # you are accepting https://aka.ms/MinecraftEULA

echo ">> Writing start script"
cat > start <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "\$(dirname "\$0")"

# Auto-update mods from the pack on every start. Comment out to pin the server
# and update only when you deliberately re-run the sync.
java -jar packwiz-installer-bootstrap.jar -g -s server "${PACK_URL}"

# Launch the NeoForge dedicated server.
exec java @user_jvm_args.txt @libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt nogui
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
