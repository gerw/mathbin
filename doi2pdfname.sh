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
# echo $tmpfile, http://dx.doi.org/$1

curl -sL -H "Accept: application/vnd.crossref.unixsd+xml" http://dx.doi.org/$1 > $tmpfile

# Parse xml and output filename
doi2pdfname.py $tmpfile

# remove tmpfile
rm $tmpfile
