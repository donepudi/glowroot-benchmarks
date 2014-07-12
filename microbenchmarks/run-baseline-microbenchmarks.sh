#!/bin/sh -e

if [ -z "$GIT_REPOS" ]; then
  echo GIT_REPOS must be set
  exit 1
fi

script_dir="$(dirname "$0")"

export PRIVATE_KEY_FILE=~/.ssh/glowroot-benchmark.pem
export KEY_NAME=glowroot-benchmark
export SECURITY_GROUP=default

export MICROBENCHMARK_JAR=$GIT_REPOS/baseline-microbenchmarks/target/microbenchmarks.jar

# Amazon Linux AMI 2014.03.2 (HVM)
export IMAGE_ID=ami-d13845e1
export LINUX_USER=ec2-user
export INSTALL_JAVA_CMD=

RUN=baseline-amazon-linux-c3-large  INSTANCE_TYPE=c3.large  $script_dir/run-microbenchmarks.sh &

# Red Hat Enterprise Linux 7.0 (HVM)
export IMAGE_ID=ami-77d7a747
export LINUX_USER=ec2-user
export INSTALL_JAVA_CMD="sudo yum install -y java-1.7.0-openjdk"

RUN=baseline-redhat-c3-large  INSTANCE_TYPE=c3.large  $script_dir/run-microbenchmarks.sh &

# Ubuntu Server 14.04 LTS (HVM), SSD Volume Type
export IMAGE_ID=ami-b5a9d485
export LINUX_USER=ubuntu
export INSTALL_JAVA_CMD="sudo apt-get update && sudo apt-get install -y openjdk-7-jre"

RUN=baseline-ubuntu-c3-large  INSTANCE_TYPE=c3.large  $script_dir/run-microbenchmarks.sh &

# SuSE Linux Enterprise Server 11 sp3 (HVM), SSD Volume Type
export IMAGE_ID=ami-7fd3ae4f
export LINUX_USER=root
export INSTALL_JAVA_CMD="zypper install -y java-1_7_0-ibm"

RUN=baseline-suse-c3-large  INSTANCE_TYPE=c3.large  $script_dir/run-microbenchmarks.sh &
