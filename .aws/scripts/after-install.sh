#!/bin/bash

export ENVIRONMENT=$DEPLOYMENT_GROUP_NAME

PROJECT_DIR="/var/www/drupal/$APPLICATION_NAME"

cd $PROJECT_DIR || { echo "ERROR: $PROJECT_DIR does not exist!"; exit 1; }

echo "Running composer install"
# (optional) sometimes get timeout error 'Install of drupal/core failed The following exception is caused by a process timeout' during composer install
/usr/local/bin/composer config process-timeout 2000

/usr/local/bin/composer install --no-interaction

# run drush commands as needed
cd $PROJECT_DIR/web || { echo "ERROR: $PROJECT_DIR/web does not exist!"; exit 1; }

chmod u+x $PROJECT_DIR/vendor/bin/drush

echo "Runing drush deploy"
../vendor/bin/drush deploy -y

echo "Setting maintenance mode FALSE"
../vendor/bin/drush state:set system.maintenance_mode FALSE

echo "Running cache:rebuild"
../vendor/bin/drush cache:rebuild

echo "Setting permissions"
# Change the group ownership of /var/www and its contents to the apache group
chown -R ec2-user:apache /var/www
chmod 2775 /var/www && find /var/www -type d -exec chmod 2775 {} \;

# Add group write permissions
find /var/www -type f -exec chmod 0664 {} \;

# Make drush executable
chmod u+x -R $PROJECT_DIR/vendor/bin/*
