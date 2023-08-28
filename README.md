# drupal-github-aws-ci-cd-testing

This repository contains a new Landoified vanilla Drupal 10 site that will be deployed to and AWS EC2 instance using GitHub Actions and AWS CodeDeploy for CI/CD.

Prerequisites:
- AWS account with roles and permissions setup
- EC2 instance for the Drupal Application
- EC2 instance for Sonarqube

# Quick Start
1. [Install lando](https://docs.lando.dev/basics/installation.html)
2. Run composer install
    ```bash
    lando composer install
    ```
3. Create `settings.php` from `default.settings.php` and add the following at the bottom.

    ```bash
    cp web/sites/default/default.settings.php web/sites/default/settings.php
    ```

    ```injectablephp
    $databases['default']['default'] = array (
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

    $settings['config_sync_directory'] = '../config/sync/default';

    $split_filename_prefix = 'config_split.config_split';

    /** Set environment splits. */
    $split_envs = [ 'local', 'dev', 'stage', 'prod' ];

    // Disable all split by default.
    foreach ($split_envs as $split_env) {
      $config["$split_filename_prefix.$split_env"]['status'] = FALSE;
    }

    # manually set environment
    #putenv("ENVIRONMENT=local");

    $split = getenv('ENVIRONMENT');

    // Enable the environment split only if it exists.
    if ($split != FALSE) {
      $config["$split_filename_prefix.$split"]['status'] = TRUE;
    } else {
      $split = 'local';
      $config["$split_filename_prefix.$split"]['status'] = TRUE;
    }
    ```

4. Set the environment you want to use in `defaults.env`

    ```bash
    echo "ENVIRONMENT=local" > ./defaults.env
    ```

5. Start it up and make sure the environment you want is correct

    ```bash
    lando start

    # check env variable is set correctly in the appserver
    lando ssh -s appserver -c env | grep ENVIRONMENT
    ```

6. Set `hash_salt` in `settings.php`

   ```bash
   # generate a random base64 encoded string for hash_salt value
   HASH_SALT=$(lando drush eval "print_r(Drupal\Component\Utility\Crypt::randomBytesBase64(55))")

   # print the generated hash_salt
   echo "Hash Salt: $HASH_SALT"

   # set hash_salt in settings.php
   sed -i "s/^\$settings\['hash_salt'\].*$/\$settings\['hash_salt'\] = '$HASH_SALT';/" web/sites/default/settings.php

   # check settings.php has the generated hash_salt value
   grep hash_salt web/sites/default/settings.php
   ```

7. Install the site using existing configs

    ```bash
    # Install drupal using existing configs
    lando drush site:install -y \
      --account-name=admin \
      --account-pass=admin \
      --existing-config

    # Update database, import configs, and clear cache
    lando deploy
    ```

# Modifying or creating new config spits for an environment
## Modify config for an environment
1. Make sure you have the environment you want to modify set
   ```bash
   # check env variable is set correctly in the appserver
   lando ssh -s appserver -c env | grep ENVIRONMENT

   # change the environment if needed and rebuild
   echo "ENVIRONMENT=local" > ./defaults.env

   lando rebuild
   ```
2. Make the configuration changes you need to make
3. Export the configuration changes
   ```bash
   lando cex
   ```
4. commit the changes and push

## Create a new config split environment
1. Navigate to http://drupal-github-aws-ci-cd-testing_2.lndo.site/admin/config/development/configuration/config-split/add
2. In the user interface enter values for the following fields
   - Label: some_new_environment
   - Folder: ../config/sync/some_new_environment
   - Weight: 1
   - Select the Modules or Items you want to be different from the default configuration
   - click save
3. See the [Modify config for an environment](#modify-config-for-an-environment) section to enable the config split and make any additional changes needed.

