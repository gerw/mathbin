#!/usr/bin/perl -w

# mathscinet.PL - automates getting bibtex references from MathSciNet
#
# Authors:      Michael Tweedale <m.tweedale@bristol.ac.uk>
#               Gerd Wachsmuth <gerd.wachsmuth@mathematik.tu-chemnitz.de>
# Version:      0.2
# Licence:      GPL

use LWP::UserAgent;
use URI::URL;
use URI::Escape;
use Getopt::Long;

## Select a mirror which is appropriate.
# $mirror = "http://www.ams.org/mathscinet/search/publications.html";
# $mirror = "http://ams.mpim-bonn.mpg.de/mathscinet/search/publications.html";
$mirror = "http://ams.mathematik.uni-bielefeld.de/mathscinet/search/publications.html";

$VERSION='0.2';
$curbox=4; # MathSciNet form has boxes for search terms numbered 4...7
$search="";
$ua=new LWP::UserAgent;
$hdrs=new HTTP::Headers(Accept => 'text/html',
  User_Agent => "mathscinet.PL $VERSION");

sub version()
{
  print STDERR << "EOF";
mathscinet $VERSION
This is free software. You may redistribute copies of it under the terms of
the GNU General Public License <http://www.gnu.org/licenses/gpl.html>.
There is NO WARRANTY, to the extent permitted by law.

Written by Michael Tweedale <m.tweedale\@bristol.ac.uk>,
  Gerd Wachsmuth <gerd.wachsmuth\@mathematik.tu-chemnitz.de>.
EOF
}

sub usage()
{
  print STDERR << "EOF";
Usage: $0 SEARCH...
Gets references from MathSciNet in bibtex format.

-t, --title    phrase from the title of the article or book
-a, --author   name of one of the authors
-y, --year     year of publication (ranges possible)
-j, --journal  journal the article appeared in
-s, --series   series the book appeared in
-m, --MR       Math Reviews number
    --help     display this help and exit
    --version  output version information and exit

Example 1: $0 -t "free+groups" -t trees -a bestvina -y 1997
Example 2: $0 -a serre -j annals -y 1955-
Example 3: $0 -a brown -s "graduate+texts" -y -2000
EOF
}

sub addterm($$)
{
  $curbox<=7 || die("cannot use more than 4 search terms");
  $search .= "&pg$curbox=" . uri_escape($_[0]) . "&s$curbox="
  . uri_escape($_[1]) . "&co$curbox=AND";
  $curbox++;
}

sub addyear($)
{
	if( $_[0] =~ /-/ ) {
		# A range of years is given.
		@years = split(/-+/,$_[0]);
		if( $#years == 0 )
		{
			$years[1] = "";
		}
	}
	else {
		# A single year is given.
		$years[0] = $_[0];
		$years[1] = $_[0];
	}
	$search .= "&dr=pubyear&yearRangeFirst=" . $years[0] . "&yearRangeSecond=" . $years[1]
}

GetOptions('title|t=s' => sub { addterm("TI",$_[1]); },
  'author|a=s' => sub { addterm("AUCN",$_[1]); },
  'journal|j=s' => sub { addterm("JOUR",$_[1]); },
  'series|s=s' => sub { addterm("SE",$_[1]); },
  'MR|m=s' => sub { addterm("MR",$_[1]); },
  'year|y=s' => sub { addyear($_[1]); },
  'help|h' => sub { usage(); exit 0; },
  'version|v' => sub { version(); exit 0; });

$search ne "" || usage() && die("no search terms found");
$url=new URI::URL(
    "$mirror?fmt=bibtex$search");

$req=new HTTP::Request(GET, $url, $hdrs);
$resp=$ua->request($req);

$resp->is_success ||
  print STDERR $resp->message . "\n" &&
  die("failed to get search results from MathSciNet");
$resp->as_string =~ /No publications results/ &&
  die("no results for this search");

map {
  print $_, (( $_=~ '^}') ? "\n\n" : "\n")
    if ((/^\s*<pre>/ .. /^\s*<\/pre>/) && ! m{^\s*</?pre>})
} split "\n", $resp->as_string;

