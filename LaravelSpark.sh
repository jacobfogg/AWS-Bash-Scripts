#!/usr/bin/env bash

#TODO: Update this script to check for each dependancy first, then only execute each step if needed.

#TODO: ask for input of the domain variables below
SPARKTOKEN="xxxx"
NODE="v6.9.1"
DOMAIN="your.domain.here"

#Install Composer
cd ~
curl -sS https://getcomposer.org/installer | php #install Composer
mv composer.phar /usr/bin/composer #move it to a more useful location

#Install Laravel
composer global require "laravel/installer" #this installs laravel globally
echo 'pathmunge ~/.config/composer/vendor/bin' > /etc/profile.d/composer.sh #add the composer bin to the path
chmod +x /etc/profile.d/composer.sh #make the file executable
PATH=~/.config/composer/vendor/bin:$PATH #make it available right now

#Install node.js and npm
# - This need to either be compiled or you need to download the relevant binaries for your server.
# - I chose compiling below as it's a bit more universal
cd ~
wget http://nodejs.org/dist/${NODE}/node-${NODE}.tar.gz
tar xzvf node-${NODE}.tar.gz
cd node-${NODE}
./configure
make
make install
echo 'pathmunge /usr/local/bin' > /etc/profile.d/node.sh #add the composer bin to the path
chmod +x /etc/profile.d/node.sh #make the file executable
PATH=/usr/local/bin:$PATH #make it available right now

#Install Gulp
npm install --global gulp-cli
#Install Bootstrap
npm install --global bootstrap

#Install Spark
cd ~
git clone https://github.com/laravel/spark-installer.git
cd spark-installer
composer install
echo 'pathmunge ~/spark-installer' > /etc/profile.d/spark.sh #add the composer bin to the path
chmod +x /etc/profile.d/spark.sh #make the file executable
PATH=~/spark-installer:$PATH #make it available right now

spark register $SPARKTOKEN
cd /var/www/
spark new ${DOMAIN}
cd ${DOMAIN}
#install js dependancies
npm install
#generate the JS & CSS files
gulp


#TODO: Work this out to automate this step
echo "You need to update .env for your db connection"
#TODO: Work this out to automate this step
echo "You need to set your webroot directory to /var/www/${DOMAIN}/public"



echo "Finally, you need to run the following three commands:"
echo "systemctl restart nginx"
#systemctl restart nginx #restart the web server... if you are running apache, it will be: systemctl restart httpd
echo "chown -R apache:apache /var/www/${DOMAIN}"
#chown -R apache:apache /var/www/${DOMAIN} #set the correct permissions, you may need to use a user/group other than apache:apache
echo "php artisan migrate"
#php artisan migrate #update the database
