#!/bin/bash
# This script downloads and reasonably renames (pdf and rtf) documents 
# from the DFG web site associated with a particular funding instrument.
#
# Get help and usage examples via 
#   get_DFG_documents.sh 

# Set debugging flag
_DEBUG=0

# Declare intelligent debug function
# from http://www.cyberciti.biz/tips/debugging-shell-script.html
function DEBUG()
{
 [ "$_DEBUG" -ne "0" ] && $@
}

function NODEBUG()
{
 [ "$_DEBUG" -eq "0" ] && $@
}

# Declare a function which lists some information about all documents
function list()
{
	for i in ${!formNr[@]}; do
		printf -- '%-14s %-4s %-2s %-7s %-30s\n' "${formNr[$i]}" "${formFileType[$i]}" "${formLanguage[$i]}" "${formDate[$i]}" "${formTitle[$i]}"
	done
}

# Issue help message if necessary
if [ $# = 0 ] || [[ $# -gt 1 && $2 != "list" && $2 != "get" ]]; then
	echo
	echo "Usage:   $(basename $0) URL                                         (lists all documents, no downloads)"
	echo "Usage:   $(basename $0) URL list                                    (lists all documents, no downloads)"
	echo "Usage:   $(basename $0) URL get [doc number 1] [doc number 2]       (retrieves documents whose numbers are given, in all languages)"
	echo "Usage:   $(basename $0) URL get de [doc number 1] en [doc number 2] (retrieves some documents in German, some in English)"
	echo "Usage:   $(basename $0) URL get .                                   (retrieves all forms)"
	echo
	echo "Example: $(basename $0) https://www.dfg.de/foerderung/programme/einzelfoerderung/sachbeihilfe/formulare_merkblaetter/index.jsp"
	echo "Example: $(basename $0) https://www.dfg.de/foerderung/programme/einzelfoerderung/sachbeihilfe/formulare_merkblaetter/index.jsp list"
	echo "Example: $(basename $0) https://www.dfg.de/foerderung/programme/einzelfoerderung/sachbeihilfe/formulare_merkblaetter/index.jsp get 52.01 '60.12 -2018-'"
	echo "Example: $(basename $0) https://www.dfg.de/foerderung/programme/einzelfoerderung/sachbeihilfe/formulare_merkblaetter/index.jsp get de 52.01 '60.12 -2018-'"
	echo "Example: $(basename $0) https://www.dfg.de/foerderung/programme/einzelfoerderung/sachbeihilfe/formulare_merkblaetter/index.jsp get en 52.01 de '60.12 -2018-'"
	echo "Example: $(basename $0) https://www.dfg.de/foerderung/programme/einzelfoerderung/sachbeihilfe/formulare_merkblaetter/index.jsp get de '60.12$"
	echo "Example: $(basename $0) https://www.dfg.de/foerderung/programme/einzelfoerderung/sachbeihilfe/formulare_merkblaetter/index.jsp get de '^1\.'"
	echo
	echo "Document numbers are interpreted as bash regular expressions."
	echo "Downloaded documents will be given reasonable names."
	echo
	exit 1
fi

# Download the URL into a temporary file
URL=$1
DOWNLOAD=$(mktemp) 
DEBUG echo Download file $DOWNLOAD
wget --quiet $URL -O $DOWNLOAD 

# Typical relevant records look like this (spaces not to scale) [:shudder:] 
#
# Example for a pdf document
# <td class="first"><span>50.01</span></td>
# <td><abbr title="Deutsch"><span class="contentType">de<span></span></span></abbr></td>
#   <td class="titel"><strong>Merkblatt Programm Sachbeihilfe [10/11]</a></strong></td>
#   <td><a href="http://www.dfg.de/formulare/50_01/50_01_de.pdf">PDF</a></td>
#
# Example for a pdf and rtf document
# <td class="first"><span>54.011</span></td>
#   <td><abbr title="Deutsch"><span class="contentType">de<span></span></span></abbr></td>
#   <td class="titel">Daten zum Antrag und Verpflichtungen - Projektantr&auml;ge (nur f&uuml;r Programme, in denen eine Antragstellung &uuml;ber das elan-Portal noch nicht m&ouml;glich ist) [03/18]</a></td>
#   <td><a href="http://www.dfg.de/formulare/54_011/54_011_de.pdf">PDF</a>, <a href="http://www.dfg.de/formulare/54_011/54_011_de_rtf.rtf">RTF</a></td>
#
# Example for a jsp link, which we do not follow up on
# <td class="first"><span>2.00</span></td>
#   <td><abbr title="Deutsch"><span class="contentType">de<span></span></span></abbr></td>
#   <td class="titel"><a href="http://www.dfg.de/formulare/2_00/index.jsp">Verwendungsrichtlinien - Allgemeine Bedingungen f&uuml;r F&ouml;rdervertr&auml;ge mit der Deutschen Forschungsgemeinschaft e.V. (DFG)</a></td>
#   <td><a href="http://www.dfg.de/formulare/2_00/index.jsp"></a></td>
#
# Example for documents with title containing a stray <span> tag
# <td class="first"><span>21.40</span></td>
#   <td><abbr title="Deutsch"><span class="contentType">de<span></span></span></abbr></td>
#   <td class="titel"><span size=&quot;5&quot;>Antrag für Großgeräte in Forschungsbauten </span>nach Art. 91b GG [03/18]</a></td>
#   <td><a href="http://www.dfg.de/formulare/21_40/21_40_de.pdf">PDF</a>, <a href="http://www.dfg.de/formulare/21_40/21_40_de_rtf.rtf">RTF</a></td>

# Define the start pattern to recognize a relevant entry
# Make sure that quantifiers are non-greedy and / properly escaped
# https://docstore.mik.ua/orelly/perl/cookbook/ch06_16.htm
STARTPATTERN='<td class="first"><span>.*?</span></td>'
STARTPATTERN=$(echo $STARTPATTERN | awk '{gsub(/\//,"\\/",$0);} 1')
DEBUG echo "START" $STARTPATTERN
DEBUG echo

# Define an awk program which filters out chunks of four lines, each beginning with the start pattern
PROGFILTER="/$STARTPATTERN/ {for (i=1; i<=4; i++) {print; getline}}"
DEBUG echo $PROGFILTER
DEBUG echo

# Define an awk program to replace multiple spaces by just one
PROGREDUCESPACES='{gsub(/ [ ]+/," ",$0);} 1'

# Define an awk program to beautify and decode some HTML stuff
PROGHTMLDECODE='{
	# replace HTML umlaut encodings to plain umlauts 
	gsub(/&Auml;/,"Ä");
	gsub(/&Ouml;/,"Ö");
	gsub(/&Uuml;/,"Ü");
	gsub(/&auml;/,"ä");
	gsub(/&ouml;/,"ö");
	gsub(/&uuml;/,"ü");
	gsub(/&szlig;/,"ß");
	gsub(/&quot;/,"");
	gsub(/&ndash;/,"-");
	gsub(/&nbsp;/," ");
	print
}'

# Define an awk program to remove lines containing links to jsp files
PROGNOJSP='!/\.jsp/'

# Define an intermediate file 
INTERMEDIATE=$(mktemp) 

# Let awk do its magic to filter the relevant lines, remove duplicate spaces, decode HTML stuff, and paste chunks of four lines into one
# Then remove lines linking to non-directly downloadable content, i.e., other jsp files (Verwendungsrichtlinien)
awk "$PROGFILTER" $DOWNLOAD | awk "$PROGREDUCESPACES" - | awk "$PROGHTMLDECODE" - | paste -d ' ' - - - - | tr -d "\r" | awk "$PROGNOJSP" - > $INTERMEDIATE

# gvim -p $DOWNLOAD $INTERMEDIATE
# exit 2

# Create the search pattern for regular downloadable documents
LINEPATTERN='<td class="first"><span>(.*)</span></td>\s*<td><abbr title="[a-zA-Z]+"><span class="contentType">(..)<span></span></span></abbr></td>\s*<td class="titel">(<strong>)?(.*) (\[.*\])</a>(</strong>)?</td>\s*<td><a href="([^>]*)">([A-Z]{3,4})</a>(, <a href="([^>]*)">([A-Z]{3,4})</a>)?</td>'
LINEPATTERN='<td class="first"><span>(.*)</span></td>\s*<td><abbr title="[a-zA-Z]+"><span class="contentType">(..)<span></span></span></abbr></td>\s*<td class="titel">(<span size=[^>]*>)?(<strong>)?([^<]*)(</span>)?(.*) (\[.*\])</a>(</strong>)?</td>\s*<td><a href="([^>]*)">([A-Z]{3,4})</a>(, <a href="([^>]*)">([A-Z]{3,4})</a>)?</td>'

# Extract the relevant pieces of information from each line
i=0
while read LINE; do
	DEBUG echo "Raw line:    " ${LINE}
	if [[ ${LINE} =~ ${LINEPATTERN} ]]; then
		formNr[$i]=${BASH_REMATCH[1]}
		formLanguage[$i]=${BASH_REMATCH[2]}
		formTitle[$i]=${BASH_REMATCH[5]}${BASH_REMATCH[7]}
		formDate[$i]=${BASH_REMATCH[8]}
		formURL[$i]=${BASH_REMATCH[10]}
		formFileType[$i]=${BASH_REMATCH[11]} 
		formURLSecond=${BASH_REMATCH[13]}
		formFileTypeSecond=${BASH_REMATCH[14]} 
		# Canonicalize the form date 
		# [07/10] -> [20100700]
		# [2018]  -> [20180000]
		date_pattern1='\[([[:digit:]]{2})/([[:digit:]]{2})\]'
		date_pattern2='\[([[:digit:]]{4})\]'
		if [[ "${formDate[$i]}" =~ $date_pattern1 ]]; then
			month=${BASH_REMATCH[1]}
			year=20${BASH_REMATCH[2]}
		elif [[ "${formDate[$i]}" =~ $date_pattern2 ]]; then
			year=${BASH_REMATCH[1]}
			month=00
		else
			echo ERROR parsing date "${formDate[$i]}"
			exit 1
		fi
		formDateCanonicalized[$i]=$year$month"00"
		# Canonicalize the form number (replace hyphens, spaces)
		formNrCanonicalized[$i]=${formNr[$i]}
		formNrCanonicalized[$i]=${formNrCanonicalized[$i]// /_}  # replace spaces by underscores
		formNrCanonicalized[$i]=${formNrCanonicalized[$i]//-/}   # remove hyphens (as in '60.12 -2012-')
		# Canonicalize the form title (replace hyphens, spaces)
		formTitleCanonicalized[$i]=${formTitle[$i]}
		formTitleCanonicalized[$i]=${formTitleCanonicalized[$i]// /_}    # replace spaces by underscores
		formTitleCanonicalized[$i]=${formTitleCanonicalized[$i]//_-/}    # remove '_-' (as in 'Leitfaden für die Antragstellung - Projektanträge')
		formTitleCanonicalized[$i]=${formTitleCanonicalized[$i]//_\/_/_} # replace '_/_' by '_' ( as in 'Antrag auf Reparatur / Ersatz / Ergänzung einer DFG-Leihgabe')
		formTitleCanonicalized[$i]=${formTitleCanonicalized[$i]//\//_}   # replace '/' by '_' ( as in 'SFB/Transregio')
		# Canonicalize the file type (to lower case)
		formFileTypeCanonicalized[$i]=$(echo ${formFileType[$i]} | tr '[:upper:]' '[:lower:]')
		DEBUG echo "Form number:               " ${formNr[$i]}
		DEBUG echo "Form number canonicalized: " ${formNrCanonicalized[$i]}
		DEBUG echo "Form language:             " ${formLanguage[$i]}
		DEBUG echo "Form title:                " ${formTitle[$i]}
		DEBUG echo "Form title canonicalized:  " ${formTitleCanonicalized[$i]}
		DEBUG echo "Form date:                 " ${formDate[$i]}
		DEBUG echo "Form date canonicalized:   " ${formDateCanonicalized[$i]}
		DEBUG echo "Form URL:                  " ${formURL[$i]}
		DEBUG echo "Form file type:            " ${formFileType[$i]}
		DEBUG echo "Form 2nd URL:              " ${formURLSecond}
		DEBUG echo "Form 2nd file type:        " ${formFileTypeSecond}
		DEBUG echo
	else
		echo "ERROR parsing line" ${LINE}
		echo "in $INTERMEDIATE"
		exit 1
	fi
	(( i++ ))
	# If we have a second entry on the same line (like pdf and rtf), create an individual entry for it
	if [ ! -z "${formURLSecond}" ]; then
		formNr[$i]=${formNr[$i-1]}
		formNrCanonicalized[$i]=${formNrCanonicalized[$i-1]}
		formLanguage[$i]=${formLanguage[$i-1]}
		formTitle[$i]=${formTitle[$i-1]}
		formTitleCanonicalized[$i]=${formTitleCanonicalized[$i-1]}
		formDate[$i]=${formDate[$i-1]}
		formDateCanonicalized[$i]=${formDateCanonicalized[$i-1]}
		formURL[$i]=${formURLSecond}
		formFileType[$i]=${formFileTypeSecond} 
		formFileTypeCanonicalized[$i]=$(echo ${formFileType[$i]} | tr '[:upper:]' '[:lower:]')
		(( i++ ))
	fi
done < $INTERMEDIATE

# If no download links were found at all, exit
if [ $i -eq 0 ]; then
	echo No download links found.
	echo It appears that $URL does not exist, or it is not of the expected type.
	NODEBUG rm $DOWNLOAD
	NODEBUG rm $INTERMEDIATE
	exit 1
fi

# If no arguments except for the URL are given, list all the forms found and exit
if [ $# = 1 ] || [[ $2 == "list" ]]; then
	list
	NODEBUG rm $DOWNLOAD
	NODEBUG rm $INTERMEDIATE
	exit 0
fi

# If the command 'get' is given, continue to parse all further arguments
if [ $2 == "get" ]; then
	# Default to documents in both languages
	en=1
	de=1
	# Eat two arguments before list of documents to be retrieved
	shift
	shift
	while [[ $# -gt 0 ]]
	do
		key=$1
		DEBUG echo Parsing $key
		case $key in
			# Switch to English documents from now on only
			en)
			en=1
			de=0
			;;
			# Switch to German documents from now on only
			de)
			en=0
			de=1
			;;
			# Expect a document number to be downloaded
			*)
			# Loop over all forms
			for i in ${!formNr[@]}; do
				# Try to find the key in its title
				# If the language is among the desired languages, download it
				if [[ ${formNr[$i]} =~ $key ]] && [[ $(eval echo \$${formLanguage[$i]}) == 1 ]]; then
					filename=${formDateCanonicalized[$i]}_${formNrCanonicalized[$i]}_${formLanguage[$i]}_${formTitleCanonicalized[$i]}.${formFileTypeCanonicalized[$i]}
					echo Downloading ${formNr[$i]} in language ${formLanguage[$i]} from ${formURL[$i]} as $filename
					wget --quiet ${formURL[$i]} --output-document $filename || exit 1
				fi
			done
			;;
	esac
		shift
	done
	didSomething=1
fi

# Exit (keeping temporary files), or clean up and exit
DEBUG exit 0

# Clean up and exit
rm $DOWNLOAD
rm $INTERMEDIATE
exit 0

