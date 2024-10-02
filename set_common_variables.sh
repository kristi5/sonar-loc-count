
#!/bin/bash -x
#
#
if [[ "$OSTYPE" == "darwin"* ]]; then
  # ...
  echo "darwin / MacOS recognized, let's use gsed"
  SED="gsed"
else
  # let's assume sed is gsed
  echo "Not on MacOS, using the standard sed"
  SED="sed"
fi

i=1
LISTF=""
LIST=""
NBCLOC="cptx.txt"
NBCLOCNAME="cpt-name.csv"
cpt=0
EXCLUDE=".clocignore"
