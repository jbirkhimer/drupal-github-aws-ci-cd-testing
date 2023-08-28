#!/bin/bash

if [ -z "$1" ]; then
  echo 'Please provide an environment to use. Ex. ./start.sh {local, dev, stage, prod}'
  exit 0
fi

ENVIRONMENT=$1

echo "Starting using ENVIRONMENT: $ENVIRONMENT"

# Run composer install
lando composer install

# Create `settings.php` from `default.settings.php` and add the following at the bottom.
cp web/sites/default/default.settings.php web/sites/default/settings.php

cat >> web/sites/default/settings.php <<EOF
\$databases['default']['default'] = array (
  'database' => 'drupal10',
  'username' => 'drupal10',
  'password' => 'drupal10',
  'prefix' => '',
  'host' => 'database',
  'port' => '',
  'isolation_level' => 'READ COMMITTED',
  'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
  'driver' => 'mysql',
  'autoload' => 'core/modules/mysql/src/Driver/Database/mysql/',
);

\$settings['config_sync_directory'] = '../config/sync/default';

\$split_filename_prefix = 'config_split.config_split';

/** Set environment splits. */
\$split_envs = [ 'local', 'dev', 'stage', 'prod' ];

// Disable all split by default.
foreach (\$split_envs as \$split_env) {
  \$config["\$split_filename_prefix.\$split_env"]['status'] = FALSE;
}

# manually set environment
#putenv("ENVIRONMENT=$ENVIRONMENT");

\$split = getenv('ENVIRONMENT');

// Enable the environment split only if it exists.
if (\$split != FALSE) {
  \$config["\$split_filename_prefix.\$split"]['status'] = TRUE;
} else {
  \$split = 'local';
  \$config["\$split_filename_prefix.\$split"]['status'] = TRUE;
}
EOF

# Set the environment you want to use in `defaults.env`
echo "ENVIRONMENT=$ENVIRONMENT" > ./defaults.env

# Start it up and make sure the environment you want is correct
lando start

# check env variable is set correctly in the appserver
lando ssh -s appserver -c env | grep ENVIRONMENT

HASH_SALT=$(lando drush eval "print_r(Drupal\Component\Utility\Crypt::randomBytesBase64(55))")
echo "Hash Salt: $HASH_SALT"
sed -i "s/^\$settings\['hash_salt'\].*$/\$settings\['hash_salt'\] = '$HASH_SALT';/" web/sites/default/settings.php

# Install drupal using existing configs
lando drush site:install -y \
  --account-name=admin \
  --account-pass=admin \
  --existing-config

# Update database, import configs, and clear cache
lando deploy
