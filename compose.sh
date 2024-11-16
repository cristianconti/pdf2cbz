#!/bin/bash

# Variabile per selezionare il metodo di estrazione
# 1 = pdftoppm
# 2 = pdfimages
# 3 = ImageMagick convert
# 4 = ImageMagick magick
EXTRACTION_METHOD=2

# Directory di lavoro
INPUT_DIR="/takeaway/0convert_in"
TEMP_DIR="/takeaway/0convert_make"
OUTPUT_DIR="/takeaway/0convert_out"

# Parametri di compressione
COMPRESSION_LEVEL=75   # Livello di compressione JPEG (1-100)
RESOLUTION=150         # Risoluzione in DPI per l'estrazione delle immagini (default: 300)

# Pulisci la cartella temporanea
rm -rf "$TEMP_DIR"/*
mkdir -p "$TEMP_DIR"

# Trova tutti i file PDF nella directory di input
find "$INPUT_DIR" -type f -name "*.pdf" | while read -r PDF_FILE; do
    # Ottieni il percorso relativo
    REL_PATH="${PDF_FILE#$INPUT_DIR/}"
    FILE_NAME=$(basename "$REL_PATH" .pdf)
    DIR_NAME=$(dirname "$REL_PATH")

    # Definisci il percorso della cartella di destinazione
    DEST_DIR="$OUTPUT_DIR/$DIR_NAME"
    mkdir -p "$DEST_DIR"

    # Ottieni la dimensione del file PDF di partenza
    PDF_SIZE=$(stat -c %s "$PDF_FILE")
    PDF_SIZE_MB=$(echo "scale=2; $PDF_SIZE/1024/1024" | bc)  # in MB

    # Intestazione
    echo "==================================================="
    echo "Inizio conversione: $FILE_NAME"
    echo "---------------------------------------------------"
    echo "[INFO] Dimensione del file PDF di partenza: $PDF_SIZE_MB MB"
    echo "[INFO] Parametri di compressione: Qualità JPEG $COMPRESSION_LEVEL, Risoluzione $RESOLUTION DPI"
    echo "---------------------------------------------------"

    case $EXTRACTION_METHOD in
        1)
            # Usa pdftoppm per estrarre le immagini
            echo "[INFO] Estraendo immagini con pdftoppm (risoluzione $RESOLUTION DPI)..."
            pdftoppm -jpeg -r $RESOLUTION -jpegopt quality=$COMPRESSION_LEVEL "$PDF_FILE" "$TEMP_DIR/$FILE_NAME"
            ;;
        2)
            # Usa pdfimages per estrarre le immagini
            echo "[INFO] Estraendo immagini con pdfimages..."
            pdfimages -j "$PDF_FILE" "$TEMP_DIR/$FILE_NAME"
            ;;
        3)
            # Usa ImageMagick convert per estrarre le immagini
            echo "[INFO] Estraendo immagini con ImageMagick convert (risoluzione $RESOLUTION DPI)..."
            convert -density $RESOLUTION "$PDF_FILE" "$TEMP_DIR/$FILE_NAME.jpg"
            ;;
        4)
            # Usa ImageMagick magick per estrarre le immagini
            echo "[INFO] Estraendo immagini con ImageMagick magick (risoluzione $RESOLUTION DPI)..."
            magick convert -density $RESOLUTION "$PDF_FILE" "$TEMP_DIR/$FILE_NAME.jpg"
            ;;
        *)
            echo "[ERRORE] Metodo di estrazione non valido!"
            exit 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo "[OK] Immagini estratte da $PDF_FILE"
    else
        echo "[ERRORE] Non è stato possibile estrarre immagini da $PDF_FILE"
        continue
    fi

    # Ottimizza ulteriormente le immagini JPEG
    echo "[INFO] Ottimizzando le immagini JPEG..."
    find "$TEMP_DIR" -type f -name "$FILE_NAME-*.jpg" -exec jpegoptim --max=$COMPRESSION_LEVEL {} \; > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "[OK] Immagini ottimizzate"
    else
        echo "[ERRORE] Non è stato possibile ottimizzare le immagini"
    fi

    # Comprimi le immagini in un file CBZ
    ZIP_FILE="$DEST_DIR/$FILE_NAME.cbz"
    echo "[INFO] Creando l'archivio CBZ..."
    zip -j "$ZIP_FILE" "$TEMP_DIR/$FILE_NAME"-*.jpg > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "[OK] Archivio CBZ creato: $ZIP_FILE"
    else
        echo "[ERRORE] Non è stato possibile creare l'archivio CBZ per $PDF_FILE"
        continue
    fi

    # Ottieni la dimensione del file CBZ
    CBZ_SIZE=$(stat -c %s "$ZIP_FILE")
    CBZ_SIZE_MB=$(echo "scale=2; $CBZ_SIZE/1024/1024" | bc)  # in MB

    # Calcola la differenza di dimensione
    SIZE_DIFF=$(echo "scale=2; ($PDF_SIZE - $CBZ_SIZE) / 1024 / 1024" | bc)

    # Verifica se il file CBZ è valido e più piccolo del PDF originale
    if [ $CBZ_SIZE -gt 0 ] && [ $CBZ_SIZE -lt $PDF_SIZE ]; then
        echo "[INFO] Dimensione del file CBZ risultante: $CBZ_SIZE_MB MB"
        echo "[INFO] Differenza di dimensione: $SIZE_DIFF MB"
        echo "[INFO] Eliminando il file PDF originale..."
        rm "$PDF_FILE"
        if [ $? -eq 0 ]; then
            echo "[OK] File PDF eliminato: $PDF_FILE"
        else
            echo "[ERRORE] Non è stato possibile eliminare il file PDF: $PDF_FILE"
        fi
    else
        echo "[INFO] Il file CBZ non è più piccolo o non è valido. Il file PDF non sarà eliminato."
    fi

    # Pulisci i file temporanei
    rm "$TEMP_DIR/$FILE_NAME"-*.jpg

    echo "---------------------------------------------------"
    echo "[COMPLETATO] Conversione terminata per $FILE_NAME"
    echo "==================================================="
done

# Eliminare sottocartelle vuote nella directory di input
echo "[INFO] Rimuovendo sottocartelle vuote nella directory di input..."
find "$INPUT_DIR" -type d -empty -delete
if [ $? -eq 0 ]; then
    echo "[OK] Sottocartelle vuote rimosse."
else
    echo "[ERRORE] Non è stato possibile rimuovere alcune sottocartelle vuote."
fi
