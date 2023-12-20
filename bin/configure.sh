
#!/bin/bash

rm -f configs
mkdir configs
cd template

CONF=$1
SCRIPT=../../extend/lmake/ltemplate.lua
ENVIRON=../config/$CONF.conf
for file in *.conf; do
  echo "../lua $SCRIPT $file ../configs/$file $ENVIRON"
  ../lua $SCRIPT $file ../configs/$file $ENVIRON
done

