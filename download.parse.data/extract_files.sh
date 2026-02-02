# Process each subdirectory
for dir in */; do
    # Remove trailing slash for easier handling
    dir=${dir%/}

    echo "Processing directory: $dir"

    # Step 1: Create a copy of the subdirectory
    backup_dir="${dir}_backup"
    cp -r "$dir" "$backup_dir"
    echo "Created backup: $backup_dir"
	
    cd "$dir"

    # Step 2: Extract and rename files in the original subdirectory
    for file in *.tar.gz; do
        echo "Extracting: $file"
        if tar -xzf "$file"; then
            rm "$file"
        else
            echo "Failed to extract: $file"
            continue
        fi

        folder_name="${file%.tar.gz}"
        folder_name="${folder_name##*/}"  # Get only the folder name without path

        if [ -d "$folder_name" ]; then
            cd "$folder_name" || { echo "Cannot enter $folder_name"; continue; }

            nxml_file=$(find . -maxdepth 1 -type f -name "*.nxml")
            if [ -n "$nxml_file" ]; then
                mv "$nxml_file" "../${folder_name}.nxml"
                echo "Renamed and moved: ${folder_name}.nxml"
            else
                echo "No .nxml file found in $folder_name"
            fi

            cd ..
            rm -rf "$folder_name"
            echo "Deleted folder: $folder_name"
        fi
    done
	
	cd ..

    # Step 3: Compare base names in original and backup directories
    original_files=$(find "$dir" -type f -exec basename {} \; | sed 's/\..*$//' | sort)
    backup_files=$(find "$backup_dir" -type f -exec basename {} \; | sed 's/\..*$//' | sort)

    if diff <(echo "$original_files") <(echo "$backup_files") > /dev/null; then
        echo "Base names match for $dir. Removing backup."
        rm -rf "$backup_dir"
    else
        echo "Base names do NOT match for $dir. Backup retained for review."
        diff <(echo "$original_files") <(echo "$backup_files")
    fi

    echo "Finished processing: $dir"
done

