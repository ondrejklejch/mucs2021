#!/usr/bin/env python3

import sys
import codecs
from collections import defaultdict

confidences = defaultdict(float)
durations = defaultdict(float)
words = defaultdict(int)

dset = sys.argv[1]
data_dir = sys.argv[2]
decode_dir = sys.argv[3]
output_dir = sys.argv[4]

with codecs.open('%s/score_0.5_10/%s.ctm' % (decode_dir, dset), 'r', 'utf-8') as f:
    for line in f:
        wav, _, _, duration, _, conf = line.strip().split()
        confidences[wav] += float(conf) * float(duration)
        durations[wav] += float(duration)
        words[wav] += 1


average_confidences = defaultdict(float)
for wav in durations.keys():
    average_confidences[wav] = confidences[wav] / durations[wav]

with open('%s/file2conf' % output_dir, 'w') as f_conf, \
    open('%s/file2decoded_dur' % output_dir, 'w') as f_dur, \
    open('%s/file2num_decoded_words' % output_dir, 'w') as f_words:
    for wav in sorted(average_confidences.keys(), key=lambda x: average_confidences[x]):
        print("%s %.4f" % (wav, average_confidences[wav]), file=f_conf)
        print("%s %.2f" % (wav, durations[wav]), file=f_dur)
        print("%s %d" % (wav, words[wav]), file=f_words)

