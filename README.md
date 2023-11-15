# drupal-github-aws-ci-cd-testing

This repository contains a new Landoified vanilla Drupal 10 site that will be deployed to and AWS EC2 instance using GitHub Actions and AWS CodeDeploy for CI/CD.

##### Prerequisites:
- [AWS account with roles and permissions setup for CodeDeploy, Cloudformation, and GitHub Actions](#aws-roles-and-permissions-setup-for-codedeploy-cloudformation-and-github-actions)
- [EC2 or local instance of the Drupal Application](#deploying-the-drupal-10-site)
- [EC2 or local instance of Sonarqube](#sonarqube-setup)


# AWS roles and permissions setup for CodeDeploy, Cloudformation, and GitHub Actions
1. Cloudformation roles and permissions
2. CodeDeploy and GitHub Actions roles and permissions
      ```bash
      aws cloudformation create-stack \
         --stack-name "codedeploy-stack" \
         --disable-rollback \
         --region us-gov-west-1 \
         --capabilities CAPABILITY_NAMED_IAM \
         --template-body file://.aws/cloudformation-templates/codedeploy/codedeploy_setup_CF.yaml \
         --parameters file://.aws/cloudformation-templates/codedeploy/parameters.json
      ```
# Github Repository setup
1. [Using environments for deployment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
2. Github Actions
3. [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

# SonarQube Setup
1. Deploying SonarQube
   1. Deploy on AWS using cloudformation
      ```bash
      aws cloudformation create-stack \
         --stack-name "sonarqube-stack" \
         --disable-rollback \
         --region us-gov-west-1 \
         --capabilities CAPABILITY_NAMED_IAM \
         --template-body file://.aws/cloudformation-templates/sonarqube/sonarqube_single_instance_CF_stack.yml \
         --parameters file://.aws/cloudformation-templates/sonarqube/parameters.json
      ```
   2. Deploy Locally with Docker Compose
      ```bash
      cd .aws/cloudformation-templates/sonarqube
      docker compose up -d
      ```
2. Once your instance is up and running, Log in to SonarQube using System Administrator credentials. Set a new admin password when prompted.
   - If you deployed to AWS use the EC2 Public IPv4 address to login.
   - If you deployed locally use http://localhost to login.
   - Default System Administrator credentials:
     - login: admin
     - password: admin
   > [!IMPORTANT]
   > ***Be sure to save your new admin password somewhere safe!***
3. Complete [GitHub Integration](https://docs.sonarsource.com/sonarqube/latest/devops-platform-integration/github-integration/) following SonarQubes documentation.
   > [!IMPORTANT]
   > ***Be sure to save the GitHub Client secret and Private key somewhere safe***
4. To allow users to log in to SonarQube with GitHub credentials follow SonarQube's [Connecting your GitHub App to SonarQube](https://docs.sonarsource.com/sonarqube/10.1/instance-administration/authentication/github/#setting-your-authentication-settings-in-sonarqube) documentation.
5. You should now be ready to start analyzing projects.

# Analyzing projects with GitHub Actions:
1. For basic setup and configuration see [Analyzing projects with GitHub Actions](https://docs.sonarsource.com/sonarqube/latest/devops-platform-integration/github-integration/#analyzing-projects-with-github-actions)
2.

# Deploying the Drupal 10 site
1. Deploy Drupal 10 site
    1. Deploy on AWS using cloudformation
       ```bash
       aws cloudformation create-stack \
          --stack-name "drupal-github-aws-ci-cd-testing-dev" \
          --disable-rollback \
          --region us-gov-west-1 \
          --capabilities CAPABILITY_NAMED_IAM \
          --template-body file://.aws/cloudformation-templates/drupal/drupal10_single_instance_CF_stack.yml \
          --parameters file://.aws/cloudformation-templates/drupal/parameters.json
       ```
    2. Deploy Locally with Docker Compose
       ```bash
       cd .aws/cloudformation-templates/sonarqube
       docker compose up -d
       ```


## Deploy locally with a specific environment
1. [Install lando](https://docs.lando.dev/basics/installation.html)
2. Start the drupal stack for a specific environment
   - OPTION 1 Simple Startup
     ```bash
     # run the start.sh script with the environment (local, dev, stage, prod) as an argument
     ./start.sh dev
     ```
   - OPTION 2: Manual Startup Steps
     <details>
     <summary>Click to Expand</summary>

       1. Run composer install
           ```bash
           lando composer install
           ```
       2. Create `settings.php` from `default.settings.php` and add the following at the bottom.

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
             $config['$split_filename_prefix.$split_env']['status'] = FALSE;
           }

           # manually set environment
           #putenv('ENVIRONMENT=local');

           $split = getenv('ENVIRONMENT');

           // Enable the environment split only if it exists.
           if ($split != FALSE) {
             $config['$split_filename_prefix.$split']['status'] = TRUE;
           } else {
             $split = 'local';
             $config['$split_filename_prefix.$split']['status'] = TRUE;
           }
           ```

       3. Set the environment you want to use in `defaults.env`

           ```bash
           echo "ENVIRONMENT=local" > ./defaults.env
           ```

       4. Start it up and make sure the environment you want is correct

           ```bash
           lando start

           # check env variable is set correctly in the appserver
           lando ssh -s appserver -c env | grep ENVIRONMENT
           ```

       5. Set `hash_salt` in `settings.php`

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

       6. Install the site using existing configs

           ```bash
           # Install drupal using existing configs
           lando drush site:install -y \
             --account-name=admin \
             --account-pass=admin \
             --existing-config

           # Update database, import configs, and clear cache
           lando deploy
           ```

     </details>

# Creating or Modifying Drupal site config spits for an environment
## Create a new config split environment
1. Navigate to http://drupal-github-aws-ci-cd-testing_2.lndo.site/admin/config/development/configuration/config-split/add
2. In the user interface enter values for the following fields
   - Label: some_new_environment
   - Folder: ../config/sync/some_new_environment
   - Weight: 1
   - Select the Modules or Items you want to be different from the default configuration
   - click save
3. See the [Modify config for an environment](#modify-config-for-an-environment) section to enable the config split and make any additional changes needed.

## Modify config split for an environment
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

