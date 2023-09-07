#!/bin/bash

PROJECT_DIR="/var/www/drupal/drupal-github-aws-ci-cd-testing"

cd $PROJECT_DIR || { echo "ERROR: $PROJECT_DIR does not exist!"; exit 1; }

# (optional) sometimes get timeout error 'Install of drupal/core failed The following exception is caused by a process timeout' during composer install
/usr/local/bin/composer config process-timeout 2000

/usr/local/bin/composer install --no-interaction

# run drush commands as needed
cd $PROJECT_DIR/web || { echo "ERROR: $PROJECT_DIR/web does not exist!"; exit 1; }

chmod u+x $PROJECT_DIR/vendor/bin/drush

../vendor/bin/drush deploy -y

../vendor/bin/drush state:set system.maintenance_mode FALSE

../vendor/bin/drush cache:rebuild

# Change the group ownership of /var/www and its contents to the apache group
chown -R ec2-user:apache /var/www
chmod 2775 /var/www && find /var/www -type d -exec chmod 2775 {} \;

# Add group write permissions
find /var/www -type f -exec chmod 0664 {} \;

# Make drush executable
chmod u+x -R $PROJECT_DIR/vendor/bin/*
