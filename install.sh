#!/bin/bash

set -e

ROOT=`pwd`
KALDI_ROOT=$ROOT/lib/kaldi

if [ ! -d $KALDI_ROOT ]; then
  echo "Installing Kaldi"

  git clone https://github.com/kaldi-asr/kaldi.git $KALDI_ROOT
  cd $KALDI_ROOT
  git checkout 98f2edfeb7c6b6efab42d0ab48cff070f37ca363

  cd $KALDI_ROOT/tools && make -j 16
  cd $KALDI_ROOT/src && ./configure && make -j 16
  cd $ROOT
fi

[ ! -L subtask1/steps ] && ln -s $KALDI_ROOT/egs/babel/s5d/steps subtask1/steps
[ ! -L subtask1/utils ] && ln -s $KALDI_ROOT/egs/babel/s5d/utils subtask1/utils
[ ! -L subtask1/local ] && ln -s $KALDI_ROOT/egs/babel/s5d/local subtask1/local
[ ! -L subtask1/rnnlm ] && ln -s $KALDI_ROOT/scripts/rnnlm/ subtask1/rnnlm

cat $KALDI_ROOT/egs/wsj/s5/path.sh | \
  sed "/export KALDI_ROOT=/s@.*@export KALDI_ROOT=$KALDI_ROOT@" > subtask1/path.sh

[ ! -L subtask2/steps ] && ln -s $KALDI_ROOT/egs/babel/s5d/steps subtask2/steps
[ ! -L subtask2/utils ] && ln -s $KALDI_ROOT/egs/babel/s5d/utils subtask2/utils
[ ! -L subtask2/local ] && ln -s $KALDI_ROOT/egs/babel/s5d/local subtask2/local
[ ! -L subtask2/rnnlm ] && ln -s $KALDI_ROOT/scripts/rnnlm/ subtask2/rnnlm

cat $KALDI_ROOT/egs/wsj/s5/path.sh | \
  sed "/export KALDI_ROOT=/s@.*@export KALDI_ROOT=$KALDI_ROOT@" > subtask2/path.sh
