#!/bin/bash
# Install a weekly launchd job on this Mac that refreshes assets/json/scholar.json.
#
# Google Scholar blocks GitHub's servers, so the update runs from this Mac instead.
# The job works in its own clone (not your working copy) and pushes only when the
# numbers changed. Run this once; run it again to update the job.
set -euo pipefail

LABEL="io.github.adrienbanse.scholar-stats"
DIR="$HOME/Library/Application Support/scholar-stats"
REPO_URL="https://github.com/adrienbanse/adrienbanse.github.io.git"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$DIR"
if [ ! -d "$DIR/repo/.git" ]; then
  git clone -q "$REPO_URL" "$DIR/repo"
fi

if [ ! -x "$DIR/venv/bin/python" ]; then
  /usr/bin/python3 -m venv "$DIR/venv"
fi
"$DIR/venv/bin/pip" install -q --disable-pip-version-check scholarly==1.7.11 "bibtexparser<2"

cat > "$DIR/run.sh" <<'EOF'
#!/bin/bash
# Weekly Google Scholar stats update. Set DRY_RUN=1 to fetch without committing.
set -euo pipefail
DIR="$HOME/Library/Application Support/scholar-stats"
cd "$DIR/repo"
echo "=== $(date '+%Y-%m-%d %H:%M:%S')"
git fetch -q origin master
git reset -q --hard origin/master
"$DIR/venv/bin/python" -W ignore .github/scripts/scholar_stats.py assets/json/scholar.json
if git diff --quiet -- assets/json/scholar.json; then
  exit 0
fi
if [ "${DRY_RUN:-0}" = "1" ]; then
  git --no-pager diff --stat -- assets/json/scholar.json
  git checkout -q -- assets/json/scholar.json
  exit 0
fi
git add assets/json/scholar.json
git commit -q -m "update Google Scholar stats"
git push -q origin HEAD:master
echo "pushed $(git rev-parse --short HEAD)"
EOF
chmod +x "$DIR/run.sh"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$DIR/run.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>1</integer>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin</string>
  </dict>
  <key>StandardOutPath</key>
  <string>$DIR/log.txt</string>
  <key>StandardErrorPath</key>
  <string>$DIR/log.txt</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $LABEL: runs every Monday at 09:00, log in $DIR/log.txt"
