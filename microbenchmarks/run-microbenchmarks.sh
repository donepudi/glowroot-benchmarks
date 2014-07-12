#!/bin/sh -e

if [ -z "$RUN" ]; then
  echo RUN must be set
  exit 1
fi
if [ -z "$MICROBENCHMARK_JAR" ]; then
  echo MICROBENCHMARK_JAR must be set
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
rm -f output/$RUN.txt
rm -f results/$RUN.txt

echo [$RUN] creating instance ...
instance_id=`aws ec2 run-instances --image-id $IMAGE_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-groups $SECURITY_GROUP $instance_args | grep InstanceId | cut -d '"' -f4`

# suppress stdout (but not stderr)
aws ec2 create-tags --resources $instance_id --tags Key=Name,Value=microbenchmarks-$RUN > /dev/null

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

echo [$RUN] copying benchmark to host ...
scp -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $MICROBENCHMARK_JAR $LINUX_USER@$public_dns_name:microbenchmarks.jar

# ensure directories exist
mkdir -p output-prereqs output results

if [ ! -z "$INSTALL_JAVA_CMD" ]; then
  echo [$RUN] installing java ...
  # -tt is to force a tty which is needed to run sudo commands on some systems
  ssh -tt -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $LINUX_USER@$public_dns_name "$INSTALL_JAVA_CMD" > output-prereqs/$RUN.txt
fi

echo [$RUN] running benchmark ...
ssh $ssh_args -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $LINUX_USER@$public_dns_name <<EOF > output/$RUN.txt
java -jar microbenchmarks.jar $MICROBENCHMARK_ARGS -rf text -rff results.txt
EOF

echo [$RUN] copying results from host ...
scp -i $PRIVATE_KEY_FILE -o StrictHostKeyChecking=no $LINUX_USER@$public_dns_name:results.txt results/$RUN.txt

echo [$RUN] terminating instance ...
aws ec2 terminate-instances --instance-ids $instance_id > /dev/null
