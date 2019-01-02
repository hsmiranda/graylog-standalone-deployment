#!/bin/bash
# Criado em:seg 11/jun/2018 hs 15:57
# ultima modificação:seg 11/jun/2018 hs 15:57
# Criado por VonNaturAustreVe - hmiranda[at]0fx66[dot]com
# 
# Objetivo do script: Este script tem como finalidade realizar a instalacao do 
# sistema graylog


# Global variables
APPNAME='graylog0fx66'
ROOTPASSOWRD='cobaia'
SERVERIP='192.168.56.102'

# This function to install requeriments from grayloag and other softwares
preRequeriments(){
    
    # Clear all cache files form yum running well.
    yum clean all

    # Setting firewall
    firewall-cmd --zone=public --add-service=ssh --permanent
    firewall-cmd --reload

    # Install many packages usage by graylog
    yum install -y java-1.8.0-openjdk-headless.x86_64 policycoreutils-python epel-release net-tools
    
    # Running upgrade for all packages in server
    yum upgrade -y
}

# This functon to install graylog
installGraylog(){

    # Setting firewall
    firewall-cmd --zone=public --add-service={http,https,syslog} --permanent
    firewall-cmd --add-port=9000/tcp --permanent
    firewall-cmd --reload

    # Setting the selinux
    setsebool -P httpd_can_network_connect 1
    semanage port -a -t http_port_t -p tcp 9000

    # Install graylog repository
    rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-2.4-repository_latest.rpm

    # Install graylog server
    yum install -y graylog-server pwgen
    
    # Generate secret hash for save users password safe
    SECRET=$(pwgen -N 1 -s 96)

    # Set secret password
    sed -i "s/password_secret =/password_secret = $SECRET/" /etc/graylog/server/server.conf

    # Generate root password for graylog
    ROOTHASH=$(echo -n $ROOTPASSWORD | sha256sum | cut -d' ' -f 1)

    # Set root password for graylog
    sed -i "s/root_password_sha2 =/root_password_sha2 = $ROOTHASH/" /etc/graylog/server/server.conf
    
    # Setting web access
    sed -i "s/rest_listen_uri = http:\/\/127.0.0.1:9000\/api\//rest_listen_uri = http:\/\/$SERVERIP:9000\/api\//g" /etc/graylog/server/server.conf
    sed -i "s/web_listen_uri = http:\/\/127.0.0.1:9000\//rest_listen_uri = http:\/\/$SERVERIP:9000\//g" /etc/graylog/server/server.conf
    sed -i 's/#web_enable = false/web_enable = true/g' /etc/graylog/server/server.conf
    
    # Setting initialization and start graylog service
    systemctl daemon-reload
    systemctl enable graylog-server.service
    systemctl start graylog-server.service

}

# This functon to install mongodb
installMongodb(){

    # Create mongodb Repository for yum
    echo "[mongodb-org-3.6]" >>  /etc/yum.repos.d/mongodb-org-3.6.repo
    echo "name=MongoDB Repository" >>  /etc/yum.repos.d/mongodb-org-3.6.repo
    echo "baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/3.6/x86_64/" >>  /etc/yum.repos.d/mongodb-org-3.6.repo
    echo "gpgcheck=1" >>  /etc/yum.repos.d/mongodb-org-3.6.repo
    echo "enabled=1" >>  /etc/yum.repos.d/mongodb-org-3.6.repo 
    echo "gpgkey=https://www.mongodb.org/static/pgp/server-3.6.asc" >>  /etc/yum.repos.d/mongodb-org-3.6.repo 

    # Install mongodb
    yum install -y mongodb-org

    # Setting firewall
    firewall-cmd --zone=public --add-port=27017/tcp --permanent
    firewall-cmd --reload

    # Configure selinux of the mongodb
    semanage port -a -t mongod_port_t -p tcp 27017
    
    # Tunning do mongoDB
    echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
    echo "never" > /sys/kernel/mm/transparent_hugepage/defrag

    # Disable THP in boot timing
    echo "[Unit]" >> /etc/systemd/system/disable-thp.service
    echo "Description=Disable Transparent Huge Pages (THP)" >> /etc/systemd/system/disable-thp.service
    echo " " >> /etc/systemd/system/disable-thp.service
    echo "[Service]" >> /etc/systemd/system/disable-thp.service
    echo "Type=simple" >> /etc/systemd/system/disable-thp.service
    echo "ExecStart=/bin/sh -c \"echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag\"" >> /etc/systemd/system/disable-thp.service
    echo " " >> /etc/systemd/system/disable-thp.service
    echo "[Install]" >> /etc/systemd/system/disable-thp.service 
    echo "WantedBy=multi-user.target" >>  /etc/systemd/system/disable-thp.service

    # Setting initialization of the service
    systemctl daemon-reload
    systemctl enable mongod.service disable-thp.service 
    systemctl start mongod.service disable-thp.service 

    # Setting logrotate for mongodb
    sed -i 's/weekly/daily/g' /etc/logrotate.conf
}

# This functon at install elasticSearch
installElasticSearch(){

    # Setting firewall
    firewall-cmd --zone=public --add-port=9200/tcp --permanent
    firewall-cmd --zone=public --add-port=9200/udp --permanent
    firewall-cmd --reload

    # Setting selinux
    semanage port -a -t http_port_t -p tcp 9200

    # Import keys at yum
    rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

    echo "[elasticsearch-5.x]" >>  /etc/yum.repos.d/elasticsearch.repo  
    echo "name=Elasticsearch repository for 5.x packages" >>  /etc/yum.repos.d/elasticsearch.repo  
    echo "baseurl=https://artifacts.elastic.co/packages/5.x/yum" >>  /etc/yum.repos.d/elasticsearch.repo  
    echo "gpgcheck=1" >>  /etc/yum.repos.d/elasticsearch.repo  
    echo "gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch" >>  /etc/yum.repos.d/elasticsearch.repo  
    echo "enabled=1" >>  /etc/yum.repos.d/elasticsearch.repo  
    echo "autorefresh=1" >>  /etc/yum.repos.d/elasticsearch.repo  
    echo "type=rpm-md" >>  /etc/yum.repos.d/elasticsearch.repo  

    # Install elasticserch usage yum
    yum install -y elasticsearch

    # Setting elasticSearch Name
    sed -i 's/#cluster.name: my-application/cluster.name: $APPNAME/g' /etc/elasticsearch/elasticsearch.yml
    

    # Enable elasticsearch and start service
    systemctl enable elasticsearch.service
    systemctl restart elasticsearch.service


}

preRequeriments
installMongodb
installElasticSearch
installGraylog
