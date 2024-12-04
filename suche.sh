#!/usr/bin/env bash
# auth:______max__kempter_______ 
# filename:______NIXbuild.sh 

# Überprüfen, ob Suchpfad und Suchmuster als Argumente übergeben wurden
echo "Suchst du eine Datei (f) oder einen Pfad (p):"
while true; do
    read -r FOP
    case $FOP in
        [fF] )
            echo "OK, wir suchen eine Datei!"
            echo
            break;;
        
        [pP] )
            echo "OK, wir suchen einen Pfad!"
            echo
            break;;
        * )
            echo "Bitte entweder f oder p eingeben."
            echo
            ;;
    esac
done

echo "Wo soll gesucht werden?, z. B. /etc"
read -r PFAD
# Überprüfen, ob die Variable mit "/" beginnt
if [[ $PFAD != /* ]]; then
    PFAD="/$PFAD"
    echo
    echo "OK, wir suchen unter $PFAD"
    echo
fi

echo
echo "Was soll gesucht werden?, z. B. shell"
while true; do
    read -r SUCHE

  
echo "Die Variable SUCHE ist: $SUCHE"
# Überprüfung der Länge von SUCHE
if [[ ${#SUCHE} -lt 2 ]]; then
  # Hänge einen Stern an SUCHE an
  SUCHE="${SUCHE}*"
fi

# Überprüfung auf Sonderzeichen (außer *)
if [[ $SUCHE =~ [^a-zA-Z0-9\*] ]]; then
  echo "Fehler: Ungültiges Zeichen in der Suchanfrage!"
else
  echo "Die Suchanfrage ist in Ordnung: $SUCHE"
fi

# Überprüfe, ob das Skript mit fish oder zsh aufgerufen wurde
if [[ "$0" == *fish* ]] || [[ "$0" == *zsh* ]]; then
  # Füge das Präfix "bash -c" hinzu
  TERM="bash -c"
else
	echo
fi


# FIND FUNKTION
	echo "Der Befehl lautet also:"
	    echo "$TERM find $PFAD -type $FOP -name $SUCHE | grep --color=auto -s -I -C 1 $SUCHE"
	    sleep 1
	    echo
command $TERM find $PFAD -type $FOP -name $SUCHE | grep --color=auto -s -I -C 1 $SUCHE
	
done


