#!/bin/bash
# Background launcher: ./start_plamo.sh <0.8b|2b|8b|31b>
set -u

PROJECT_DIR="$HOME/MyProject"
PYTHON="$PROJECT_DIR/plamo-mlx-env/bin/python"
GUI_SCRIPT="$PROJECT_DIR/bin/translate_gui.py"
STATE_DIR="$HOME/Library/Application Support/PLaMoTranslate"
PID_FILE="$STATE_DIR/server.pid"
MODEL_FILE="$STATE_DIR/model_size"
LOG_FILE="$STATE_DIR/server.log"
LOCK_DIR="$STATE_DIR/start.lock"
URL="http://127.0.0.1:7860/"

mkdir -p "$STATE_DIR"

alert() {
    /usr/bin/osascript - "$1" <<'APPLESCRIPT'
on run argv
    display alert "PLaMo Translate" message (item 1 of argv) as warning
end run
APPLESCRIPT
}

is_running() {
    [[ -f "$PID_FILE" ]] || return 1
    local pid command
    pid=$(/bin/cat "$PID_FILE" 2>/dev/null) || return 1
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    /bin/kill -0 "$pid" 2>/dev/null || return 1
    command=$(/bin/ps -ww -p "$pid" -o command= 2>/dev/null) || return 1
    [[ "$command" == *"$GUI_SCRIPT"* ]]
}

if [[ $# -ne 1 ]]; then
    alert "モデルサイズを指定してください (0.8b / 2b / 8b / 31b)。"
    exit 2
fi
SIZE="$1"
case "$SIZE" in
  0.8b|2b|8b|31b) ;;
  *) alert "指定されたモデルが無効です: $SIZE"; exit 2 ;;
esac
MODEL_DIR="$PROJECT_DIR/lib/plamo-3-translate-${SIZE}-MLX-4bit"

if [[ ! -x "$PYTHON" || ! -f "$GUI_SCRIPT" ]]; then
    alert "Python環境または翻訳プログラムがありません。~/MyProject を確認してください。"
    exit 1
fi
if [[ ! -f "$MODEL_DIR/config.json" ]]; then
    alert "モデルが見つかりません: $MODEL_DIR"
    exit 1
fi

locked=0
for ((i=0; i<50; i++)); do
    if /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
        locked=1
        break
    fi
    /bin/sleep 0.2
done
if (( locked == 0 )); then
    alert "起動ロックが解除されません。ログを確認してください。"
    exit 1
fi
trap '/bin/rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

if is_running; then
    current_size=$(/bin/cat "$MODEL_FILE" 2>/dev/null || true)
    if [[ "$current_size" != "$SIZE" ]]; then
        alert "現在 ${current_size:-別の} モデルが起動中です。翻訳画面の終了ボタンで停止してから選択してください。"
        exit 1
    fi
else
    if /usr/sbin/lsof -nP -iTCP:7860 -sTCP:LISTEN >/dev/null 2>&1; then
        alert "7860番ポートは別のプログラムが使用しています。"
        exit 1
    fi

    echo "=== $(/bin/date) | PLaMo $SIZE ===" >> "$LOG_FILE"
    /usr/bin/nohup "$PYTHON" -u "$GUI_SCRIPT" --model-size "$SIZE" \
        >> "$LOG_FILE" 2>&1 < /dev/null &
    echo $! > "$PID_FILE"
    echo "$SIZE" > "$MODEL_FILE"
fi

/bin/rmdir "$LOCK_DIR" 2>/dev/null || true
trap - EXIT

# Keep wait reasonably generous for the 31B model.
for ((i=0; i<300; i++)); do
    if ! is_running; then
        alert "モデルの起動に失敗しました。server.logを確認してください。"
        exit 1
    fi
    if /usr/bin/curl -fsS --connect-timeout 1 --max-time 2 "$URL" >/dev/null 2>&1; then
        /usr/bin/open "$URL"
        exit 0
    fi
    /bin/sleep 2
done
alert "起動確認がタイムアウトしました。server.logを確認してください。"
exit 1
