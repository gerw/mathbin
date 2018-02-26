<?php

/*
	Script for finding and downloading a PDF or PS for a given 
	Digital Object Identifier (DOI), which usually points to a website 
	containing a link to the actual file.
	
	Usage:    php doi2pdf.php DOI [filename]
	
	If filename is omitted the raw PDF/PS is written to standard output
	
	Example:  php doi2pdf.php 10.1016/j.orl.2012.11.009 paper.pdf

	Authors: Felix Ospald <felix.ospald@mathematik.tu-chemnitz.de>
	Version: 2017.1
	Licence: GPL v3
*/

define('APP_VERSION', '2017.1');

// this regular expression is used to check a link-tag to be a PDF candidate
define('PDF_REGEXP', '/\W(PDF|PS|Full Text)\W/i');

function parse_cookies($header) {
	
	$cookies = array();
	
	$cookie = new cookie();
	
	$parts = explode("=",$header);
	for ($i=0; $i< count($parts); $i++) {
		$part = $parts[$i];
		if ($i==0) {
			$key = $part;
			continue;
		} elseif ($i== count($parts)-1) {
			$cookie->set_value($key,$part);
			$cookies[$key] = $cookie;
			continue;
		}
		$comps = explode(" ",$part);
		$new_key = $comps[count($comps)-1];
		$value = substr($part,0,strlen($part)-strlen($new_key)-1);
		$terminator = substr($value,-1);
		$value = substr($value,0,strlen($value)-1);
		$cookie->set_value($key,$value);
		if ($terminator == ",") {
			$cookies[$key] = $cookie;
			$cookie = new cookie();
		}
		
		$key = $new_key;
	}
	return $cookies;
}

class cookie {
	public $name = "";
	public $value = "";
	public $expires = "";
	public $domain = "";
	public $path = "";
	public $secure = false;
	
	public function set_value($key,$value) {
		switch (strtolower($key)) {
			case "expires":
				$this->expires = $value;
				return;
			case "domain":
				$this->domain = $value;
				return;
			case "path":
				$this->path = $value;
				return;
			case "secure":
				$this->secure = ($value == true);
				return;
		}
		if ($this->name == "" && $this->value == "") {
			$this->name = $key;
			$this->value = $value;
		}
	}
}

function contains_location($line)
{
	return preg_match('/^Location:/i', $line);
}

function contains_cookie($line)
{
	return preg_match('/^Set-Cookie:/i', $line);
}

function filter_count_greater_zero($match)
{
	return ($match['count'] > 0);
}

function filter_valid_url($match)
{
	return !preg_match('/(^$|#.*|onclick=.*|javascript:)/', $match[2]);
}

function compute_hit_measure($match)
{
	return ($match['count']/(1.0 + $match['similarity'] + $match['pos_rank']));
}

function order_by_relevance($match1, $match2)
{
	$d = $match1['already_visited'] - $match2['already_visited'];
	if ($d != 0) {
		return $d;
	}

	return ($match1['hit_measure'] < $match2['hit_measure']);
}

function clean_url($url)
{
	$url = trim($url);

	// strip off any leading and tailing ' or " pairs
	$url = preg_replace("#^'(.*)'$#", '\1', $url);
	$url = preg_replace('#^"(.*)"$#', '\1', $url);

	$url = trim($url);

	return $url;
}

function relocate_url($url, $loc)
{
	$loc = preg_replace("/[\r\n\t]/", "", $loc);

	// skip page links
	if (substr($loc, 0, 1) == '#') {
		return $url;
	}
	
	return rel2abs($loc, $url);
}

function rel2abs($rel, $base)
{
	//echo "rel2abs($rel, $base)\n";
	if(strpos($rel,"//")===0) return "http:".$rel;
	/* return if  already absolute URL */
	if  (parse_url($rel, PHP_URL_SCHEME) != '') return $rel;
	/* queries and  anchors */
	if ($rel[0]=='#'  || $rel[0]=='?') return $base.$rel;
	/* parse base URL  and convert to local variables:
	$scheme, $host,  $path */
	extract(parse_url($base));
	/* remove  non-directory element from path */
	$path = preg_replace('#/[^/]*$#',  '', $path);
	/* destroy path if  relative url points to root */
	if ($rel[0] ==  '/') $path = '';
	/* dirty absolute  URL */
	$path = preg_replace('#/$#', '', $path);
	$rel = preg_replace('#^/#', '', $rel);
	$abs =  "$host$path/$rel";
	/* replace '//' or  '/./' or '/foo/../' with '/' */
	//$re =  array('#(/\.?/)#', '#/(?!\.\.)[^/]+/\.\./#');
	//for($n=1; $n>0;  $abs=preg_replace($re, '/', $abs, -1, $n)) {}
	/* absolute URL is  ready! */
	return  $scheme.'://'.$abs;
}

function url_get_contents_curl($url, $options)
{
	$ch = curl_init();
	curl_setopt($ch, CURLOPT_URL, $url);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	$html = curl_exec($ch);
	curl_close($ch);
	$headers = array();
	return array($html, $headers);
}

function url_get_contents_php($url, $options)
{
	$context = stream_context_create($options);
	$html = file_get_contents($url, false, $context);
	if ($html === false) {
		return array(null, array());
	}
	return array($html, $http_response_header);
}

function url_get_contents($url, $options)
{
	write_info(sprintf("Fetching %s", color_url($url)));
	write_debug($options);

//	if (function_exists('curl_init')) {
//		return url_get_contents_curl($url, $options);
//	}
	
	return url_get_contents_php($url, $options);
}

function color_text($text, $color, $close=true)
{
	$color_map = array(
		'green' => '1;32',
		'red' => '1;31',
		'blue' => '1;34',
		'cyan' => '1;36',
		'white' => '1;37',
		'purple' => '1;35'
	);
	$color = $color_map[$color];
	return sprintf("\033[%sm%s%s", $color, $text, $close ? "\033[0m" : "");
}

function color_url($url)
{
	return color_text($url, 'purple');
}

function clean_text($text)
{
	if (is_array($text)) {
		ob_start();
		var_dump($text);
		return ob_get_clean();
	}
	return $text;
}

function write_info($text)
{
	global $STDERR;
	$text = clean_text($text);
	$text = sprintf("INFO: %s\n", $text);
	fwrite($STDERR, color_text($text, 'white'));
}

function write_error($text)
{
	global $STDERR;
	$text = clean_text($text);
	$text = sprintf("ERROR: %s\n", $text);
	fwrite($STDERR, color_text($text, 'red'));
}

function write_debug($text)
{
	global $STDERR, $DEBUG;
	if (!$DEBUG) return;
	$text = clean_text($text);
	$text = sprintf("DEBUG: %s\n", $text);
	fwrite($STDERR, color_text($text, 'blue'));
}

function scan_for_pdf($doi, $url, $save_filename, $nrecurse = 2, $cookies = array())
{
	global $g_fetched, $STDOUT, $DEBUG;
	
	if ($nrecurse < 0) {
		write_info("Maximum recursion depth reached");
		return 1;
	}

	if (count($g_fetched) > 20) {
		write_info("Maximum scan count reached");
		return 1;
	}
	
	// get html content and also add the cookies to the request
	// some server check for a user agent, so we set some header values here
	$header = array(
		'User-Agent: Mozilla/5.0 (Windows NT 5.1; rv:23.0) Gecko/20100101 Firefox/23.0',
	//  'User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.12) Gecko/20101026 Firefox/3.6.12',
	//  'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
	//  'Accept-Language: en-us,en;q=0.5',
	//  'Accept-Encoding: gzip,deflate',
	//  'Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7',
	//  'Keep-Alive: 115',
	//  'Connection: keep-alive',
	);
	$opts = array(
		'http'=>array(
			'method' => "GET",
			'header' => (implode("\r\n", $header) . "\r\n"),
			'follow_location' => false, // don't follow redirects
			'ignore_errors' => true
		)
	);
	foreach ($cookies as $cookie) {
		$opts['http']['header'] .= 'Cookie: ' . $cookie->name . '=' . $cookie->value . "\r\n";
	}

	// skip duplicate requests
	$req_id = md5(serialize(array('url' => $url, 'opts' => $opts)));
	if (isset($g_fetched[$req_id])) {
		write_info(sprintf("Already visited %s", color_url($url)));
		return 1;
	}
	$g_fetched[$req_id] = $url;
	$g_fetched[$url] = $url;
	
	// get the html of the document
	list($html, $http_response_header) = url_get_contents($url, $opts);
	if ($html === false) {
		write_error(sprintf("Get contents failed for: %s", color_url($url)));
		return 1;
	}
	#write_debug($html);

	// check response code
	if (isset($http_response_header[0])) {
		$parts = explode(' ', $http_response_header[0]);
		if (isset($parts[1]) && is_numeric($parts[1])) {
			$code = intval($parts[1]);
			if ($code >= 400) {
				// does not make sense to continue
				return $code;
			}
		}
	}

	// check for file magic
	$magic = substr($html, 0, 5);
	if ($magic == '%PDF-' || $magic == '%!PS-') {
		write_info(sprintf("PDF/PS found at %s", color_url($url)));
		if (!empty($save_filename)) {
			write_info(sprintf("Writing contents to %s", color_url($save_filename)));
			if (file_exists($save_filename)) {
				global $options;
				if (isset($options["f"])) {
					write_info("File already exisits: overwriting...");
				}
				else {
					write_error("File already exisits: use option -f to overwrite existing files");
					return -1;
				}
			}
			file_put_contents($save_filename, $html);
		}
		else {
			write_info(sprintf("Writing contents to %s", color_url('STDOUT')));
			fwrite($STDOUT, $html);
		}
		return 0;
	}
	
	// add new cookies
	$old_cookie_count = count($cookies);
	$xcookies = array_filter($http_response_header, "contains_cookie");
	foreach ($xcookies as $cookie) {
		$cookie = trim(substr($cookie, strlen("Set-Cookie:")));
		$acookies = parse_cookies($cookie);
		foreach ($acookies as $c) {
			$cookies[$c->name] = $c;
		}
	}
	
	write_debug("Resoponse header:");
	write_debug($http_response_header);
	#write_debug("Cookies:");
	#write_debug($cookies);

	// get new location from response header
	$locs = array_filter($http_response_header, "contains_location");
	if (count($locs) > 0) {
		// compute relocation url
		$old_url = $url;
		foreach ($locs as $loc) {
			$loc = clean_url(substr($loc, strlen("Location:")));
			$url = relocate_url($url, $loc);
			write_debug(sprintf("Relocate found: %s", color_url($url)));
		}
		write_debug(sprintf("Relocating to %s", color_url($url)));
		// if cookies were added, do the request again, since they are	
		// not handeled correctly for multiple relocates
		//if (count($cookies) > $old_cookie_count) {
		//	write_info("Cookies detected, requesting again");
		//	return scan_for_pdf($doi, $url, $save_filename, $nrecurse, $cookies);
		//}
		// reload if url changed and html is empty
		if ($url != $old_url) {
			$r = scan_for_pdf($doi, $url, $save_filename, $nrecurse, $cookies);
			return min($r, 1);
		}
	}

	// get all links of page including name and url
	$patterns = array("<a\s[^>]*href\s*=\s*[^\s](\"??)([^\" >]*?)\\1[^>]*>(.*)<\/a>",
		"<frame\s[^>]*src\s*=\s*[^\s](\"??)([^\" >]*?)\\1[^>]*>(.*)<",
		"<iframe\s[^>]*src\s*=\s*[^\s](\"??)([^\" >]*?)\\1[^>]*>(.*)<");
	
	if ($DEBUG) {
		$fn = tempnam("/tmp", "doi2pdf");
		file_put_contents($fn, $html);
		write_debug("Response written to: " . $fn . "\n");
	}

	foreach ($patterns as $regexp)
	{
		if(!preg_match_all("/$regexp/siU", $html, $matches, PREG_SET_ORDER)) {
			write_debug("no match for " . $regexp . "\n");
			continue;
		}

		// filter matches having valid url
		$matches = array_filter($matches, "filter_valid_url");

		// clean up
		foreach($matches as $key => $match) {
			foreach($match as $k => $v) {
				if ($k != 2) $v = preg_replace('/\s+/i', ' ', $v);
				$v = trim($v);
				$matches[$key][$k] = $v;
			}
		}

		// compute the keyword occurence in each link
		foreach($matches as $key => $match) {
			$match_url = $match[2];
			$match_html = $match[0];
			$match_title = $match[3];
			$matches[$key]['count'] = preg_match_all(PDF_REGEXP, $match_html, $m, PREG_SET_ORDER);
			$matches[$key]['key'] = $key;
			$matches[$key]['similarity'] = levenshtein(substr($doi, 0, 255), substr($match_url, 0, 255), 1, 2, 3);
			$matches[$key]['pos'] = strpos($html, $match_url);
			$link = clean_url($match_url);
			$link = relocate_url($url, $link);
			$matches[$key]['url'] = $link;
			$matches[$key]['title'] = $match_title;
			$matches[$key]['html'] = $match_html;
			$matches[$key]['already_visited'] = isset($g_fetched[$link]) ? 1 : 0;
			unset($matches[$key][0]);
			unset($matches[$key][1]);
			unset($matches[$key][2]);
			unset($matches[$key][3]);
		}

		// print matches for debugging
		foreach ($matches as $key => $match) {
			write_debug("unfiltered match $key: " . print_r($match, true) . "\n");
		}

		// filter links having at least one match
		$matches = array_filter($matches, "filter_count_greater_zero");
		
		// compute position rank and hit measure
		$positions = array();
		foreach($matches as $key => $match) {
			$positions[] = $matches[$key]['pos'];
		}
		foreach($matches as $key => $match) {
			$matches[$key]['pos_rank'] = array_search($matches[$key]['pos'], $positions);
			$matches[$key]['hit_measure'] = compute_hit_measure($matches[$key]);
		}

		//echo "matches;\n"; print_r($matches);

		// sort by matches by relevance
		uasort($matches, "order_by_relevance");

		// print matches for debugging
		foreach ($matches as $key => $match) {
			write_debug("match $key: " . print_r($match, true) . "\n");
		}
		
		// filter matches containing PDF
		foreach ($matches as $match) {
			$link = $match['url'];
			// perform recursive scan
			$ret = scan_for_pdf($doi, $link, $save_filename, $nrecurse-1, $cookies);
			if ($ret <= 0) {
				return $ret;
			}
		}
	}
	
	return 1;
}

function intro()
{
	$w = stream_get_wrappers();
	
	write_info(sprintf("This is doi2pdf %s!", APP_VERSION));

	$no = color_text("no", "red", false);
	$yes = color_text("yes", "green", false);
	write_info("checking for php wrappers (should be all yes):");
	write_info(sprintf(" - openssl: %s", extension_loaded('openssl') ? $yes : $no . " (please install an OpenSSL enabled PHP version, e.g. php5-openssl)"));
	write_info( sprintf(" - http:    %s", in_array('http', $w) ? $yes : $no . " (please set allow_url_fopen to 1 in your php.ini)"));
	write_info(sprintf(" - https:   %s", in_array('https', $w) ? $yes : $no . " (please enable the php_openssl extension in your php.ini)"));
}

// *****************************************************************************

// open stderr and stdout
$STDOUT = fopen("php://stdout", "w");
$STDERR = fopen("php://stderr", "w");

intro();

// parse arguments
$options = getopt("hdf", ["help", "debug", "force"]);

// debug switch
$DEBUG = isset($options["d"]);

// check for arguments
if (count($argv) <= 1 || isset($options["h"])) {
	write_info("Usage: ${argv[0]} DOI [filename]");
	write_info("will try and retrieve the PDF file for the DOI given and save it to filename or writes to stdout if filename is omitted.");
	write_info("Options: -d, --debug enables debug mode.");
	write_info("         -f, --force allows to overwrite existing file.");
	write_info("         -h, --help shows this help.");
	exit(1);
}

// build the doi url
$url = trim($argv[count($options)+1]);
$parts = parse_url($url);
if (empty($parts['scheme']) || $parts['scheme'] == 'doi') {
	$url = "http://dx.doi.org/" . $parts['path'];
}

// run
$g_fetched = array();
$filename = @$argv[count($options)+2];
$r = scan_for_pdf($parts['path'], $url, $filename);
if ($r > 0) {
	if ($r == 404) {
		write_error(sprintf("DOI not found (%d)", $r));
	}
	else {
		write_error("Failed to find any suitable document");
	}
}

// return exit code
exit($r);

