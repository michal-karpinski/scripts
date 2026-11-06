#!/bin/bash
# Wskazanie poprawnej ścieżki do gniazda ydotool
export YDOTOOL_SOCKET=/tmp/.ydotool_socket

PID_FILE="/tmp/claude_voice.pid"
AUDIO_FILE="/tmp/claude_voice.wav"
# Ścieżka do Twojego whisper.cpp
WHISPER_DIR="$HOME/github/whisper.cpp"

if [ -f "$PID_FILE" ]; then
    # --- ZATRZYMANIE NAGRYWANIA I TRANSKRYPCJA ---
    REC_PID=$(cat "$PID_FILE")
    kill "$REC_PID" 2>/dev/null
    # Czekamy aż parecord faktycznie się zakończy i domknie plik WAV
    # (nie jest potomkiem tej powłoki, więc `wait` by nie zadziałał tu) —
    # inaczej whisper-cli czasem czyta niedokończony plik i "halucynuje" tekst.
    while kill -0 "$REC_PID" 2>/dev/null; do
        sleep 0.1
    done
    rm -f "$PID_FILE"

    notify-send "Claude Voice" "⚡ Przetwarzanie ..." -i audio-input-microphone -t 2000

    # Przetwarzanie modelem large-v3-turbo z użyciem GPU
    TEXT=$($WHISPER_DIR/build/bin/whisper-cli -m $WHISPER_DIR/models/ggml-large-v3-turbo.bin -l pl -f $AUDIO_FILE --no-timestamps -nt 2>/dev/null)
    CLEAN_TEXT=$(echo "$TEXT" | xargs)

    if [ -n "$CLEAN_TEXT" ]; then
        # Skopiowanie do schowka Waylanda
        echo -n "$CLEAN_TEXT" | wl-copy
        
        # Wklejenie tekstu (Ctrl + Shift + V) za pomocą ydotool
        ydotool key ctrl+shift+v 2>/dev/null
        
        notify-send "Claude Voice" "✅ Wklejono!" -t 1500
    else
        notify-send "Claude Voice" "⚠️ Nie rozpoznano mowy." -t 2000
    fi

else
    # --- START NAGRYWANIA ---
    notify-send "Claude Voice" "🎙️ Nagrywanie... Mów teraz" -i audio-input-microphone -t 2000
    
    # Nagrywanie dźwięku w tle (przez PipeWire/Pulse, bo sox nie ma sterownika pulseaudio
    # i nagrywanie przez `sox -d` łapało złe/ciche urządzenie ALSA zamiast mikrofonu)
    # Niski --latency-msec, żeby przy zatrzymaniu jak najmniej dźwięku
    # zostało "w locie" w buforze PipeWire i nie ucinało końcówki wypowiedzi.
    parecord --rate=16000 --channels=1 --format=s16le --file-format=wav --latency-msec=10 "$AUDIO_FILE" &
    echo $! > "$PID_FILE"
fi
