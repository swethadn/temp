#!/bin/bash

# List of positional variables
# $HDI = $1
# $HDISSHUSER = $2
# $HDISSHPASSWORD = $3
# $HDIADMINUSER = $4
# $UNIFI_VERSION = $5
# $USE_SSL = $6

set -e

prog=unifi_install_edge.sh

# Install pre-reqs and copy unifi to vm
/usr/sbin/adduser --disabled-password --gecos "" unifi
wget --retry-connrefused -t 0 -O /tmp/unifi-prereqs-2.6-ubuntu1604-hdi3.6.tar.gz "https://demostoragey4.blob.core.windows.net/mydisks/unifi-prereqs-2.6-ubuntu1604-hdi3.6.tar.gz?st=2018-04-12T07%3A53%3A00Z&se=2028-12-13T06%3A53%3A00Z&sp=rl&sv=2017-04-17&sr=b&sig=DDTbP%2BUYADC%2F1ZAO5G3Jz2t6gyYoaSKKNhP%2FqB8GuEM%3D"
if [ $? -ne 0 ]; then
    echo "Could not download Unifi prerequisite artifact"
fi

sudo tar -xvf /tmp/unifi-prereqs-2.6-ubuntu1604-hdi3.6.tar.gz -C /usr/local
cd /usr/local/unifi-prereqs-2.6-ubuntu1604-hdi3.6
sudo ./01_linux_prereqs.sh
sudo ./02_unifi_prereqs.sh
wget --retry-connrefused -t 0 -O /tmp/unifing-2.6.tar.gz "https://demostoragey4.blob.core.windows.net/mydisks/unifing-2.6.tar.gz?st=2018-04-12T00%3A53%3A00Z&se=2028-12-12T22%3A53%3A00Z&sp=rl&sv=2017-04-17&sr=b&sig=b126tfDX87cwamGjPKw1AzLU%2F1noZE2tOR1gBKuzLyQ%3D"
if [ $? -ne 0 ]; then
    echo "Could not download Unifi product artifact"
fi
sudo tar -xvf /tmp/unifing-2.6.tar.gz -C /usr/local

sudo echo export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-amd64 >> /etc/sqoop/conf/sqoop-env.sh
#sshpass -f password.txt scp $2@$1-ssh.azurehdinsight.net:/usr/lib/hdinsight-common/certs/key_decryption_cert.prv /usr/lib/hdinsight-common/certs/key_decryption_cert.prv

cp /etc/hive/conf/hive-site.xml /usr/local/spark/conf
ln -s /usr/lib/hdinsight-logging/microsoft-log4j-etwappender-1.0.jar /usr/local/spark/jars/microsoft-log4j-etwappender-1.0.jar
ln -s /usr/lib/hdinsight-logging/mdsdclient-1.0.jar /usr/local/spark/jars/mdsdclient-1.0.jar
ln -s /usr/lib/hdinsight-logging/json-simple-1.1.jar /usr/local/spark/jars/json-simple-1.1.jar
ln -s /usr/lib/hdinsight-logging/json-20090211.jar /usr/local/spark/jars/json-20090211.jar

# The unifi_virtualenv folder needs to be owned by unifi user
chown -R unifi:unifi /usr/local/unifi_virtualenv


# The unifing folder needs to be owned by unifi user
chown -R unifi:unifi /usr/local/unifing-2.6


# We use a symbolic link called unifi which sits on /usr/local. For upgrades, we recreate this link
ln -s /usr/local/unifing-2.6 /usr/local/unifi
chown -R  unifi /usr/local/unifi


# We define our installation folder for subsequent steps
UNIFI_ROOT_DIR=/usr/local/unifi


# Ensuring permissions are set correctly
chown -RH unifi:unifi /opt/solr


# Get ready to install Unifi
. /usr/local/unifi_virtualenv/bin/activate


# The LD_LIBRARY_PATH contains libpq.so.5 which is needed by psycopg2 for installing Unifi software
PG_HOME=/usr/local/pgsql
export LD_LIBRARY_PATH=/usr/local/pgsql/lib/:$LD_LIBRARY_PATH
export PATH=$PATH:/usr/local/pgsql/bin/:/opt/solr/bin:/usr/local/spark/bin
export HADOOP_HOME=/usr/hdp/current/hadoop-client
export JAVA_HOME=/opt/jdk1.8.0_45/


# Symbolic link needed to import unifi_pylib libraries
ln -s $UNIFI_ROOT_DIR/unifi_pylib/lib/unifi /usr/local/unifi_virtualenv/lib/python2.7/site-packages/unifi


# Write out the appropriate UNIFI_VIRT_ENV
echo "UNIFI_VIRT_ENV=/usr/local/unifi_virtualenv/" > $UNIFI_ROOT_DIR//unifi_env.sh
#mkhomedir_helper unifi

# unifi env variables
echo export JAVA_HOME=/opt/jdk1.8.0_45 >> /home/unifi/.bashrc
echo export LD_LIBRARY_PATH=/usr/local/pgsql/lib/:$LD_LIBRARY_PATH >> /home/unifi/.bashrc
echo export UNIFI_HOME=/usr/local/unifi >> /home/unifi/.bashrc
echo export SPARK_HOME=/usr/local/spark >> /home/unifi/.bashrc

# hadoop env variables for CDH hadoop. These will not work for other distributions.
echo export HADOOP_HOME=/usr/hdp/current/hadoop-client >> /home/unifi/.bashrc
echo export HADOOP_CONF_DIR=/etc/hadoop/conf >> /home/unifi/.bashrc
echo export HIVE_CONF_DIR=/etc/hive/conf >> /home/unifi/.bashrc
echo export HADOOP_CLASSPATH=/usr/lib/hadoop/share/hadoop/tools/lib/*:/usr/local/spark/jars/emrfs-hadoop-assembly-2.18.0.jar:/usr/local/spark/jars/s3distcp.jar:$HADOOP_CONF_DIR:$HADOOP_CLASSPATH >> /home/unifi/.bashrc

#activate unifi_virtualenv
echo source /usr/local/unifi_virtualenv/bin/activate >> /home/unifi/.bashrc
echo export PATH=$PATH:/usr/local/bin/:/usr/bin:/usr/local/pgsql/bin:/usr/local/unifi/scripts/sbin:/opt/jdk1.8.0_45/bin:/opt/solr/bin:/usr/local/nginx/sbin:$SPARK_HOME/bin:$HADOOP_HOME/bin:$UNIFI_ROOT_DIR/scripts/sbin >> /home/unifi/.bashrc

su unifi -c "source /usr/local/unifi_virtualenv/bin/activate; $PG_HOME/bin/pg_ctl -D $PG_HOME/data -l $PG_HOME/server.log start"

### TODO - Need to implement pg_stat_activity to ensure template1 database doesn't have any active sessions
### This is to avoid a race condition where if template1 database has any active connections,
### the Unifi-base container does not attempt to install Unifi software
# SELECT * FROM pg_stat_activity where '' is empty
apt-get install -y ca-certificates-java
apt-get -y install nginx

# Unifi installation begins
echo "Installing Unifi"
su unifi -c "source /usr/local/unifi_virtualenv/bin/activate && export PATH=/usr/local/unifi_virtualenv/bin:/usr/local/pgsql/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/spark/bin/:/opt/solr/bin:$PATH && $UNIFI_ROOT_DIR/scripts/sbin/unifi_install --dbhost localhost --dbport 5432 --dbuser unifi --dbpass unifi --dbname unifi --unifiuser unifi --unifipass unifi --unifiemail unifi@unifisoftware.com --unififirstname Unifi --unifilastname Administrator --install-missing-deps"

if [ "$6" = "TRUE" ]; then
    echo "Enabling SSL support in Unifi"
    su unifi -c "$UNIFI_ROOT_DIR/scripts/sbin/unifi_enablessl --privkey $UNIFI_ROOT_DIR/test/api/ssl/localhost.key --ssl-cert $UNIFI_ROOT_DIR/test/api/ssl/localhost.crt --hide-warning"
fi


# Set hdp.version property in yarn-config on HDI and copy the file to Unifi
# wait for the property to get updated
ssh -o "StrictHostKeyChecking no" $2@$1-ssh.azurehdinsight.net sudo python /var/lib/ambari-server/resources/scripts/configs.py -u $4 -p $3 -a "set" -l headnodehost -n $1 -c "yarn-site" -k "hdp.version" -v $hdp
curl -u $4:$3 -H "X-Requested-By: ambari" -X POST -d '{"RequestInfo":{"command":"RESTART","context":"Restart all required services","operation_level":"host_component"},"Requests/resource_filters":[{"hosts_predicate":"HostRoles/stale_configs:true"}]}' https://$1.azurehdinsight.net/api/v1/clusters/$1/requests
set +e
while true
  sshpass -f password.txt scp -o "StrictHostKeyChecking no" $2@$1-ssh.azurehdinsight.net:/etc/hadoop/conf/yarn-site.xml /etc/hadoop/conf/yarn-site.xml
  do version=$(hdfs getconf -confKey hdp.version)
    if [ $? -eq 0 ]
    then
      break
    fi
  done
set -e

chown -R unifi /var/log/nginx
chown -R unifi /var/lib/nginx

# Generating the license for 15 day trial
uid=$(uuidgen)
wget -O UNIFi.license https://license.unifisoftware.com/license_service/license/demo?company=$uid
cp UNIFi.license /usr/local/unifi
rm UNIFi.license

#export PATH=/usr/local/unifi_virtualenv/bin:/usr/local/bin/:/usr/local/pgsql/bin:/usr/local/unifi/scripts/sbin:/opt/jdk1.8.0_45/bin:/opt/solr/bin:/usr/local/nginx/sbin:/usr/local/spark/bin:/usr/local/unifi_virtualenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
# Start unifi services
echo "Starting unifi"
su unifi -c "source /usr/local/unifi_virtualenv/bin/activate && export PATH=/usr/local/pgsql/bin/:/opt/solr/bin:/usr/local/spark/bin:$PATH && export LD_LIBRARY_PATH=/usr/local/pgsql/lib/:$LD_LIBRARY_PATH && export PGDATA=/usr/local/pgsql/data && export HADOOP_HOME=/usr/hdp/current/hadoop-client && export HADOOP_CONF_DIR=/etc/hadoop/conf && export HIVE_CONF_DIR=/etc/hive/conf && export SPARK_HOME=/usr/local/spark && $UNIFI_ROOT_DIR/scripts/sbin/unifi_start"


# Set the Solr core home directory and install solr core
SOLR_VERSION=6.2.1
SOLR_HOME=$UNIFI_ROOT_DIR/ext/solr/$SOLR_VERSION
SOLR_MAIN_CORE=unifi_main
SOLR_MD_CORE=unifi_metadata_mgmt
SOLR_MAIN_CORE_HOME=$SOLR_HOME/$SOLR_MAIN_CORE
SOLR_MD_CORE_HOME=$SOLR_HOME/$SOLR_MD_CORE

echo "Installing UNIFi Solr Cores"
su unifi -c "source /usr/local/unifi_virtualenv/bin/activate && $UNIFI_ROOT_DIR/scripts/sbin/unifi_installsolrcore --unifiuser unifi --unifipass unifi"
