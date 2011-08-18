TEXMAKE=../texmake

(echo "[NOTICE] notice" && echo "[WARNING] warning" && echo "[FATAL] fatal" && echo "no match") | ($TEXMAKE filter "^\[NOTICE\]" | $TEXMAKE color green) 2>&1 | ($TEXMAKE filter "^\[WARNING\]" | $TEXMAKE color yellow) 2>&1 | ($TEXMAKE filter "^\[FATAL\]" | $TEXMAKE color red) 2>&1  | ($TEXMAKE filter "." | $TEXMAKE color cyan )
