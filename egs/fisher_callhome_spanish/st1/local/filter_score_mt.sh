#!/bin/bash

decode_mdl_dir=exp/train.en_lc.rm_lc.rm_pytorch_train_pytorch_transformer_bpe_bpe1000
#decode_mdl_dir=../st1/exp/train_sp.en_lc.rm_pytorch_train_bpe1000_asrtrans_mttrans
data_dir=../mt1/data/kaldi_asr
#dsets="callhome_devtest.en callhome_evltest.en fisher_dev.en fisher_dev2.en fisher_test.en"
dsets="fisher_dev.en"
filter_name="kaldi_hyp.uttid"
hyp_affix="_decode_pipeline"
#hyp_affix="_decode"
affix="wrd.trn.detok.lc.rm"
nbpe=1000
bpemode=bpe
tgt_case=lc.rm
bpemodel=../st1/data/lang_1spm/train_sp.en_${bpemode}${nbpe}_${tgt_case}.model

. path.sh
for d in ${dsets}; do
  score_dir=$decode_mdl_dir/decode_${d}${hyp_affix}
  [ ! -d $score_dir ] && echo "No such directory: $score_dir" && exit 1
  new_dir=$score_dir/filter_kaldi_non_empty
  mkdir -p $new_dir
  asr=$(echo ${d} | cut -f -1 -d ".").es
  #filter=../asr1b/data/$asr/overlap.uttid
  filter=$data_dir/$d/$filter_name
  #cat $filter | tr [:upper:] [:lower:] > $new_dir/filter
  cp $filter $new_dir/filter
  filter=$new_dir/filter

  for f in ref hyp src; do
    [ ! -f $score_dir/$f.trn.org ] && echo "No such file:$score_dir/$f.trn.org " && exit 1;
    cat $score_dir/$f.trn.org | grep -f $filter > $new_dir/$f.trn.org
    perl -pe 's/\([^\)]+\)//g;' ${new_dir}/$f.trn.org > ${new_dir}/$f.trn
    spm_decode --model=${bpemodel} --input_format=piece < ${new_dir}/$f.trn | sed -e "s/▁/ /g" > ${new_dir}/$f.wrd.trn
    detokenizer.perl -l en -q < ${new_dir}/$f.wrd.trn > ${new_dir}/$f.wrd.trn.detok
    local/remove_punctuation.pl < ${new_dir}/$f.wrd.trn.detok > ${new_dir}/$f.wrd.trn.detok.lc.rm
  done

  echo "1-ref BLEU"
  multi-bleu-detok.perl -lc ${new_dir}/ref.$affix < ${new_dir}/hyp.$affix >> ${new_dir}/result.lc.txt
done

