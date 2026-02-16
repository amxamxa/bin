#!/usr/bin/env bash

# Default-Text setzen, falls kein Argument übergeben wurde
text="${1:-Hallo, Welt!}"

# Fontliste holen (ab Zeile 4)
fonts=$(figlist | tail -n +4)

for f in $fonts; do
    # Testen, ob Font funktioniert
    if figlet -tcf "$f" "test" >/dev/null 2>&1; then
        echo "===== FONT: $f ====="
        
        # Ausgabe mit Farben, Fehler unterdrückt
        figlet -tcf "$f" "$text" 2>/dev/null | lolcat | clolcat
        
        echo
        sleep 0.1
    fi
done
