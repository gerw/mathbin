#!/bin/bash

# Parse the arguments
# display help message if necessary
if [ ! $# = 1 ] || [ "x$1" = "x--help" ]; then
	echo "Usage: $(basename $0) arXiv"
	echo 
	echo "$(basename $0) queries arXiv for the given article id"
	echo "to retrieve the publication metadata. Author names and"
	echo "the title are extracted and a file name is formed."
	echo
	echo "Example: $(basename $0) 1701.06092v1"
	exit 1
fi

# Get web page from arxiv
tmpfile=/tmp/$RANDOM$RANDOM
# echo "http://arxiv.org/abs/$1"
curl -sL http://arxiv.org/abs/$1 > $tmpfile

# Get title
# Replace space, slash /, apostrophe ', colon : by underscore _
titlepattern="<meta name=\"citation_title\" content=\"([^\"]+)\""
title=$( perl -ne "/$titlepattern/ and print \$1" < $tmpfile | awk '{gsub(" ","_"); gsub("/","_"); gsub("&#x27;","\x27"); gsub(":","_"); gsub("-[-]+","-"); gsub("_[_]+","_"); print}')

# Get authors
authorpattern="<meta name=\"citation_author\" content=\"([^\"]+),.*\""
author=$( perl -ne "/$authorpattern/ and print \$1 . \"_\"" < $tmpfile)
author=$(echo $author | awk '{ gsub ("[ '\'']", "", $0); print}');
# Remove spaces
# Uppercase initial letter and everything after a space
# author=$(echo $author |\
# 	perl -nE '$_ = lc($_); say join " ", map {ucfirst $_} split /\s/' );
# author=$(echo $author |\
# 	awk '{ gsub (" ", "", $0); print}');
# echo $author

# Finalize suggested file name
outfile=${author}_${title}"_PREPRINT.pdf"
echo $outfile

# Clean up and exit
# rm $tmpfile
exit 0

