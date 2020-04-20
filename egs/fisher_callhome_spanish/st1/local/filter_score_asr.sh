#!/bin/bash

decode_mdl_dir=exp/train_sp.es_lc.rm_pytorch_train_bpe1000
dsets="callhome_devtest.es callhome_evltest.es fisher_dev.es fisher_dev2.es fisher_test.es"
. path.sh
affix="wrd.trn.lc.rm.detok"

for d in ${dsets}; do
  score_dir=$decode_mdl_dir/decode_${d}_decode
  [ ! -d $score_dir ] && echo "No such directory: $score_dir" && exit 1
  new_dir=$score_dir/filter_kaldi
  mkdir -p $new_dir
  filter=data/$d/overlap.uttid
  cat $filter | tr [:upper:] [:lower:] > $new_dir/filter
  filter=$new_dir/filter
  for f in hyp ref; do
    [ ! -f $score_dir/$f.$affix ] && echo "No such file: $score_dir/$f.$affix " && exit 1;
    cat $score_dir/$f.$affix | grep -f $filter > $new_dir/$f.$affix
  done

  sclite -r $new_dir/ref.$affix trn -h $new_dir/hyp.$affix trn -i rm -o all stdout > $new_dir/result.wrd.txt
done

