# The CSTR System for Multilingual and Code-Switching ASR Challenges for Low Resource Indian Languages
This repository contains code for reproduction of the decoded output on the blind test set in [MUCS 2021: MUltilingual and Code-Switching ASR Challenges for Low Resource Indian Languages](https://navana-tech.github.io/IS21SS-indicASRchallenge/).

## Installation
The dependencies can be installed with `bash install.sh`.

## Subtask 1
To reproduce the output for Subtask 1 first edit variables `feat_nj`, `decode_nj`, `rescore_nj` and `root_dir` in `subtask1/decode_subtask1.sh` and then run the following steps:

```
cd subtask1
bash download_models.sh
bash decode_subtask1.sh
```
The output will be stored in `subtask1/exp/multilingual/chain/cnn_tdnn/decode_blind_rnnlm_rescore/subtask1.txt`.

## Subtask 2
To reproduce the output for Subtask 2 first edit the variable `root_dir` in `subtask2/decode_subtask2.sh` and then run the following steps:
```
cd subtask2
bash download_models.sh
bash decode_subtask2.sh
```
The output will be stored in `subtask2/submission/subtask2.txt`.

## Models
Models are licensed under a [Creative Commons CC BY-SA 4.0 license](https://creativecommons.org/licenses/by-sa/4.0/).

## Cite us
```
@inproceedings{klejch2021mucs,
  author={Ond\v{r}ej Klejch and Electra Wallington and Peter Bell},
  title={{The CSTR System for Multilingual and Code-Switching ASR Challenges for Low Resource Indian Languages}},
  year=2021,
  booktitle={Proc. Interspeech 2021},
}
```
