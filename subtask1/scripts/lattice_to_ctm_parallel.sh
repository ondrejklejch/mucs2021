#!/usr/bin/env bash
# Copyright Johns Hopkins University (Author: Daniel Povey) 2012.  Apache 2.0.

# begin configuration section.
cmd=run.pl
stage=0
decode_mbr=true
beam=5
word_ins_penalty=0.5
lmwt=10
model=
resolve_overlaps=false   # If true, the words decoded in the regions where
                         # two segments A and B are overlapping are resolved 
                         # such that only words before the mid-point of the
                         # overlapping region are taken to be hypothesized for 
                         # segment A, and only words after the mid-point of 
                         # the overlapping region are taken to be 
                         # hypothesized for segment B.

#end configuration section.

#debugging stuff
echo $0 $@

[ -f ./path.sh ] && . ./path.sh
[ -f ./cmd.sh ]  && . ./cmd.sh
. parse_options.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $0 [options] <dataDir> <langDir|graphDir> <decodeDir>" && exit;
  echo " Options:"
  echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "    --stage (0|1)                 # (createCTM | filterCTM )."
  exit 1;
fi

data=$1
lang=$2 # Note: may be graph directory not lang directory, but has the necessary stuff copied.
dir=$3

if [ -z "$model" ] ; then
  model=`dirname $dir`/final.mdl # Relative path does not work in some cases
  #model=$dir/../final.mdl # assume model one level up from decoding dir.
  #[ ! -f $model ] && model=`(set +P; cd $dir/../; pwd)`/final.mdl
fi


for f in $lang/words.txt $model $data/segments $data/reco2file_and_channel $dir/lat.1.gz; do
  [ ! -f $f ] && echo "$0: expecting file $f to exist" && exit 1;
done

if [ -f $dir/../frame_subsampling_factor ]; then
  factor=$(cat $dir/../frame_subsampling_factor) || exit 1
  frame_shift_opt="--frame-shift=0.0$factor"
  echo "$0: $dir/../frame_subsampling_factor exists, using $frame_shift_opt"
fi

name=`basename $data`; # e.g. eval2000

mkdir -p $dir/scoring/log

resolve_overlaps_cmd="cat"

if $resolve_overlaps; then
  resolve_overlaps_cmd="utils/ctm/resolve_ctm_overlaps.py $data/segments - -"
fi

nj=`cat $dir/num_jobs`
if [ $stage -le 0 ]; then
  if [ ! -f $lang/phones/word_boundary.int ] ; then
    $cmd JOB=1:$nj $dir/scoring/log/get_ctm.JOB.log \
      set -e -o pipefail \; \
      mkdir -p $dir/score_${word_ins_penalty}_$lmwt/ '&&' \
      lattice-scale --inv-acoustic-scale=$lmwt "ark:gunzip -c $dir/lat.JOB.gz|" ark:- \| \
      lattice-add-penalty --word-ins-penalty=$word_ins_penalty ark:- ark:- \| \
      lattice-prune --beam=$beam ark:- ark:- \| \
      lattice-align-words-lexicon $lang/phones/align_lexicon.int $model ark:- ark:- \| \
      lattice-to-ctm-conf $frame_shift_opt --decode-mbr=$decode_mbr ark:- - \| \
      utils/int2sym.pl -f 5 $lang/words.txt  \| \
      $resolve_overlaps_cmd \| \
      utils/convert_ctm.pl $data/segments $data/reco2file_and_channel \
      '>' $dir/score_${word_ins_penalty}_$lmwt/$name.JOB.ctm || exit 1;

      seq 1 $nj | xargs -I {} cat $dir/score_${word_ins_penalty}_$lmwt/$name.{}.ctm > $dir/score_${word_ins_penalty}_$lmwt/$name.ctm
      rm $dir/score_${word_ins_penalty}_$lmwt/$name.*.ctm
  else
    $cmd JOB=1:$nj $dir/scoring/log/get_ctm.JOB.log \
      set -e -o pipefail \; \
      mkdir -p $dir/score_${word_ins_penalty}_$lmwt/ '&&' \
      lattice-scale --inv-acoustic-scale=$lmwt "ark:gunzip -c $dir/lat.JOB.gz|" ark:- \| \
      lattice-add-penalty --word-ins-penalty=$word_ins_penalty ark:- ark:- \| \
      lattice-prune --beam=$beam ark:- ark:- \| \
      lattice-align-words $lang/phones/word_boundary.int $model ark:- ark:- \| \
      lattice-to-ctm-conf $frame_shift_opt --decode-mbr=$decode_mbr ark:- - \| \
      utils/int2sym.pl -f 5 $lang/words.txt  \| \
      $resolve_overlaps_cmd \| \
      utils/convert_ctm.pl $data/segments $data/reco2file_and_channel \
      '>' $dir/score_${word_ins_penalty}_$lmwt/$name.JOB.ctm || exit 1;

      seq 1 $nj | xargs -I {} cat $dir/score_${word_ins_penalty}_$lmwt/$name.{}.ctm > $dir/score_${word_ins_penalty}_$lmwt/$name.ctm
      rm $dir/score_${word_ins_penalty}_$lmwt/$name.*.ctm
  fi
fi

echo "Lattice2CTM finished on " `date`
exit 0
