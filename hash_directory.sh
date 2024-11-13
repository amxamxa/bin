#!/run/current-system/sw/bin/zsh -f


<< 'Explanation'
###########################################################
 Filename   : x                                           #
# Author     : x                                          #
# Created    : x                                          #
# Last edit  : x                                          #
# Purpose    : x                                          #
# Reference  : x                                          #
# Depends    : x                                          #
# Arguments  : x                                          #
# Known bugs : x                                          #
# To do      : x                                          #
############################################################
Explanation


# Überprüfen, ob ein Verzeichnis als Argument angegeben wurde
# Wenn kein Argument übergeben wird, wird eine Fehlermeldung ausgegeben
# und das Skript wird mit einem Fehlercode beendet.
if [ -z "$1" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

# Den absoluten Pfad des Verzeichnisses erhalten.
# `realpath` wird verwendet, um den vollständigen Pfad des Verzeichnisses zu ermitteln,
# unabhängig davon, ob ein relativer Pfad übergeben wurde.
dir=$(realpath "$1")

# Sicherstellen, dass das angegebene Argument ein Verzeichnis ist.
# Wenn das Argument kein Verzeichnis ist, wird eine Fehlermeldung ausgegeben
# und das Skript wird beendet.
if [ ! -d "$dir" ]; then
  echo "Error: $dir is not a directory"
  exit 1
fi

# Die Gesamtanzahl der Dateien im Verzeichnis ermitteln.
# `find` wird verwendet, um alle Dateien im Verzeichnis zu finden,
# und `wc -l` zählt die Anzahl der gefundenen Dateien.
total_files=$(find "$dir" -type f | wc -l)

# Initialisierung eines Zählers.
# Der Zähler wird verwendet, um den Fortschritt der Dateiverarbeitung zu verfolgen.
counter=0

# Funktion zur Anzeige der Fortschrittsanzeige.
# Diese Funktion berechnet den Fortschritt basierend auf der Anzahl der verarbeiteten Dateien
# und druckt eine Fortschrittsanzeige in der Konsole.
display_progress() {
  local progress=$((counter * 100 / total_files))
  local done=$((progress * 4 / 10))
  local left=$((40 - done))
  local fill=$(printf "%${done}s")
  local empty=$(printf "%${left}s")
  
  # Die Fortschrittsanzeige drucken.
  printf "\rProgress : [${fill// /#}${empty// /-}] ${progress}%%"
}

# Die Funktion exportieren, damit sie von der Untershell verwendet werden kann.
# Dies ist erforderlich, da die Funktion innerhalb einer Schleife verwendet wird.
export -f display_progress

# Initialisierung einer temporären Datei zur Speicherung der Hashes.
# `mktemp` erstellt eine temporäre Datei, in der die Hashes der einzelnen Dateien gespeichert werden.
tmpfile=$(mktemp)

# Jede Datei verarbeiten.
# `find` wird verwendet, um alle Dateien im Verzeichnis zu finden und zu sortieren.
# Für jede Datei wird der SHA-256-Hash berechnet und in die temporäre Datei geschrieben.
find "$dir" -type f -print0 | sort -z | while IFS= read -r -d '' file; do
  sha256sum "$file" >> "$tmpfile"
  counter=$((counter + 1))
  # Fortschrittsanzeige aktualisieren.
  display_progress
done

# Den endgültigen Hash der zusammengefügten Hashes berechnen.
# Die temporäre Datei wird sortiert und der SHA-256-Hash der Inhalte wird berechnet.
final_hash=$(sort -z "$tmpfile" | sha256sum | awk '{print $1}')

# Den endgültigen Hash drucken.
# Der endgültige Hash, der den gesamten Verzeichnisinhalt repräsentiert, wird ausgegeben.
echo
echo "Directory Hash: $final_hash"

# Temporäre Datei bereinigen.
# Die temporäre Datei wird gelöscht, nachdem der endgültige Hash berechnet wurde.
rm "$tmpfile"

