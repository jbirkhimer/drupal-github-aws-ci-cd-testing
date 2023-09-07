#!/bin/bash

GIT_REPO="jbirkhimer/drupal-github-aws-ci-cd-testing"
PROJECT_DIR="/var/www/drupal/$(basename "$GIT_REPO")"
BACKUP_DIR="/home/ec2-user/backups"
BACKUP_FILE="${BACKUP_DIR}/archive-${DEPLOYMENT_ID}_$(date +"%Y-%m-%d").tar.gz"
# run drush commands as needed
cd "$PROJECT_DIR"/web || { echo "ERROR: $PROJECT_DIR/web does not exist!"; exit 1; }

mkdir -p $BACKUP_DIR

#tar -zcvf $BACKUP_DIR/archive-$DEPLOYMENT_ID_$(date +"%Y-%m-%d").tar.gz#
#../vendor/bin/drush sql:dump --gzip --result-file=$BACKUP_DIR/database-$DEPLOYMENT_ID_$(date +"%Y-%m-%d").sql

../vendor/bin/drush archive:dump -y --destination=BACKUP_FILE

../vendor/bin/drush state:set system.maintenance_mode TRUE

../vendor/bin/drush cache:rebuild
