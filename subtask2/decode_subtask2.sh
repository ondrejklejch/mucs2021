#!/bin/bash

. path.sh

stage=0
root_dir="/group/corporapublic/ASR_challenge/blind2/"

languages="bengali hindi"
nnet1=cnn_tdnn_specaugment_cleaned
nnet2=cnn_tdnn_specaugment_cleaned_transfer

if [ $stage -le 0 ]; then
  for lang in $languages; do
      data_dir=data/$lang/blind

      mkdir -p $data_dir
      cp -r $root_dir/$lang/files/* $data_dir
      sed -i "s@ @ $root_dir/$lang/@" $data_dir/wav.scp

      utils/validate_data_dir.sh --no-text --no-feats $data_dir
  done
fi

if [ $stage -le 1 ]; then
    for lang in $languages; do	
        utils/copy_data_dir.sh data/${lang}/blind data/${lang}/blind_hires
        steps/make_mfcc.sh --mfcc-config conf/mfcc8k_hires.conf --nj 10 data/${lang}/blind_hires
        steps/compute_cmvn_stats.sh data/${lang}/blind_hires
        utils/fix_data_dir.sh data/${lang}/blind_hires
    done
fi

if [ $stage -le 2 ]; then
    for lang in $languages; do	
      steps/online/nnet2/extract_ivectors_online.sh --nj 10 \
        data/${lang}/blind_hires exp/multilingual/nnet3/extractor/ exp/$lang/nnet3/ivectors_blind || exit 1;
    done
fi

if [ $stage -le 3 ]; then
  for lang in $languages; do
    dir1="exp/$lang/chain/$nnet1"
    dir2="exp/$lang/chain/$nnet2"
    decode_dir="exp/$lang/chain/combine/decode_blind"

    steps/nnet3/decode_score_fusion.sh --nj 20 --num-threads 4 \
       --online-ivector-dir exp/$lang/nnet3/ivectors_blind \
       --acwt 1.0 --post-decode-acwt 10.0 \
       --skip-scoring true \
       data/${lang}/blind_hires exp/$lang/chain/tree_bi/graph $dir1 $dir2 $decode_dir || exit 1;
  done
fi

if [ $stage -le 4 ]; then
  for lang in $languages; do	
    dir="exp/$lang/chain/combine/"

    rnnlm/lmrescore_pruned.sh \
      --cmd "run.pl --mem 4G" \
      --weight 0.5 --max-ngram-order 4 \
      --skip-scoring true \
      exp/$lang/chain/tree_bi/graph exp/$lang/rnnlm \
      data/$lang/blind_hires $dir/decode_blind $dir/decode_blind_rnnlm_rescore || exit 1;
  done
fi

if [ $stage -le 5 ]; then
  lang=bengali
  dir="exp/$lang/chain/combine/"
  graph="exp/$lang/chain/tree_bi/graph"
  data="data/${lang}/blind_hires"
  decode_dir="$dir/decode_blind"

  mkdir -p submission
  rm submission/subtask2.txt || true

  awk '{print $1, $1, 1}' $data/wav.scp > $data/reco2file_and_channel
  local/lattice_to_ctm.sh --word_ins_penalty 0.0 --min-lmwt 12 --max-lmwt 12 $data $graph $decode_dir
  scripts/ctm_to_tra.py $decode_dir/score_12/blind_hires.ctm $data/segments $decode_dir/score_12/subtask2.txt
  cat $decode_dir/score_12/subtask2.txt >> submission/subtask2.txt

  lang=hindi
  dir="exp/$lang/chain/combine/"
  graph="exp/$lang/chain/tree_bi/graph"
  data="data/${lang}/blind_hires"
  decode_dir="$dir/decode_blind_rnnlm_rescore"

  awk '{print $1, $1, 1}' $data/wav.scp > $data/reco2file_and_channel
  local/lattice_to_ctm.sh --word_ins_penalty 0.0 --min-lmwt 12 --max-lmwt 12 $data $graph $decode_dir
  scripts/ctm_to_tra.py $decode_dir/score_12/blind_hires.ctm $data/segments $decode_dir/score_12/subtask2.txt
  cat $decode_dir/score_12/subtask2.txt >> submission/subtask2.txt

  echo "Output is stored in submission/subtask2.txt"
fi
