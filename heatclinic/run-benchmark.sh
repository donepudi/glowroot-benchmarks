#!/bin/sh -e

if [ -z "$RUN" ]; then
  echo RUN must be set
  exit 1
fi
if [ -z "$INSTALL_PREREQS_SCRIPT" ]; then
  echo INSTALL_PREREQS_SCRIPT must be set
  exit 1
fi
if [ -z "$HEATCLINIC_DUMP" ]; then
  echo HEATCLINIC_DUMP must be set
  exit 1
fi
if [ -z "$HEATCLINIC_WAR" ]; then
  echo HEATCLINIC_WAR must be set
  exit 1
fi
if [ -z "$SPRING_INSTRUMENT_JAR" ]; then
  echo SPRING_INSTRUMENT_JAR must be set
  exit 1
fi
if [ -z "$GLOWROOT_DIST_ZIP" ]; then
  echo GLOWROOT_DIST_ZIP must be set
  exit 1
fi
if [ -z "$GATLING_SCRIPTS" ]; then
  echo GATLING_SCRIPTS must be set
  exit 1
fi
if [ -z "$GATLING_TAR_GZ" ]; then
  # this is required because currently gatling download requires manual intervention
  # see https://groups.google.com/d/msg/gatling/rLizpj0TjgU/JIBLR_9y9asJ
  echo GATLING_TAR_GZ must be set
  exit 1
fi
if [ -z "$INSTANCE_TYPE" ]; then
  echo INSTANCE_TYPE must be set
  exit 1
fi
if [ -z "$IMAGE_ID" ]; then
  echo IMAGE_ID must be set
  exit 1
fi
if [ -z "$LINUX_USER" ]; then
  echo LINUX_USER must be set
  exit 1
fi
if [ -z "$PRIVATE_KEY_FILE" ]; then
  echo PRIVATE_KEY_FILE must be set
  exit 1
fi
if [ -z "$KEY_NAME" ]; then
  echo KEY_NAME must be set
  exit 1
fi
if [ -z "$SECURITY_GROUP" ]; then
  echo SECURITY_GROUP must be set
  exit 1
fi


if [ ! -z "$SSD" ]; then
  instance_args='--block-device-mappings [{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2"}}]'
fi

# clean up previous run
rm -f output/$RUN-prereqs.txt
rm -f output/$RUN.txt
rm -rf results/$RUN

echo [$RUN] creating instance ...
# ssd root volume (volume type gp2)
instance_id=`aws ec2 run-instances --image-id $IMAGE_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-groups $SECURITY_GROUP $instance_args --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2"}}]' | grep InstanceId | cut -d '"' -f4`

# suppress stdout (but not stderr)
aws ec2 create-tags --resources $instance_id --tags Key=Name,Value=heatclinic-benchmark-$RUN > /dev/null

echo [$RUN] instance created: $instance_id

while
  public_dns_name=`aws ec2 describe-instances --instance-ids $instance_id --filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].PublicDnsName' --output text`
  [ ! $public_dns_name ]
do
  echo [$RUN] waiting for instance to start ...
done

echo [$RUN] instance started: $public_dns_name

while
  # intentionally suppress both stdout and stderr
  ssh -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $LINUX_USER@$public_dns_name echo &> /dev/null
  [ "$?" != "0" ]
do
  echo [$RUN] waiting for sshd to start ...
done

# ensure directories exist
mkdir -p output-prereqs output results/$RUN

echo [$RUN] installing prereqs ...
# -tt is to force a tty which is needed to run sudo commands on some systems
ssh -tt -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $LINUX_USER@$public_dns_name "$INSTALL_PREREQS_SCRIPT" > output-prereqs/$RUN.txt

echo [$RUN] copying resources to host ...
scp -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $HEATCLINIC_DUMP $LINUX_USER@$public_dns_name:heatclinic.sql
scp -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $HEATCLINIC_WAR $LINUX_USER@$public_dns_name:heatclinic.war
scp -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $SPRING_INSTRUMENT_JAR $LINUX_USER@$public_dns_name:spring-instrument.jar
scp -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $GLOWROOT_DIST_ZIP $LINUX_USER@$public_dns_name:glowroot-dist.zip
scp -r -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $GATLING_SCRIPTS $LINUX_USER@$public_dns_name:gatling-scripts
# this is required because currently gatling download requires manual intervention
# see https://groups.google.com/d/msg/gatling/rLizpj0TjgU/JIBLR_9y9asJ
scp -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $GATLING_TAR_GZ $LINUX_USER@$public_dns_name:gatling.tar.gz

run_script="
sim_users=\"$SIM_USERS\"
sim_iterations=\"$SIM_ITERATIONS\"
extra_jvm_args=\"$EXTRA_JVM_ARGS\"
$(cat <<'EOF'
# create mysql user for heatclinic
mysql --user=root --password=password <<EOF2
create user heatclinic@localhost identified by 'heatclinic';
create database heatclinic;
grant all privileges on heatclinic.* to heatclinic@localhost;
EOF2

# import database
mysql -u root -ppassword heatclinic < $HOME/heatclinic.sql

# install mysql jdbc driver
sudo wget -O /usr/share/tomcat7/lib/mysql-connector-java-5.1.31.jar http://search.maven.org/remotecontent?filepath=mysql/mysql-connector-java/5.1.31/mysql-connector-java-5.1.31.jar

# install glowroot somewhere that tomcat can access
sudo mkdir -p /usr/share/tomcat7/extras
sudo unzip glowroot-dist.zip -d /usr/share/tomcat7/extras
sudo chown -R tomcat:tomcat /usr/share/tomcat7/extras/glowroot

# install spring-instrument javaagent somewhere that tomcat can access
sudo cp $HOME/spring-instrument.jar /usr/share/tomcat7/extras

# install heatclinic war
sudo cp $HOME/heatclinic.war /usr/share/tomcat7/webapps/ROOT.war

# install gatling
tar xzf $HOME/gatling.tar.gz
mv gatling-charts-highcharts-* gatling

function run_sim {
  echo "running $1 user(s) $2 iteration(s) ..."
  JAVA_OPTS="-Dusers=$1 -Diterations=$2" $HOME/gatling/bin/gatling.sh --simulations-folder $HOME/gatling-scripts --results-folder $3 -s com.github.trask.gatling.heatclinic.BasicSimulation
}

function run_simulation {

  mkdir -p $HOME/results/$1

  if [ "$1" == "glowroot" ]; then
    glowroot_jvm_arg=-javaagent:/usr/share/tomcat7/extras/glowroot/glowroot.jar
  else
    glowroot_jvm_arg=
  fi
  
  # set tomcat jvm args
  sudo mkdir -p /etc/tomcat
  echo CATALINA_OPTS=\"-Xms1g -Xmx1g -XX:MaxPermSize=256m $glowroot_jvm_arg -javaagent:/usr/share/tomcat7/extras/spring-instrument.jar -Druntime.environment=production -Ddatabase.url=jdbc:mysql://localhost:3306/heatclinic -Ddatabase.user=heatclinic -Ddatabase.password=heatclinic -Ddatabase.driver=com.mysql.jdbc.Driver $extra_jvm_args\" | sudo tee /etc/tomcat/tomcat.conf > /dev/null

  # start tomcat
  sudo service tomcat7 start

  # wait for tomcat to start
  while
    sleep 5
    sudo sh -c "grep 'Server startup' /var/log/tomcat7/catalina.*.log"
    [ "$?" != "0" ]
  do
    echo waiting for tomcat to start ...
  done

  # capture startup time
  sudo sh -c "grep 'Server startup' /var/log/tomcat7/catalina.*.log" >> $HOME/results/$1/startup.txt

  if [ "$1" == "system-warmup" ]; then
    # run single user first to get it minimally warmed up before real warmup
    run_sim 1 1 "$HOME/results/system-warmup/warmup-1-1"
    run_sim $sim_users $sim_iterations "$HOME/results/system-warmup/warmup-$sim_users-$sim_iterations"
  else
    run_sim 1 1 "$HOME/results/$1/cold-1-1"
    run_sim $sim_users $sim_iterations "$HOME/results/$1/warmup-$sim_users-$sim_iterations"
    run_sim $sim_users $sim_iterations "$HOME/results/$1/hot-$sim_users-$sim_iterations"
  fi

  # stop tomcat
  sudo service tomcat7 stop
  
  # clean up
  sudo sh -c "rm /var/log/tomcat7/*"
}

# system warmup
run_simulation "system-warmup"

for i in {1..10}
do
  echo running baseline simulation ...
  run_simulation "baseline"
  echo running simulation with glowroot ...
  run_simulation "glowroot"
done

EOF
)
"

echo [$RUN] installing and running benchmark ...
# -tt is to force a tty which is needed to run sudo commands on some systems
ssh -tt $ssh_args -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $LINUX_USER@$public_dns_name "$run_script" > output/$RUN.txt

echo [$RUN] copying results from host ...
scp -r -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $LINUX_USER@$public_dns_name:results/baseline results/$RUN
scp -r -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $LINUX_USER@$public_dns_name:results/glowroot results/$RUN
scp -r -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $LINUX_USER@$public_dns_name:/usr/share/tomcat7/extras/glowroot results/$RUN/glowroot/glowroot-data

echo [$RUN] terminating instance ...
aws ec2 terminate-instances --instance-ids $instance_id > /dev/null
