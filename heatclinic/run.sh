#!/bin/sh -e

if [ -z "$GIT_REPOS" ]; then
  echo GIT_REPOS must be set
  exit 1
fi
if [ -z "$GATLING_TAR_GZ" ]; then
  # this is required because currently gatling download requires manual intervention
  # see https://groups.google.com/d/msg/gatling/rLizpj0TjgU/JIBLR_9y9asJ
  echo GATLING_TAR_GZ must be set
  exit 1
fi

script_dir="$(dirname "$0")"

export HEATCLINIC_DUMP=$GIT_REPOS/heatclinic-scripts/database/heatclinic.sql
export HEATCLINIC_WAR=$GIT_REPOS/heatclinic/site/target/mycompany.war
export SPRING_INSTRUMENT_JAR=$GIT_REPOS/heatclinic/lib/spring-instrument-3.2.2.RELEASE.jar
export GLOWROOT_DIST_ZIP=$GIT_REPOS/glowroot/distribution/target/glowroot-dist.zip
export GATLING_SCRIPTS=$GIT_REPOS/heatclinic-scripts/gatling/src

export PRIVATE_KEY_FILE=~/.ssh/glowroot-benchmark.pem
export KEY_NAME=glowroot-benchmark
export SECURITY_GROUP=default

# Amazon Linux AMI 2014.03.2 (HVM)
export IMAGE_ID=ami-d13845e1
export LINUX_USER=ec2-user
export INSTALL_PREREQS_SCRIPT="$(cat <<EOF
sudo yum -y install tomcat7
sudo yum -y install mysql-server
sudo service mysqld start
mysqladmin -u root password password
EOF
)"

export INSTANCE_TYPE=c3.xlarge

export SIM_USERS=10
export SIM_ITERATIONS=100
RUN=amazon-linux-c3-xlarge-$SIM_USERS-users $script_dir/run-benchmark.sh &
