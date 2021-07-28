#!/bin/bash

if [ ! -f subtask1.zip ]; then
  wget https://data.cstr.ed.ac.uk/mucs2021/subtask1.zip
fi

if [ ! -d exp ]; then
  unzip subtask1.zip
fi
