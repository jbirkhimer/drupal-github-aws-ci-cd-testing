#!/bin/bash

PROJECT_DIR="drupal-github-aws-ci-cd-testing"

cd /var/www/drupal/$PROJECT_DIR

# (optional) sometimes get timeout error 'Install of drupal/core failed The following exception is caused by a process timeout' during composer install
/usr/local/bin/composer config process-timeout 2000

/usr/local/bin/composer install

# run drush commands as needed
cd /var/www/drupal/$PROJECT_DIR/web

# fix for bug with hook_install during site:install only allows using existing-config for minimal install profile
# see https://www.drupal.org/project/drupal/issues/2982052 and https://www.drupal.org/node/2897299
sed -i 's|standard|minimal|g' ../config/sync/default/core.extension.yml

../vendor/bin/drush site:install -y \
--account-name=admin \
--account-pass=admin \
--existing-config

../vendor/bin/drush deploy

../vendor/bin/drush state:set system.maintenance_mode FALSE

../vendor/bin/drush cache:rebuild

# permissions
# https://www.drupal.org/forum/support/post-installation/2016-09-22/file-and-directory-permissions-lets-finally-get-this
find /var/www/drupal/$PROJECT_DIR -type d -exec chmod 755 {} +
find /var/www/drupal/$PROJECT_DIR -type f -exec chmod 644 {} +
chmod 444 /var/www/drupal/$PROJECT_DIR/web/.htaccess
chmod 555 /var/www/drupal/$PROJECT_DIR/web/sites/default
chmod 400 /var/www/drupal/$PROJECT_DIR/web/sites/default/settings.php
chmod 755 /var/www/drupal/$PROJECT_DIR/vendor/drush/drush/drush
find /var/www/drupal/$PROJECT_DIR/web/sites/default/files -type d -exec chmod 755 {} +
find /var/www/drupal/$PROJECT_DIR/web/sites/default/files -type f -exec chmod 664 {} +
chown -R ec2-user:apache /var/www/drupal
