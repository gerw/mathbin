#!/bin/bash

# Parse the arguments
if [ ! $# = 1 ]; then
	echo "Usage: $(basename $0) file.pdf"
	echo 
	echo "$(basename $0) renames file.pdf to the name suggested by suggest_pdfname.sh"
	exit
fi

# Show what the name will be
name=$(suggest_pdfname.sh "$1")

if [ -z "$name" ]; then
	exit 1
else
	echo $name
fi

# And rename the file
read -n 1 -p "Rename the file [Y/n]? " answer
if [ -z "$answer" ] || [[ $answer =~ [yY] ]]; then
	echo mv "$1" $(suggest_pdfname.sh "$1")
	mv "$1" $(suggest_pdfname.sh "$1")
else
	echo
fi

