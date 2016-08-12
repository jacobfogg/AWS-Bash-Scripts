#!/usr/bin/env bash

#TODO: ask for input of the domain you wish to use with this server
#TODO: ping that domain somehow to ensure the DNS is configured correctly.
# TODO: If it's not, throw and error telling the user to add the DNS record and try after propagation finishes and die.

#Set some user variables
EMAIL=jacob@datajoe.com
DOMAIN=djoe.us
SUBDOMAIN=www

#Set some script variables
CENTVER="7"
OPENSSL="openssl-1.0.2h"
NGINX="nginx-1.11.3-1"

#update the server
yum -y update
yum clean all
cd ~/

#Add the builder user used for installing nginx
useradd builder
groupadd builder

#install some helper tools
yum install -y epel-release #the EPEL (Extra Packages for Enterprise Linux) Repository
yum group install -y "Development Tools" #Install the development tools used for compiling from source
yum install -y wget openssl-devel libxml2-devel libxslt-devel gd-devel perl-ExtUtils-Embed GeoIP-devel pcre-devel #Install several other packages

#install but don't build OpenSSL 1.0.2h
mkdir -p /opt/lib
wget https://www.openssl.org/source/${OPENSSL}.tar.gz /opt/lib/${OPENSSL}.tar.gz
tar -zxvf /opt/lib/${OPENSSL}.tar.gz -C /opt/lib

#install Nginx
rpm -ivh http://nginx.org/packages/mainline/centos/${CENTVER}/SRPMS/${NGINX}.el${CENTVER}.centos.gnx.src.rpm #download the RPM
sed -i "s|--with-http_ssl_module|--with-http_ssl_module --with-openssl=/opt/lib/${OPENSSL}|g" /root/rpmbuild/SPECS/nginx.spec #modify the config to add reference to the newer openssl
rpmbuild -ba /root/rpmbuild/SPECS/nginx.spec #compile nginx
rpm -ivh /root/rpmbuild/RPMS/x86_64/${NGINX}.el${CENTVER}.ngx.x86_64.rpm #install it
rpm -ivh /root/rpmbuild/RPMS/x86_64/${NGINX}.el${CENTVER}.centos.ngx.x86_64.rpm

mkdir -p /var/www/${DOMAIN} #create the webroot where the SSL will be installed

#Configure the new directory to be compatible with selinux
semanage fcontext -a -t usr_t "/var/www/${DOMAIN}(/.*)?"
restorecon -Rv /var/www/${DOMAIN}

cp /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.old
sed -i '0,/\/usr\/share\/nginx\/html/s//\/var\/www\/'${DOMAIN}'/' /etc/nginx/conf.d/default.conf #Change root location for webroot

echo "Welcome to nginx" > /var/www/${DOMAIN}/index.html #Create an index.html file for nginx to render

systemctl start nginx #Start nginx
systemctl enable nginx #Enable nginx so it will start on boot



#install the secure Cert:
yum install -y certbot #Certbot itself
#TODO: modify the command below to use the previously captured domain
certbot certonly --webroot -m ${EMAIL} -w /var/www/${DOMAIN} -d ${DOMAIN} -d ${SUBDOMAIN}.${DOMAIN} #Request the SSL using CertBot

sed -i 's/listen       80;/listen       80;\n    listen       443 default_server ssl http2;/' /etc/nginx/conf.d/default.conf
sed -i 's/server_name  localhost;/server_name  localhost;\n    ssl_certificate_key   \/etc\/letsencrypt\/live\/'${SUBDOMAIN}'.'${DOMAIN}'\/privkey.pem;/' /etc/nginx/conf.d/default.conf
sed -i 's/server_name  localhost;/server_name  localhost;\n    ssl_certificate       \/etc\/letsencrypt\/live\/'${SUBDOMAIN}'.'${DOMAIN}'\/fullchain.pem;/' /etc/nginx/conf.d/default.conf




systemctl restart nginx #Restart the sever to update the settings











##############################
#List of websites that helped:
# Installing OpenSSL1.0.2
# - http://thelinuxfaq.com/403-how-to-install-openssl-1-0-2d-version-on-centos-6-centos-7-rhel
# Installing Nginx:
# - http://m12.io/blog/http-2-with-haproxy-and-nginx-guide
# - https://forum.nginx.org/read.php?2,261880,261951#msg-261951
# - https://gist.github.com/kennwhite/6b6250e635c45c92a118a7a5cdc052c6
# Configuring selinux to work with the new webroot
# - http://www.terminalinflection.com/relocating-apache-selinux/
# Using letsencrypt with nginx
# - https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-14-04
# - https://letsencrypt.org/
# - https://certbot.eff.org/
# Testing http2
# - https://tools.keycdn.com/http2-test
# Installing development tools
# - https://support.eapps.com/index.php?/Knowledgebase/Article/View/438/55/user-guide---installing-the-centos-development-tools-gcc-flex-etc#development-tools---included-applications
