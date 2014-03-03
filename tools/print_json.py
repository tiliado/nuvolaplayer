#!/usr/bin/python3

import sys
import json

filename = sys.argv[1]
key = sys.argv[2]

with open(filename) as fd:
	data = json.load(fd)
	print(data[key])
