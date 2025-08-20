
#!/bin/bash

rm -f config
mkdir config
cd template

CONF=$1
SCRIPT=../../extend/lmake/ltemplate.lua
ENVIRON=../environ/$CONF.conf
for file in *.conf; do
  echo "../lua $SCRIPT $file ../config/$file $ENVIRON"
  ../lua $SCRIPT $file ../config/$file $ENVIRON
done

