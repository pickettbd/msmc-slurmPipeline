
import sys

def getHeadersOfLongest(fai_fn, cutoff):
	headers = []
	with open(fai_fn, 'r') as ifd:
		for line in ifd:
			fields = line.rstrip('\n').split('\t')
			name = fields[0]
			length = int(fields[1])
			if length >= cutoff:
				headers.append(name)
	return headers

def extractSpecificSequences(ifn, ofn, heads):
	with open(ofn, 'w') as ofd:
		with open(ifn, 'r') as ifd:
			line = ifd.readline()
			while line != '':
				header = line.rstrip('\n')[1:]
				seq = ''
				line = ifd.readline()
				while line != '' and line[0] != '>':
					seq += line.rstrip('\n')
					line = ifd.readline()
				if header in heads:
					ofd.write(f">{header}\n{seq}\n")

if __name__ == "__main__":
	
	fa_fn = sys.argv[1]
	fai_fn = sys.argv[2]
	out_fa_fn = sys.argv[3]
	cutoff_kb = int(sys.argv[4])

	cutoff = cutoff_kb * 1000

	heads_of_longest = getHeadersOfLongest(fai_fn, cutoff)

	extractSpecificSequences(fa_fn, out_fa_fn, heads_of_longest)
