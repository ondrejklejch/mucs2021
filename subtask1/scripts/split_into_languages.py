#!/usr/bin/env python3

import sys
from collections import defaultdict

def load_dict(path):
  utt2val = {}
  with open(path, 'r') as f:
    for line in f:
      utt, conf = line.strip().split()
      utt2val[utt] = float(conf)

  return utt2val

def load_score(score_type, lang, nnet, decode_dir, data_dir):
  if score_type == "confidence":
    return load_dict('exp/%s/chain/%s/%s/file2conf' % (lang, nnet, decode_dir))
  elif score_type == "calibrated_confidence":
    return load_dict('exp/%s/chain/%s/%s/calibrated/file2conf' % (lang, nnet, decode_dir))
  elif score_type == "confidence+sr":
    file2conf = load_dict('exp/%s/chain/%s/%s/file2conf' % (lang, nnet, decode_dir))
    file2decoded_dur = load_dict('exp/%s/chain/%s/%s/file2decoded_dur' % (lang, nnet, decode_dir))
    file2dur = load_dict('%s/reco2dur' % data_dir)

    utt2score = {}
    for utt in file2conf.keys():
      utt2score[utt] = 0.5 * file2decoded_dur[utt] / file2dur[utt] + 0.5 * file2conf[utt]

    return utt2score
  elif score_type == "calibrated_confidence+sr":
    file2conf = load_dict('exp/%s/chain/%s/%s/calibrated/file2conf' % (lang, nnet, decode_dir))
    file2decoded_dur = load_dict('exp/%s/chain/%s/%s/file2decoded_dur' % (lang, nnet, decode_dir))
    file2dur = load_dict('%s/reco2dur' % data_dir)

    utt2score = {}
    for utt in file2conf.keys():
      utt2score[utt] = 0.5 * file2decoded_dur[utt] / file2dur[utt] + 0.5 * file2conf[utt]

    return utt2score

languages = ['gujarati', 'hindi', 'marathi', 'odia', 'tamil', 'telugu']
score_type = sys.argv[1]
nnet = sys.argv[2]
decode_dir = sys.argv[3]
data_dir = sys.argv[4]

utt2lang = defaultdict(lambda: (None, -1))
for lang in languages:
  for utt, conf in load_score(score_type, lang, nnet, decode_dir, data_dir).items():
    if utt2lang[utt][1] < conf:
      utt2lang[utt] = (lang, conf)

for utt in utt2lang.keys():
  print(utt, utt2lang[utt][0])
