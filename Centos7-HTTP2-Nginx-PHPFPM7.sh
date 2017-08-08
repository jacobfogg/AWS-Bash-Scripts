#!/usr/bin/env bash

#TODO: Add an auto-renew certbot script
#TODO: Test that this is root user
#TODO: Ask for input of the domain you wish to use with this server
#TODO: Ping that domain somehow to ensure the DNS is configured correctly.
# TODO: If it's not, throw and error telling the user to add the DNS record and try after propagation finishes and die.

#Set some user variables
EMAIL=jacob@datajoe.com
DOMAIN=www.djoe.us

#Set some script variables
CENTVER="7"
OPENSSL="openssl-1.1.0f"
NGINX="nginx-1.13.3-1"
PHPVER="php71w"
IPADDR="$(ip addr show eth0 | grep inet | awk '{ print $2; }' | head -1 | sed 's/\/.*$//')"

#update the server
yum -y update
yum clean all
cd ~/

#Add the builder user used for installing nginx
useradd builder

#install some helper tools
#the AWS version of EPEL (Extra Packages for Enterprise Linux) Repository
yum install –y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm 
yum -y install yum-utils
yum-config-manager --enable rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional
#Install the development tools used for compiling from source
yum group install -y "Development Tools" 
#Install several other packages
yum install -y wget openssl-devel libxml2-devel libxslt-devel gd-devel perl-ExtUtils-Embed GeoIP-devel pcre-devel mariadb postgresql

#install but don't build OpenSSL 1.1.0f
mkdir -p /opt/lib
cd /opt/lib/
wget https://www.openssl.org/source/${OPENSSL}.tar.gz /opt/lib/${OPENSSL}.tar.gz
tar -zxvf /opt/lib/${OPENSSL}.tar.gz -C /opt/lib

#install Nginx
rpm -ivh http://nginx.org/packages/mainline/centos/${CENTVER}/SRPMS/${NGINX}.el${CENTVER}.ngx.src.rpm #download the RPM
sed -i "s|--with-http_ssl_module|--with-http_ssl_module --with-openssl=/opt/lib/${OPENSSL}|g" /root/rpmbuild/SPECS/nginx.spec #modify the config to add reference to the newer openssl
rpmbuild -ba /root/rpmbuild/SPECS/nginx.spec #compile nginx
rpm -ivh /root/rpmbuild/RPMS/x86_64/${NGINX}.el${CENTVER}.centos.ngx.x86_64.rpm #install it

#disable SELinux
setenforce 0
echo 0 > /etc/selinux/enforce

mkdir -p /var/www/${DOMAIN} #create the webroot where the SSL will be installed
chmod 755 /var/www/${DOMAIN} #set the correct permissions
chown centos:centos /var/www/${DOMAIN} #Set the ownership to centos user


#Configure the new directory to be compatible with selinux
semanage fcontext -a -t usr_t "/var/www/${DOMAIN}(/.*)?"
restorecon -Rv /var/www/${DOMAIN}

sed -i.bak  '0,/\/usr\/share\/nginx\/html/s//\/var\/www\/'${DOMAIN}'/' /etc/nginx/conf.d/default.conf #Change root location for webroot
sed -i  's/localhost/'${DOMAIN}'/' /etc/nginx/conf.d/default.conf #Change the server_name to the domain


echo "Welcome to nginx" > /var/www/${DOMAIN}/index.html #Create an index.html file for nginx to render

systemctl start nginx #Start nginx
systemctl enable nginx #Enable nginx so it will start on boot

#TODO: figure out if there is a way to see if the site is accessible via http://${SUBDOMAIN}.${DOMAIN} yet...
#  If it is not yet accessible, pause the script and encourage the user to check in their browser, and once accessible,
#  return to this script to continue.


#install the secure Cert:
yum install -y certbot-nginx
certbot --nginx
sed -i  's/listen 443 ssl/listen 443 ssl http2/' /etc/nginx/conf.d/default.conf #add http2 support

#Check for the existance of the certbot renew, and if it doesn't exist, add it
crontab -l | grep -q 'certbot renew'  && echo || (crontab -l 2>/dev/null; echo "0 1,13 * * * certbot renew -q") | crontab -

systemctl restart nginx #Restart the sever to update the settings

#TODO: Figure out a way to automate the following:
#TODO: suggest to the user that they test both the http and https references to their site
#TODO: suggest to the user that they test HTTP2 compatibility via https://tools.keycdn.com/http2-test


#Install PHP-FPM
#install the webtatic repos
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm

yum install -y ${PHPVER}-fpm ${PHPVER}-opcache ${PHPVER}-cli ${PHPVER}-gd ${PHPVER}-mbstring ${PHPVER}-mcrypt ${PHPVER}-mysql ${PHPVER}-pdo ${PHPVER}-xml ${PHPVER}-xmlrpc #install php and a few modules
sed -i.bak 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php.ini #modify the php.ini file to turn off fix_pathinfo for security
sed -i.bak 's/worker_processes  1;/worker_processes  4;/' /etc/nginx/nginx.conf #increase the number of workers to 4
touch /var/log/nginx/access.log

#Lest overwrite the default.conf to include several changes for PHP-FPM ... This is easier than a dozen sed commands.
cat << EOF > /etc/nginx/conf.d/default.conf
server {
    listen       80;
    listen       443 default_server ssl http2;
    server_name  ${IPADDR};
    ssl_certificate       /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key   /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;

    access_log  /var/log/nginx/access.log  main;
    error_log   /var/log/nginx/error.log   error;
    location / {
        root   /var/www/${DOMAIN};
        index  index.php  index.html index.htm;
    }

    error_page  404              /404.html;
    location = /404.html {
        root  /usr/share/nginx/html;
    }

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    location ~ \.php$ {
        root           /var/www/${DOMAIN};
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }
}

EOF

echo "<?php echo 'Welcome to PHP-FPM';" > /var/www/${DOMAIN}/index.php

systemctl start php-fpm
systemctl enable php-fpm
systemctl restart nginx

#TODO: prompt the user to check the server now....
#TODO: Same as the other one... see if we can just test it, then prompt the user if needed




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
# Adding the SSL Cert
# - https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-14-04
# - https://letsencrypt.org/
# - https://certbot.eff.org/
# Testing http2
# - https://tools.keycdn.com/http2-test
# Installing development tools
# - https://support.eapps.com/index.php?/Knowledgebase/Article/View/438/55/user-guide---installing-the-centos-development-tools-gcc-flex-etc#development-tools---included-applications
#Installing PHP-FPM 7
# - https://webtatic.com/packages/php70/
