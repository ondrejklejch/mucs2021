#!/usr/bin/env python3

import sys
import codecs
from collections import defaultdict

ctm = sys.argv[1]
segments = sys.argv[2]
output = sys.argv[3]

words_per_file = defaultdict(list)
with codecs.open(ctm, 'r', 'utf-8') as f:
  for line in f:
    filename, _, start, dur, word, _ = line.strip().split()
    start = float(start)
    end = start + float(dur)
    words_per_file[filename].append((start, end, word))

with codecs.open(segments, 'r', 'utf-8') as f, \
    codecs.open(output, 'w', 'utf-8') as f_out:
  for line in f:
    utt, filename, start, end = line.strip().split()
    start = float(start)
    end = float(end)

    words = [w for (s, e, w) in sorted(words_per_file[filename], key=lambda x: x[1]) if start <= s and e <= end]
    print(utt, u" ".join(words), file=f_out)

