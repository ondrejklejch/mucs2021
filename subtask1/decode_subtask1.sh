#!/bin/bash

set -e

. cmd.sh
. path.sh

stage=0
feat_nj=80
decode_nj=20 # Will use $decode_nj * 4 cpus
rescore_nj=40 # Will use for RNN LM rescoring, requires $rescore_nj * 4GB memory
root_dir="/group/corpora/public/ASR_challenge/blind1/audio/"

dset=blind
languages="gujarati hindi marathi odia tamil telugu"
declare -A lang_to_lmwt=( [gujarati]=12 [hindi]=12 [marathi]=10 [odia]=8 [tamil]=12 [telugu]=12 )
data_dir=data/multilingual/blind

if [ $stage -le 0 ]; then
  mkdir -p $data_dir
  ls -1 $root_dir/*.wav | \
    sed 's@.*/\([^/]*\)\.wav@\1 \0@' > $data_dir/wav.scp
  awk '{print $1, $1}' $data_dir/wav.scp > $data_dir/utt2spk
  awk '{print $1, $1}' $data_dir/wav.scp > $data_dir/spk2utt
  awk '{print $1, "NO TEXT"}' $data_dir/wav.scp > $data_dir/text
  awk '{print $1, $1, 1}' $data_dir/wav.scp > $data_dir/reco2file_and_channel

  utils/fix_data_dir.sh $data_dir
  utils/data/get_reco2dur.sh $data_dir
  utils/validate_data_dir.sh --no-feats $data_dir
fi

if [ $stage -le 1 ]; then
  utils/copy_data_dir.sh $data_dir ${data_dir}_hires
  steps/make_mfcc.sh --mfcc-config conf/mfcc8k_hires.conf --nj $feat_nj ${data_dir}_hires
  steps/compute_cmvn_stats.sh ${data_dir}_hires
  utils/fix_data_dir.sh ${data_dir}_hires
fi

if [ $stage -le 2 ]; then
  steps/online/nnet2/extract_ivectors_online.sh --nj $feat_nj \
    ${data_dir}_hires exp/multilingual/nnet3/extractor/ exp/multilingual/nnet3/ivectors_blind || exit 1;
fi

if [ $stage -le 3 ]; then
  for lang in $languages; do	
    dir="exp/$lang/chain/cnn_tdnn/"

    steps/nnet3/decode.sh --nj $decode_nj --num-threads 4 \
       --online-ivector-dir exp/multilingual/nnet3/ivectors_blind \
       --acwt 1.0 --post-decode-acwt 10.0 \
       --lattice-beam 8.0 \
       --skip-scoring true \
       $dir/graph ${data_dir}_hires $dir/decode_blind || exit 1;
  done
fi

if [ $stage -le 4 ]; then
  for lang in $languages; do	
    dir="exp/$lang/chain/cnn_tdnn/"
    graph_dir="$dir/graph"
    decode_dir="$dir/decode_blind"
    
    awk '{print $1, $1, 0, $2}' $data_dir/reco2dur > $data_dir/segments
    awk '{print $1, $1, 1}' $data_dir/wav.scp > $data_dir/reco2file_and_channel

    scripts/lattice_to_ctm_parallel.sh --lmwt 10 $data_dir $graph_dir $decode_dir
    scripts/file2average_conf.py blind $data_dir $decode_dir $decode_dir
    scripts/apply_calibration.sh --cmd "run.pl" $data_dir $graph_dir $decode_dir $dir/calibration $decode_dir/calibrated

    mkdir -p $decode_dir/calibrated/score_0.5_10
    cat $decode_dir/calibrated/ctm_calibrated | \
      awk '{print $1, $2, 3 * $3, 3 * $4, $5, $6}' > $decode_dir/calibrated/score_0.5_10/blind.ctm
    scripts/file2average_conf.py blind $data_dir $decode_dir/calibrated $decode_dir/calibrated
  done
fi

if [ $stage -le 5 ]; then
  scripts/split_into_languages.py "calibrated_confidence+sr" cnn_tdnn decode_blind ${data_dir}_hires > ${data_dir}_hires/utt2lang
fi

if [ $stage -le 6 ]; then
  global_decode_dir=exp/multilingual/chain/cnn_tdnn/decode_blind_rnnlm_rescore
  mkdir -p $global_decode_dir/

  for lang in $languages; do
    graph_dir="exp/$lang/chain/cnn_tdnn/graph"
    new_data_dir=$data_dir/${lang}
    decode_dir=exp/$lang/chain/cnn_tdnn/decode_${dset}
    new_decode_dir=${decode_dir}_${lang}
    
    mkdir -p $new_data_dir
    awk -v lang=$lang '{if($2 == lang) print $1}' ${data_dir}_hires/utt2lang > $new_data_dir/utts
    utils/subset_data_dir.sh --utt-list $new_data_dir/utts $data $data_dir $new_data_dir
    awk '{print $1, $1, 1}' $new_data_dir/wav.scp > $new_data_dir/reco2file_and_channel

    steps/copy_lat_dir.sh --cmd run.pl --nj $rescore_nj $new_data_dir $decode_dir $new_decode_dir
    rnnlm/lmrescore_pruned.sh \
      --cmd "$decode_cmd --mem 4G" \
      --weight 0.5 --max-ngram-order 4 \
      --skip-scoring true \
      exp/$lang/chain/cnn_tdnn/graph exp/$lang/rnnlm \
      $new_data_dir $new_decode_dir ${new_decode_dir}_rnnlm_rescore || exit 1;

    cp $decode_dir/../{final.mdl,frame_subsampling_factor} $decode_dir
    scripts/lattice_to_ctm_parallel.sh --word-ins-penalty 0.0 --lmwt ${lang_to_lmwt[$lang]} $new_data_dir $graph_dir ${new_decode_dir}_rnnlm_rescore
    cat ${new_decode_dir}_rnnlm_rescore/score_0.0_${lang_to_lmwt[$lang]}/${lang}.ctm > $global_decode_dir/$lang.ctm
  done
fi

if [ $stage -le 7 ]; then
  global_decode_dir=exp/multilingual/chain/cnn_tdnn/decode_blind_rnnlm_rescore
  cat $global_decode_dir/{gujarati,hindi,marathi,odia,tamil,telugu}.ctm > $global_decode_dir/output.ctm
  steps/conf/convert_ctm_to_tra.py $global_decode_dir/output.ctm  $global_decode_dir/subtask1.tmp
  join -a 2 <(sort -k 1,1 $global_decode_dir/subtask1.tmp) <(awk '{print $1}' $data_dir/wav.scp | sort) > $global_decode_dir/subtask1.txt
  echo "Output is stored in $global_decode_dir/subtask1.txt"
fi
