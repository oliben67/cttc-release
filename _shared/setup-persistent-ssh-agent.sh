#!/usr/bin/env bash
# Sets up a persistent ssh-agent on this host, at a fixed socket path, so the
# cttc-gateway container's SSH_AUTH_SOCK mount (see docker-compose.yml) keeps
# working across reboots/logouts instead of silently going stale the moment
# a forwarded-agent ssh session ends.
#
# Run this ONCE, directly on the Docker-enabled host that runs the
# cttc-gateway container -- not on your client machine, and not over the
# tunnel CTTC itself opens (ssh in with your own account first).
#
# What it does:
#   - installs a systemd --user service that runs `ssh-agent` at a fixed
#     socket path (survives reboot: `loginctl enable-linger` + WantedBy=
#     default.target keeps it running without you being logged in)
#   - writes/updates cttc-gateway/.env with SSH_AUTH_SOCK=<that path>, so
#     `docker compose up` picks it up on every future run regardless of
#     which shell/session invokes it (interactive, or the ssh exec CTTC's
#     "Update server image" / "Run Setup" use) -- this is what actually
#     removes the dependency on a live forwarded-agent session.
#
# After running this, you still need to `ssh-add` the key that reaches your
# target host(s) into the persistent agent (see the printed instructions) --
# once now, and again after any reboot (the agent restarts automatically via
# systemd, but ssh-add itself doesn't persist keys across that).
set -euo pipefail

if ! command -v systemctl >/dev/null 2>&1; then
  echo "error: this host has no systemd (systemctl not found) -- this script only supports systemd hosts." >&2
  exit 1
fi

SOCK="$HOME/.ssh/agent.sock"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/cttc-ssh-agent.service"
COMPOSE_DIR="$HOME/cttc-gateway"   # matches server-provision.js's remoteDir

mkdir -p "$UNIT_DIR" "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

cat > "$UNIT" <<EOF
[Unit]
Description=Persistent ssh-agent for CTTC's docker -H ssh:// support

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=$SOCK
ExecStartPre=/bin/rm -f $SOCK
ExecStart=/usr/bin/ssh-agent -D -a $SOCK
Restart=on-failure

[Install]
WantedBy=default.target
EOF

echo "Enabling lingering, so this keeps running after you log out..."
loginctl enable-linger "$(whoami)" 2>/dev/null || sudo loginctl enable-linger "$(whoami)"

systemctl --user daemon-reload
systemctl --user enable --now cttc-ssh-agent.service

mkdir -p "$COMPOSE_DIR"
if [[ -f "$COMPOSE_DIR/.env" ]] && grep -q '^SSH_AUTH_SOCK=' "$COMPOSE_DIR/.env"; then
  sed -i.bak "s#^SSH_AUTH_SOCK=.*#SSH_AUTH_SOCK=$SOCK#" "$COMPOSE_DIR/.env" && rm -f "$COMPOSE_DIR/.env.bak"
else
  echo "SSH_AUTH_SOCK=$SOCK" >> "$COMPOSE_DIR/.env"
fi

cat <<EOF

Persistent ssh-agent running at: $SOCK
  (managed by: systemctl --user status cttc-ssh-agent.service)
$COMPOSE_DIR/.env now sets SSH_AUTH_SOCK for every future 'docker compose up' there.

Next: add the key that reaches your target host(s) to this agent --
  SSH_AUTH_SOCK=$SOCK ssh-add ~/.ssh/id_ed25519

Verify it's loaded:
  SSH_AUTH_SOCK=$SOCK ssh-add -l

Note: the agent itself restarts automatically after a reboot (systemd), but
the key you ssh-add'd does not -- re-run the ssh-add command above after any
reboot of this host.
EOF
