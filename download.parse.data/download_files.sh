#!/bin/bash

# FTP server details
FTP_SERVER="ftp.ncbi.nlm.nih.gov"

DIRECTORIES=(
    "comm"
    "noncomm"
    "other"
)
LOCAL_DIR="articles_filelist"

# Ensure the local directory exists
mkdir -p "$LOCAL_DIR"

# Range of PMC IDs to download
DATE="2024-12-18"

# Loop through directories
for DIR in "${DIRECTORIES[@]}"; do

	# Loop through PMC IDs from 0 to 11
	for i in $(seq -w 0 11); do
	    FILENAME="oa_${DIR}_xml.PMC0${i}xxxxxx.baseline.${DATE}.filelist.csv"
	    FTP_DIR="/pub/pmc/oa_bulk/oa_${DIR}/xml/"
	    URL="ftp://${FTP_SERVER}${FTP_DIR}${FILENAME}"
	    LOCAL_FILE="$LOCAL_DIR/$FILENAME"

	    # Skip download if the file already exists
            if [ -f "$LOCAL_FILE" ]; then
            	echo "$FILENAME already exists. Skipping download."
	        continue
            fi

	    echo "Downloading $FILENAME..."
	    wget -P "$LOCAL_DIR" "$URL"

	    if [ $? -eq 0 ]; then
		echo "$FILENAME downloaded successfully."
	    else
		echo "Failed to download $FILENAME."
	    fi

	done
done

# Final file
wget https://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_file_list.csv

echo "Download complete."

