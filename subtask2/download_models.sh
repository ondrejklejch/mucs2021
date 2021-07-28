#!/bin/bash

if [ ! -f subtask2.zip ]; then
  wget https://data.cstr.ed.ac.uk/mucs2021/subtask2.zip
fi

if [ ! -d exp ]; then
  unzip subtask2.zip
fi
