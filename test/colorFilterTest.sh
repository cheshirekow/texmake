TEXMAKE=../texmake

(echo "[NOTICE] notice" && echo "[WARNING] warning" && echo "[FATAL] fatal" && echo "no match") | $TEXMAKE color-filter "^\[NOTICE\]" green "^\[WARNING\]" yellow "^\[FATAL\]" red "." white

