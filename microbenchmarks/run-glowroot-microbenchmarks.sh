#!/bin/sh -e

if [ -z "$GIT_REPOS" ]; then
  echo GIT_REPOS must be set
  exit 1
fi

script_dir="$(dirname "$0")"

export PRIVATE_KEY_FILE=~/.ssh/glowroot-benchmark.pem
export KEY_NAME=glowroot-benchmark
export SECURITY_GROUP=default

# SuSE Linux Enterprise Server 11 sp3 (HVM), SSD Volume Type
export IMAGE_ID=ami-7fd3ae4f
export LINUX_USER=root
export INSTALL_JAVA_CMD="zypper install -y java-1_7_0-ibm"

export MICROBENCHMARK_JAR=$GIT_REPOS/glowroot/testing/microbenchmarks/target/microbenchmarks.jar
export MICROBENCHMARK_ARGS="-jvmArgs \"-javaagent:microbenchmarks.jar\""
RUN=core-suse-c3-large INSTANCE_TYPE=c3.large $script_dir/run-microbenchmarks.sh &

export MICROBENCHMARK_JAR=$GIT_REPOS/glowroot/plugins/servlet-plugin-microbenchmarks/target/microbenchmarks.jar
export MICROBENCHMARK_ARGS="-jvmArgs \"-javaagent:microbenchmarks.jar\""
RUN=servlet-plugin-suse-c3-large INSTANCE_TYPE=c3.large $script_dir/run-microbenchmarks.sh &

export MICROBENCHMARK_JAR=$GIT_REPOS/glowroot/plugins/jdbc-plugin-microbenchmarks/target/microbenchmarks.jar
export MICROBENCHMARK_ARGS="-jvmArgs \"-javaagent:microbenchmarks.jar\""
RUN=jdbc-plugin-suse-c3-large INSTANCE_TYPE=c3.large $script_dir/run-microbenchmarks.sh &

# Amazon Linux AMI 2014.03.2 (HVM)
export IMAGE_ID=ami-d13845e1
export LINUX_USER=ec2-user
export INSTALL_JAVA_CMD=

export MICROBENCHMARK_JAR=$GIT_REPOS/glowroot/testing/microbenchmarks/target/microbenchmarks.jar
export MICROBENCHMARK_ARGS="-jvmArgs \"-javaagent:microbenchmarks.jar\""
RUN=core-amazon-linux-c3-large INSTANCE_TYPE=c3.large $script_dir/run-microbenchmarks.sh &
export MICROBENCHMARK_ARGS="-jvmArgs \"-javaagent:microbenchmarks.jar -Dglowroot.internal.dummyTicker=true\""
RUN=core-amazon-linux-c3-large-with-dummy-ticker INSTANCE_TYPE=c3.large $script_dir/run-microbenchmarks.sh &

export MICROBENCHMARK_JAR=$GIT_REPOS/glowroot/plugins/servlet-plugin-microbenchmarks/target/microbenchmarks.jar
export MICROBENCHMARK_ARGS="-jvmArgs \"-javaagent:microbenchmarks.jar\""
RUN=servlet-plugin-amazon-linux-c3-large INSTANCE_TYPE=c3.large $script_dir/run-microbenchmarks.sh &
export MICROBENCHMARK_ARGS="-jvmArgs \"-javaagent:microbenchmarks.jar -Dglowroot.internal.dummyTicker=true\""
RUN=servlet-plugin-amazon-linux-c3-large-with-dummy-ticker INSTANCE_TYPE=c3.large $script_dir/run-microbenchmarks.sh &

export MICROBENCHMARK_JAR=$GIT_REPOS/glowroot/plugins/jdbc-plugin-microbenchmarks/target/microbenchmarks.jar
export MICROBENCHMARK_ARGS="-jvmArgs \"-javaagent:microbenchmarks.jar\""
RUN=jdbc-plugin-amazon-linux-c3-large INSTANCE_TYPE=c3.large $script_dir/run-microbenchmarks.sh &
export MICROBENCHMARK_ARGS="-jvmArgs \"-javaagent:microbenchmarks.jar -Dglowroot.internal.dummyTicker=true\""
RUN=jdbc-plugin-amazon-linux-c3-large-with-dummy-ticker INSTANCE_TYPE=c3.large $script_dir/run-microbenchmarks.sh &
