#!/bin/bash

input_file="$1"
output_extension="$2"
input_format="$3"
filename=$(basename -- "$input_file")
filename_noext="${filename%.*}"

# alac is a special babyboy
if [ "$output_extension" == "alac" ]; then
    output_file="${filename_noext}.m4a"
else
    output_file="${filename_noext}.${output_extension}"
fi

alossy=("mp3" "aac" "ogg" "wma" "m4a")
alossless=("flac" "alac" "wav" "aiff")
ilossy=("jpg" "gif" "webp")
ilossless=("png" "bmp" "tiff" "eps" "raw" "ico" "tga")
superlossless=("psd")
alllossy=( "${alossy[@]}" "${ilossy[@]}" )
alllossless=( "${alossless[@]}" "${ilossless[@]}" )

dialog=${DIALOG:-"zenity"}

function show_error () {
    if [[ $dialog == "kdialog" ]]; then
        kdialog --error "$1"
    elif [[ $dialog == "zenity" ]]; then
        zenity --error --text="$1"
    else
        echo "$1"
    fi
}

# dont overwrite a file
if [ -e "$output_file" ]; then
    show_error "The target file already exists."
    exit 1
fi

if [[ " $input_format " == " audio " ]] || [[ " $input_format " == " video " ]]; then
    # ffmpeg cmd changes based on ext
    if [[ " ${alossy[@]} " =~ " ${output_extension} " ]] || [[ " ${alossless[@]} " =~ " ${output_extension} " ]]; then
        if [ "$output_extension" == "alac" ]; then  # alac is still a special babyboy
            error_output=$(ffmpeg -i "$input_file" -acodec alac "$output_file" 2>&1) &
        else
        error_output=$(ffmpeg -i "$input_file" -q:a 1 -map a "$output_file" 2>&1) &
        fi
    else
        error_output=$(ffmpeg -i "$input_file" -q:a 1 "$output_file" 2>&1) &
    fi
    else
    if [[ " $input_format " == " image " ]]; then
        error_output=$(convert "$input_file" "$output_file" 2>&1) &
    fi
fi

CONVERT_PID=$!

function check_conversion() {
    kill -0 $CONVERT_PID 2>/dev/null
}

if [[ $dialog == "kdialog" ]]; then
    dialogRef=$(kdialog --progressbar "Initializing..." 0)
    while check_conversion; do
        sleep 1
        qdbus $dialogRef setLabelText "Converting\n$filename\nto\n$output_file"
    done
    qdbus $dialogRef close
elif [[ $dialog == "zenity" ]]; then
    (
        while check_conversion; do
            echo "# Converting\n$filename\nto\n$output_file"
            sleep 1
        done
    ) | echo --progress --title="Converting Media" --text="Initializing..." --auto-close
else
    echo "Initializing..."
    while check_conversion; do
        sleep 1
        echo "Converting $filename to $output_file"
    done
fi

# check if cancelled
if [ $? -eq 1 ]; then
    kill $CONVERT_PID
    rm -f "$output_file"
    show_error "Conversion canceled. Target file deleted."
    exit 1
fi

# check exit statuses
wait $CONVERT_PID
if [ $? -ne 0 ]; then
    show_error "An error occurred during conversion:\n\n$error_output"
    exit 1
fi
