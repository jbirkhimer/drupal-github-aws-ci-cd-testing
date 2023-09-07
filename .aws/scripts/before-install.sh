#!/bin/bash

GIT_REPO="jbirkhimer/drupal-github-aws-ci-cd-testing"
PROJECT_DIR=$(basename "$GIT_REPO")

# run drush commands as needed
cd /var/www/drupal/$PROJECT_DIR/web

mkdir -p /home/ec2-user/backups

#tar -zcvf /home/ec2-user/backups/archive-$DEPLOYMENT_ID_$(date +"%Y-%m-%d").tar.gz#
#../vendor/bin/drush sql:dump --gzip --result-file=/home/ec2-user/backups/database-$DEPLOYMENT_ID_$(date +"%Y-%m-%d").sql

../vendor/bin/drush archive:dump -y --destination=/home/ec2-user/backups/archive-$DEPLOYMENT_ID_$(date +"%Y-%m-%d").tar.gz

../vendor/bin/drush state:set system.maintenance_mode TRUE

../vendor/bin/drush cache:rebuild

#rm -f /var/www/app/drupal/$PROJECT_DIR/*
