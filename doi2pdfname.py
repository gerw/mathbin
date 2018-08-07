#!/usr/bin/env python

import xml.etree.ElementTree as ET
import sys

import re

tree = ET.parse(sys.argv[1])
root = tree.getroot()

names = []
title = ""

for child in root.iter():
	# print child.tag
	if re.search('(content_item|journal_article)$', child.tag):
		for grandchild in child.iter():
			if re.search('surname$', grandchild.tag):
				name = grandchild.text.strip()
				# make each first letter of a name Uppercase
				name = name.title()
				# remove spaces
				name = name.replace(' ', '')
				names.append(name)
			if title == "" and re.search('title$', grandchild.tag):
				title = grandchild.text.strip()
				# remove double whitespaces
				title = ' '.join(title.split())


filename = '_'.join(names) + "__" + title + ".pdf"

# replace some special characters in filename
items = {
	'/': '_',
	' ': '_'
}
for s, r in items.iteritems():
	filename = filename.replace(s, r)

print filename.encode("utf8")
