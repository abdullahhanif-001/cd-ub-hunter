#!/usr/bin/env bash
# install-from-tar.sh — extract to /opt/cd-ub with gates + systemd caps; NEVER wipe; NEVER touch PM2
set -euo pipefail

TAR_PATH="${1:-}"
if [[ -z "$TAR_PATH" ]] || [[ ! -f "$TAR_PATH" ]]; then
  echo "Usage: $0 /path/to/cd-ub-<sha>.tar.gz"
  exit 1
fi

ROOT=/opt/cd-ub
INCOMING=/opt/cd-ub-incoming
mkdir -p "$INCOMING"

# Disk / RAM gates
AVAIL_G="$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')"
MEM_G="$(awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)"
python3 - <<PY
avail=float("${AVAIL_G}")
mem=float("${MEM_G}")
assert avail >= 40.0, f"disk avail {avail}G < 40G"
assert mem >= 3.5, f"mem avail {mem}G < 3.5G"
print(f"GATES_OK disk={avail}G mem={mem}G")
PY

# Preserve previous marker
if [[ -d "$ROOT" ]]; then
  mkdir -p "${ROOT}/previous"
  date -u >"${ROOT}/previous/replaced-at.txt"
fi

TMP="$(mktemp -d)"
tar -xzf "$TAR_PATH" -C "$TMP"
# find extracted root (files at top of tar)
if [[ -d "$TMP/vendor" ]]; then
  SRC="$TMP"
else
  SRC="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"
fi

mkdir -p "$ROOT"
# Preserve runtime dirs
KEEP_BASE=0; [[ -d "$ROOT/baseline" ]] && KEEP_BASE=1 && mv "$ROOT/baseline" /tmp/cdub-baseline-$$ || true
KEEP_WORK=0; [[ -d "$ROOT/work" ]] && KEEP_WORK=1 && mv "$ROOT/work" /tmp/cdub-work-$$ || true
rm -rf "$ROOT"
mkdir -p "$ROOT"
cp -a "$SRC"/. "$ROOT"/
[[ "$KEEP_BASE" = 1 ]] && rm -rf "$ROOT/baseline" && mv /tmp/cdub-baseline-$$ "$ROOT/baseline" || true
[[ "$KEEP_WORK" = 1 ]] && rm -rf "$ROOT/work" && mv /tmp/cdub-work-$$ "$ROOT/work" || true

mkdir -p "$ROOT/baseline" "$ROOT/work" "$ROOT/reports/live" "$ROOT/previous"
chmod +x "$ROOT"/deploy/contabo/*.sh "$ROOT"/scripts/oneclick/*.sh 2>/dev/null || true

# Snapshot baseline BEFORE clang/build
bash "$ROOT/deploy/contabo/snapshot-baseline.sh"
bash "$ROOT/deploy/contabo/pm2-guard.sh"

# systemd unit with caps
cat >/etc/systemd/system/cd-ub.service <<'UNIT'
[[Unit]]
Description=CD-UB CompDiff worker (VPS isolated)
After=network.target

[[Service]]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/cd-ub
EnvironmentFile=/opt/cd-ub/config/ephemeral.env
Nice=5
CPUQuota=50%
MemoryMax=2.5G
CPUAffinity=2 3
TasksMax=512
# No start payload by default — oneclick runs manually
ExecStart=/bin/true
ExecStop=/bin/true

[[Install]]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable cd-ub.service
systemctl start cd-ub.service

bash "$ROOT/deploy/contabo/pm2-guard.sh"
echo "INSTALL_OK $ROOT"
echo "systemctl show cd-ub.service -p CPUQuota -p MemoryMax -p Nice" 
systemctl show cd-ub.service -p CPUQuota -p MemoryMax -p Nice 2>/dev/null || true
