#!/bin/bash
# Przełącza persistence mode karty NVIDIA: przy każdym uruchomieniu raz włącza,
# raz wyłącza. Włączony trzyma kartę wybudzoną, żeby whisper nie tracił ~3 s
# na start CUDA (koszt: ok. 3–5 W więcej na baterii). Działa do restartu
# komputera lub usługi nvidia-persistenced.
#
# Razem z włączeniem persistence mode podnosi w tle whisper-server (whisper.cpp)
# z modelem large-v3-turbo, z którego korzysta claude_voice.sh.
# Przy wyłączeniu najpierw zatrzymuje serwer (zwalnia pamięć GPU), a potem
# wyłącza persistence mode. Serwer działa jako zwykły użytkownik, nie root.
#
# Hasło pyta okno KDE przez pkexec (polkit). Nie używamy kdesu: działa przez sudo
# i nie rozpoznaje prośby o hasło z sudo-rs (Ubuntu), więc wisi bez okna.
#
# Wymagane paczki apt: pkexec, libnotify-bin (notify-send), curl
# whisper-server (whisper.cpp) instalowany osobno, musi być w ~/.local/bin lub w PATH.

# Skróty KDE dziedziczą PATH sesji Plasmy, który nie zawiera ~/.local/bin (tam jest whisper-server)
export PATH="$HOME/.local/bin:$PATH"

WHISPER_DIR="$HOME/github/whisper.cpp"
WHISPER_MODEL="$WHISPER_DIR/models/ggml-large-v3-turbo.bin"
# Port musi się zgadzać z WHISPER_URL w claude_voice.sh
# (nie 8080 — domyślny port whisper-server łatwo koliduje z innymi usługami)
WHISPER_PORT=8178
SERVER_PID_FILE="/tmp/whisper_server.pid"
SERVER_LOG="/tmp/whisper_server.log"

state() { nvidia-smi -q | awk -F': ' '/Persistence Mode/ {print $2; exit}'; }

server_running() {
    [ -f "$SERVER_PID_FILE" ] && kill -0 "$(cat "$SERVER_PID_FILE")" 2>/dev/null
}

start_server() {
    if server_running; then
        return 0
    fi
    # nohup: serwer nie ginie razem ze skrótem KDE, który uruchomił skrypt.
    # (Bez setsid — przy włączonej kontroli zadań forkuje się i $! wskazywałby zły proces.)
    nohup whisper-server -m "$WHISPER_MODEL" -l pl -nt \
        --host 127.0.0.1 --port "$WHISPER_PORT" >"$SERVER_LOG" 2>&1 < /dev/null &
    echo $! > "$SERVER_PID_FILE"

    # Serwer zaczyna nasłuchiwać dopiero po wczytaniu modelu do GPU — czekamy do 60 s
    for _ in $(seq 600); do
        if ! server_running; then
            rm -f "$SERVER_PID_FILE"
            return 1
        fi
        curl -sf -o /dev/null "http://127.0.0.1:$WHISPER_PORT/" && return 0
        sleep 0.1
    done
    return 1
}

stop_server() {
    if server_running; then
        local pid
        pid=$(cat "$SERVER_PID_FILE")
        kill "$pid"
        # Czekamy aż proces faktycznie się zakończy i zwolni kartę
        for _ in $(seq 50); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$pid" 2>/dev/null
    fi
    rm -f "$SERVER_PID_FILE"
}

if [ "$(state)" = "Enabled" ]; then
    MODE=0; WANT=Disabled; MSG="Karta NVIDIA może znów zasypiać (persistence mode i whisper-server wyłączone)"
else
    MODE=1; WANT=Enabled;  MSG="Karta NVIDIA wybudzona (persistence mode włączony, whisper-server działa na porcie $WHISPER_PORT)"
fi

# Przy wyłączaniu: najpierw serwer, żeby nie trzymał karty
[ "$MODE" = 0 ] && stop_server

pkexec /usr/bin/nvidia-smi -pm "$MODE"

if [ "$(state)" != "$WANT" ]; then
    notify-send "NVIDIA" "Nie udało się zmienić persistence mode" -i dialog-error -t 4000
    exit 1
fi

if [ "$MODE" = 1 ]; then
    notify-send "NVIDIA" "⏳ Uruchamianie whisper-server ..." -i video-display -t 2000
    if ! start_server; then
        notify-send "NVIDIA" "Persistence mode włączony, ale whisper-server nie wystartował (log: $SERVER_LOG)" -i dialog-error -t 5000
        exit 1
    fi
fi

notify-send "NVIDIA" "$MSG" -i video-display -t 2000
