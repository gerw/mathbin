#!/usr/bin/env python

from lxml import etree
import sys
import re

tree = etree.parse(sys.argv[1])
root = tree.getroot()

names = []
title = ""
suffix = ""

for child in root.iter():
	# print child.tag
	if re.search('book$', child.tag):
		suffix = "_BOOK"
	if re.search('(content_item|journal_article|book)$', child.tag):
		for grandchild in child.iter():
			if re.search('surname$', grandchild.tag):
				name = grandchild.text.strip()
				# make each first letter of a name Uppercase
				name = name.title()
				# remove spaces
				name = name.replace(' ', '')
				names.append(name)
			if title == "" and re.search('title$', grandchild.tag):
				if re.search('}series_metadata$', grandchild.find('../..').tag):
					# Springer books sometimes include a title of the book series,
					# e.g., 10.1007/978-3-642-04490-8.
					# We try to filter that out.
					continue
				title = grandchild.text.strip()
				# remove double whitespaces
				title = ' '.join(title.split())
				# replace multiple dashes
				title = re.sub('--','-', title)


filename = '_'.join(names) + "__" + title + suffix + ".pdf"

# replace some special characters in filename
items = {
	'/': '_',
	' ': '_'
}
for s, r in items.iteritems():
	filename = filename.replace(s, r)

print filename.encode("utf8")
