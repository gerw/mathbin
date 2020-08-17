#!/bin/bash

# Parse the arguments
if [ ! $# = 1 ]; then
	echo "Usage: $(basename $0) DOI"
	echo 
	echo "$(basename $0) does a crossref query on the given DOI"
	echo "to retrieve the publication metadata. Author names and"
	echo "the title are extracted and a file name is formed."
	exit
fi

# Perform crossref query
# (see http://tdmsupport.crossref.org/researchers/)
tmpfile=/tmp/$RANDOM$RANDOM
# echo $tmpfile, https://doi.org/$1

curl -sL -H "Accept: application/vnd.crossref.unixsd+xml" https://doi.org/$1 > $tmpfile

# Check whether the given file indicates 'DOI not found' error
if grep -q 'Error: DOI Not Found' $tmpfile; then
	echo >&2 "Error: https://doi.org/$1 reports DOI not found."
	exit 1
fi

# Parse xml and output filename
doi2pdfname.py $tmpfile

# remove tmpfile
# rm $tmpfile
