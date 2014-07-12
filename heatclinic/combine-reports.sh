#!/bin/sh -e

if [ -z "$GATLING_HOME" ]; then
  echo GATLING_HOME must be set
  exit 1
fi

function combine {
  mkdir -p $GATLING_HOME/results/temp
  cat $1/basicsimulation-*/simulation.log | head -1 > $GATLING_HOME/results/temp/simulation.log
  grep -h REQUEST $1/basicsimulation-*/simulation.log >> $GATLING_HOME/results/temp/simulation.log
  cat $1/basicsimulation-*/simulation.log | tail -1 >> $GATLING_HOME/results/temp/simulation.log
  $GATLING_HOME/bin/gatling.sh -ro temp
  mv $GATLING_HOME/results/temp $1/combined
}

for dir in results/*/*/cold-1-1
do
  combine $dir
done

for dir in results/*/*/hot-*
do
  combine $dir
done
