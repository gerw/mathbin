#!/bin/bash

# Parse the arguments
if [ ! $# = 1 ]; then
	echo "Usage: $(basename $0) file.pdf"
	echo 
	echo "$(basename $0) tries to suggest a reasonable file name for the PDF file"
	echo "specified in the command line." 
	echo "To do so, it tries "
	echo "1. to find the DOI and in the pdfinfo fields,"
	echo "2. to retrieve author names and title from a crossref query,"
	echo "in case the document's DOI can be found  in the PDF file itself;"
	echo "3. to query arXiv in case it is an arXiv preprint file,"
	echo "4. pdfinfo on the file to read at least its title."
	exit
fi

# Try to find an arXiv mark on the first page of the document
# arxiv_line=$(pdftotext -f 1 -l 1 "$1" - | egrep "arXiv:[0-9.]+.*\[[a-z-]+\.[A-Z]+\]")
arxiv_line=$(pdftotext -f 1 -l 1 "$1" - | egrep "arXiv:[0-9.]+")
# echo $arxiv_line
if [ -n "$arxiv_line" ]; then
	arxiv=$(echo $arxiv_line |\
		awk 'match($0,/[0-9]{4}\.[0-9]{4,}([v][0-9]*)?/) { print substr($0,RSTART,RLENGTH)}');
	# echo $arxiv
fi
if [ -n "$arxiv" ]; then
	arxiv2pdfname.sh $arxiv;
	exit 0
fi


# See if pdfinfo has the document's DOI
doi_line=$(pdfinfo "$1" | grep -i doi)
# echo $doi_line
if [ -n "$doi_line" ]; then
	# match the first occurence of at least 10 of the admissible characters
	# NOTE: pattern may be incomplete and not match all possible DOIs
	# NOTE: The pattern will also find dummy DOIs of the form 
	# https://doi.org/10.1145/nnnnnnn.nnnnnnn as, for instance, in 
	# https://arxiv.org/abs/1808.05513v1
	doi=$(echo $doi_line |\
		awk 'match($0,/10\.[a-zA-Z0-9./()-]{10,}/) { print substr($0,RSTART,RLENGTH)}');
	# echo $doi
fi
# If DOI search was successful, run a crossref query on it
if [ -n "$doi" ]; then
	doi2pdfname.sh $doi;
	exit 0
fi


# Try to find the document's DOI on the first page of the document
# (or on the first ten pages when it's a book)
if [[ $1 == *BOOK* ]]; then
	doi_line=$(pdftotext -f 1 -l 10 "$1" - | grep -i doi)
else
	# SIAM journal articles tend to use the word DOI in a funny way so that
	# pdftotext would extract the string "\bfD \bfO \bfI"
	doi_line=$(pdftotext -f 1 -l 2 "$1" - | egrep -i "(doi|\\\bfD \\\bfO \\\bfI|Digital Object Identifier)")
fi;
# echo $doi_line
if [ -n "$doi_line" ]; then
	# match the first occurence of at least 10 of the admissible characters
	# NOTE: pattern may be incomplete and not match all possible DOIs
	doi=$(echo $doi_line |\
		awk 'match($0,/10\.[a-zA-Z0-9./()-]{10,}/) { print substr($0,RSTART,RLENGTH)}');
	# echo $doi
fi
# If DOI search was successful, run a crossref query on it
if [ -n "$doi" ]; then
	doi2pdfname.sh $doi;
	exit 0
fi



# Fallback: try pdfinfo to read the document's title
# (but no author information)
pdfinfo "$@" |\
	grep ^Title |\
	gawk '{split($0,a," "); for( i=2; i<=length(a); i++ ){printf a[i] (i<length(a)?"_":"\n");};}';

