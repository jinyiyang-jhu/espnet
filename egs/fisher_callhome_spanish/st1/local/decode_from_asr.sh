
#!/bin/bash

# Give input of MT from other sources (like Kaldi ASR output).

. ./path.sh || exit 1;
. ./cmd.sh || exit 1;

stage=1
#trans_set="fisher_dev.en fisher_dev2.en fisher_test.en callhome_devtest.en callhome_evltest.en"
trans_set="callhome_devtest.en"
trans_model=exp/train.en_lc.rm_lc.rm_pytorch_train_pytorch_transformer_bpe_bpe1000/results/model.val5.avg.best
asr_data_dir=../asr1b/data
affix="kaldi_asr"
unk_sys="<unk>"
trans_dir=data/$affix
nj=16
expdir=exp/train.en_lc.rm_lc.rm_pytorch_train_pytorch_transformer_bpe_bpe1000
dumpdir=dump
decode_config=conf/decode.yaml
src_case=lc.rm
tgt_case=lc.rm
nbpe=1000
bpemode=bpe
backend=pytorch
bpemodel=../st1/data/lang_1spm/train_sp.en_${bpemode}${nbpe}_${tgt_case}
dict=../st1/data/lang_1spm/train_sp.en_${bpemode}${nbpe}_units_${tgt_case}.txt


if [ $stage -le 0 ];then
  pids=()
  for ttask in ${trans_set}; do
 (
      feat_trans_dir=${dumpdir}/${ttask}_$(echo ${affix} | rev | cut -f 2 -d "/" | rev); mkdir -p ${feat_trans_dir}
      rtask=$(echo ${ttask} | cut -f -1 -d ".").es
      data_dir=$trans_dir/${rtask}
      mkdir -p $trans_dir/${ttask} || exit "Mkdir $trans_dir/${ttask} failed"
      filter=$asr_data_dir/$rtask/overlap.uttid
      cat data/${ttask}/text.${tgt_case} | grep -f $filter > $trans_dir/${ttask}/text.${tgt_case}
      cat data/${ttask}/utt2spk | grep -f $filter > $trans_dir/${ttask}/utt2spk
      data2json.sh --text $trans_dir/${ttask}/text.${tgt_case} --bpecode ${bpemodel}.model --lang en \
            $trans_dir/${ttask} ${dict} > ${feat_trans_dir}/data_${bpemode}${nbpe}.${src_case}_${tgt_case}.json
      update_json.sh --text ${data_dir}/text_asr_hyp.wrd.${src_case} --bpecode ${bpemodel}.model \
          ${feat_trans_dir}/data_${bpemode}${nbpe}.${src_case}_${tgt_case}.json ${data_dir} ${dict}
 ) &
  pids+=($!) # store background pids
  done
  i=0; for pid in "${pids[@]}"; do wait ${pid} || ((++i)); done
  [ ${i} -gt 0 ] && echo "$0: ${i} background jobs are failed." && false
fi

pids=()
for ttask in ${trans_set}; do
(
    decode_dir=decode_${ttask}_$(basename ${decode_config%.*})_${affix}
    feat_trans_dir=${dumpdir}/${ttask}_$(echo ${affix} | rev | cut -f 2 -d "/" | rev)

    # split data
    splitjson.py --parts ${nj} ${feat_trans_dir}/data_${bpemode}${nbpe}.${src_case}_${tgt_case}.json
    ngpu=1

    ${decode_cmd} JOB=1:${nj} ${expdir}/${decode_dir}/log/decode.JOB.log \
        mt_trans.py \
        --config ${decode_config} \
        --ngpu ${ngpu} \
        --backend ${backend} \
        --batchsize 0 \
        --trans-json ${feat_trans_dir}/split${nj}utt/data_${bpemode}${nbpe}.JOB.json \
        --result-label ${expdir}/${decode_dir}/data.JOB.json \
        --model $trans_model || exit 1;

    local/score_bleu.sh --case ${tgt_case} --set ${ttask} --bpe ${nbpe} --bpemodel ${bpemodel}.model \
        ${expdir}/${decode_dir} ${dict}
) &
pids+=($!) # store background pids
done
i=0; for pid in "${pids[@]}"; do wait ${pid} || ((++i)); done
[ ${i} -gt 0 ] && echo "$0: ${i} background jobs are failed." && false
echo "Finished"

