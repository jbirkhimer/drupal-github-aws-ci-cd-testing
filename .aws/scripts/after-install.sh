#!/bin/bash

PROJECT_DIR="/var/www/drupal/drupal-github-aws-ci-cd-testing"

cd $PROJECT_DIR || { echo "ERROR: $PROJECT_DIR does not exist!"; exit 1; }

# (optional) sometimes get timeout error 'Install of drupal/core failed The following exception is caused by a process timeout' during composer install
/usr/local/bin/composer config process-timeout 2000

/usr/local/bin/composer install --no-interaction

# run drush commands as needed
cd $PROJECT_DIR/web || { echo "ERROR: $PROJECT_DIR/web does not exist!"; exit 1; }

# fix for bug with hook_install during site:install only allows using existing-config for minimal install profile
# see https://www.drupal.org/project/drupal/issues/2982052 and https://www.drupal.org/node/2897299
sed -i 's|standard|minimal|g' ../config/sync/default/core.extension.yml

chmod 755 $PROJECT_DIR/vendor/drush

../vendor/bin/drush deploy -y

../vendor/bin/drush state:set system.maintenance_mode FALSE

../vendor/bin/drush cache:rebuild

# permissions
find $PROJECT_DIR -type d -exec chmod 755 {} +
find $PROJECT_DIR -type f -exec chmod 644 {} +
chmod 444 $PROJECT_DIR/web/.htaccess
chmod 555 $PROJECT_DIR/web/sites/default
chmod 400 $PROJECT_DIR/web/sites/default/settings.php
chmod 755 $PROJECT_DIR/vendor/drush
find $PROJECT_DIR/web/sites/default/files -type d -exec chmod 755 {} +
find $PROJECT_DIR/web/sites/default/files -type f -exec chmod 664 {} +
chown -R ec2-user:apache /var/www/drupal
