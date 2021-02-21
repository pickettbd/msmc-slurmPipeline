#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
This should really be done manually. You just need to create a simple list of sample names. The names should be alphanumeric identifiers without whitespace.
If you had 4 samples, your list might look like this (1 record per line!):
	sample1
	sample2
	sample3
	sample4
The order is not important. Each sample identifier must be unique; they need not follow a pattern. The following list is just as valid:
	sally
	bob
	jack
	mae
This list must be located at data/samples.list.
'
