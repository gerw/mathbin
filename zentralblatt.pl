#!/usr/bin/perl -w

# zentralblatt.PL - automates getting bibtex references from Zentralblatt
#
# Authors:      Michael Tweedale <m.tweedale@bristol.ac.uk>
#               Gerd Wachsmuth <gerd.wachsmuth@mathematik.tu-chemnitz.de>
# Version:      0.2
# Licence:      GPL

use LWP::UserAgent;
use URI::URL;
use URI::Escape;
use Getopt::Long;

$mirror = "http://www.zbmath.org/";

$VERSION='0.2';
$search="?q=";
$sep = "";
$ua=new LWP::UserAgent;
$hdrs=new HTTP::Headers(Accept => 'text/html',
  User_Agent => "zentralblatt.PL $VERSION");

sub version()
{
  print STDERR << "EOF";
zentralblatt $VERSION
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
Gets references from Zentralblatt in bibtex format.

-t, --title    phrase from the title of the article or book
-a, --author   name of one of the authors
-y, --year     year of publication (ranges possible)
-s, --source   source data (see zentralblatt)
    --help     display this help and exit
    --version  output version information and exit

Example 1: $0 -t "free+groups" -t trees -a bestvina -y 1997
Example 2: $0 -a serre -s annals -y 1955-
Example 3: $0 -a brown -s "graduate texts" -y -2000
EOF
}

sub addterm($$)
{
  $search .= $sep . uri_escape($_[0]) . ":\"" . uri_escape($_[1]) . "\"";
	$sep = " %26 ";
}

sub addyear($)
{
	if( $_[0] =~ /-/ ) {
		# A range of years is given.
		@years = split(/-+/,$_[0]);
		if( $#years == 0 )
		{
			$years[1] = "9999";
		}
		if( $years[0] =~ /^$/ )
		{
			$years[0] = "1000";
		}
	}
	else {
		# A single year is given.
		$years[0] = $_[0];
		$years[1] = $_[0];
	}
	$search .= $sep . "py:(" . $years[0] . "-" . $years[1] . ")";
	$sep = " %26 ";
}

GetOptions('title|t=s' => sub { addterm("ti",$_[1]); },
  'author|a=s' => sub { addterm("au",$_[1]); },
  'source|s=s' => sub { addterm("so",$_[1]); },
  'year|y=s' => sub { addyear($_[1]); },
  'help|h' => sub { usage(); exit 0; },
  'version|v' => sub { version(); exit 0; });

$search ne "search/?q=" || usage() && die("no search terms found");
$url=new URI::URL(
    "$mirror$search");

$req=new HTTP::Request(GET, $url, $hdrs);
$resp=$ua->request($req);

$resp->is_success ||
  print STDERR $resp->message . "\n" &&
  die("failed to get search results from Zentralblatt");
$resp->as_string =~ /Your query produced no results/ &&
  die("no results for this search");

map {
	if (m{as BibTeX}) {
		s/.*href="([^"]*\.bib)".*/$1/g;
		$url=new URI::URL("$mirror$_");
		$req=new HTTP::Request(GET, $url, $hdrs);
		$resp=$ua->request($req);
		$resp->is_success ||
			print STDERR $resp->message . "\n" &&
			die("failed to get search results from Zentralblatt");
		print $resp->content . "\n\n";
	}
} split "\n", $resp->as_string;
