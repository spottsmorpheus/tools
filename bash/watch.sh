#!/bin/bash

declare watchpath=$1
declare capturepath=$2
declare note=$3

if [ -z $watchpath ]; then
    echo "You must supply a folder to watch and Parameter 1"
    exit 1
fi
if [ -z $capturepath ]; then
    declare capturepath="$PWD/capture"
    echo "Captures save in $capturepath"
fi

mkdir -p $capturepath

echo $watchpath - $capturepath - $note

declare capturelog="${capturepath}/capture.log"

declare now="$(date +"%F_%H:%M:%S")"
echo "Watching $watchpath"
echo "Log saved to $capturelog"

# Watch for files created, written and closed - capture file on close
sudo inotifywait -q -m -e close_write -r "$watchpath" 2>&1 |
while read -r folder action file; do
   sudo cp --no-preserve=all -v -u "$folder$file"  "$capturepath/$file"
   declare now="$(date +"%F_%H:%M:%S")"
   echo "$now:$note -- Capturing:  $folder -- $action -- $file" | tee -a $capturelog
done
