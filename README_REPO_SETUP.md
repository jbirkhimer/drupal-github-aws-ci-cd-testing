# How this Repo was created (FOR REFERENCE ONLY)

Set up repository with a new Landoified vanilla Drupal 10 site with Configuration Split for `dev`, `stage`, and `prod` environments.

1. [Install lando](https://docs.lando.dev/basics/installation.html)
2. Spin up a new Landoified vanilla Drupal site
   ```bash
    # Initialize a drupal10 recipe
    mkdir drupal-github-aws-ci-cd-testing \
    && cd drupal-github-aws-ci-cd-testing \
    && lando init \
    --source cwd \
    --recipe drupal10 \
    --webroot web \
    --name drupal-github-aws-ci-cd-testing

    # Create latest drupal10 project via composer
    lando composer create-project drupal/recommended-project:^10 tmp && cp -r tmp/. . && rm -rf tmp

    # Start it up
    lando start

    # Install a site local drush, config_split, and environment_indicator
    lando composer require drush/drush drupal/config_split drupal/environment_indicator

    # Install drupal
    lando drush site:install -y \
      --site-name=drupal-github-aws-ci-cd-testing \
      --account-name=admin \
      --account-pass=admin \
      --db-url=mysql://drupal10:drupal10@database/drupal10

    # List information about this app
    lando info
    ```

   ***(OPTIONAL)*** In `.lando.yml` file change the default database from `mysql:5.7` to `mysql:8.0` by adding `database: mysql:8.0` under config.

    ```yaml
    config:
      webroot: web
      database: mysql:8.0
    ```
   > **NOTE:** mysql:5.7 docker container used by the lando drupal10 recipe may cause extremely high memory usage on some machines. Use mysql:8.0 instead.

    Add custom lando tooling to `.lando.yml`

    ```yaml
    env_file:
      - defaults.env
    tooling:
      deploy:
        service: appserver
        description: "Run drupal database updates, cache rebuild, config import"
        cmd: drush deploy -y
        stdout:
          description: Running drupal deploy
      cr:
        service: appserver
        description: "Rebuild drupal caches"
        cmd: drush cr -y
        stdout:
          description: Rebuilding drupal caches
      cim:
        service: appserver
        description: "Import drupal configuration"
        cmd: drush cim -y
        stdout:
          description: Importing drupal configuration
      cex:
        service: appserver
        description: "Export drupal configuration"
        cmd: drush cex -y
        stdout:
          description: Exporting drupal configuration
      entup:
        service: appserver
        description: "Drupal entities update"
        cmd: drush entup -y
        stdout:
          description: Updating drupal entities
      updb:
        service: appserver
        description: "Run drupal database updates"
        cmd: drush updb -y
        stdout:
          description: Running drupal database updates
    ```
3. Create `defaults.env` in the project root dir and rebuild lando for changes to take effect.
    ```bash
    echo "ENVIRONMENT=local" > ./defaults.env

    lando rebuild -y

    # check env variable is set correctly in the appserver
    lando ssh -s appserver -c env | grep ENVIRONMENT
    ```
4. Change permissions and modify `web/sites/default/settings.php` and add the following to set the `config_sync_directory` path and activate `config_split` for the environment we are using
    ```bash
    # change permissions on settings.php so we can edit it
    chmod 755 web/sites/default web/sites/default/settings.php
    ```
    ```injectablephp
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
5. Create the drupal config split dir's
    ```bash
    mkdir -p ./config/sync/{default,local,dev,stage,prod}
    ```
6. Enable Config Split and Environment Indicator Modules
   ```bash
   lando drush en config_split environment_indicator environment_indicator_ui -y
   ```
7. Change Site Name and Set Module permissions to enable Environment Indicators for all users
   - navigate to http://drupal-github-aws-ci-cd-testing.lndo.site/admin/config/system/site-information
     - change the site name to `drupal-github-aws-ci-cd-testing (DEFAULT)`
     - save configuration
   - navigate to http://drupal-github-aws-ci-cd-testing.lndo.site/admin/people/permissions/module/environment_indicator
     - check all boxes for **See all environment indicators** and **See all the environment indicators in the site.**
     - Save permissions
8. Export the default configuration for the application. The default configuration is the configuration imported for your application, by default, even if no splits are defined or active. The default configuration will be shared by all websites using the application.
   ```bash
   lando cex
   ```
9. Add config split settings for `local`.
   - make sure the `ENVIRNMENT` variable is set to `local` in `defaults.env` file or manually set it in `settings.php`
     - `echo "ENVIRONMENT=local" > ./defaults.env`
     - `lando rebuild -y`
     - `lando deploy`
   - navigate to http://drupal-github-aws-ci-cd-testing.lndo.site/admin/config/development/environment-indicator/current
     - set `Foreground Color` to white rgb value `255,255,255`
     - set `Background Color` to black rgb value `0,0,0`
     - click save configuration
   - navigate to http://drupal-github-aws-ci-cd-testing.lndo.site/admin/config/system/site-information
     - change the site name to `drupal-github-aws-ci-cd-testing (LOCAL)`
   - navigate to http://drupal-github-aws-ci-cd-testing.lndo.site/admin/config/development/configuration/config-split/add
   - in the user interface enter values for the following fields
     - Label: local
     - Folder: ../config/sync/local
     - Weight: 1
     - navigate to **Complete Split > Configuration Items** and select `environment_indicator.indicator`
     - navigate to **Conditional Split > Configuration Items** and select `system.site`
   - save the changes
   - run `lando cex`
   - run `lando deploy`
   - after a browser refresh you should now see the Site Name change, the toolbar color change, and the config split active for the environment
10. Repeat Step 9 for `dev`, `stage`, and `prod` using the values below.
    - dev
      - Label: dev
      - Folder: ../config/sync/dev
      - Site Name: `drupal-github-aws-ci-cd-testing (DEV)`
      - Foreground Color: `255,255,255`
      - Background Color: `13,109,253`
    - stage
      - Label: stage
      - Folder: ../config/sync/stage
      - Site Name: `drupal-github-aws-ci-cd-testing (STAGE)`
      - Foreground Color: `255,255,255`
      - Background Color: `255,193,7`
    - prod
      - Label: local
      - Folder: ../config/sync/local
      - Site Name: `drupal-github-aws-ci-cd-testing (PROD)`
      - Foreground Color: `255,255,255`
      - Background Color: `220,53,70`

## You should now have the following directory structure and configurations for each environment:

```bash
config
└── sync
    ├── default
    │   ├── automated_cron.settings.yml
    │   ├── block.block.claro_breadcrumbs.yml
    │   ├── block.block.claro_content.yml
    │   ├── block.block.claro_help.yml
    │   ├── block.block.claro_local_actions.yml
    │   ├── block.block.claro_messages.yml
    │   ├── block.block.claro_page_title.yml
    │   ├── block.block.claro_primary_local_tasks.yml
    │   ├── block.block.claro_secondary_local_tasks.yml
    │   ├── block.block.olivero_account_menu.yml
    │   ├── block.block.olivero_breadcrumbs.yml
    │   ├── block.block.olivero_content.yml
    │   ├── block.block.olivero_help.yml
    │   ├── block.block.olivero_main_menu.yml
    │   ├── block.block.olivero_messages.yml
    │   ├── block.block.olivero_page_title.yml
    │   ├── block.block.olivero_powered.yml
    │   ├── block.block.olivero_primary_admin_actions.yml
    │   ├── block.block.olivero_primary_local_tasks.yml
    │   ├── block.block.olivero_search_form_narrow.yml
    │   ├── block.block.olivero_search_form_wide.yml
    │   ├── block.block.olivero_secondary_local_tasks.yml
    │   ├── block.block.olivero_site_branding.yml
    │   ├── block.block.olivero_syndicate.yml
    │   ├── block_content.type.basic.yml
    │   ├── claro.settings.yml
    │   ├── comment.settings.yml
    │   ├── comment.type.comment.yml
    │   ├── config_split.config_split.dev.yml
    │   ├── config_split.config_split.local.yml
    │   ├── config_split.config_split.prod.yml
    │   ├── config_split.config_split.stage.yml
    │   ├── contact.form.feedback.yml
    │   ├── contact.form.personal.yml
    │   ├── contact.settings.yml
    │   ├── core.base_field_override.node.page.promote.yml
    │   ├── core.date_format.fallback.yml
    │   ├── core.date_format.html_datetime.yml
    │   ├── core.date_format.html_date.yml
    │   ├── core.date_format.html_month.yml
    │   ├── core.date_format.html_time.yml
    │   ├── core.date_format.html_week.yml
    │   ├── core.date_format.html_yearless_date.yml
    │   ├── core.date_format.html_year.yml
    │   ├── core.date_format.long.yml
    │   ├── core.date_format.medium.yml
    │   ├── core.date_format.olivero_medium.yml
    │   ├── core.date_format.short.yml
    │   ├── core.entity_form_display.block_content.basic.default.yml
    │   ├── core.entity_form_display.comment.comment.default.yml
    │   ├── core.entity_form_display.node.article.default.yml
    │   ├── core.entity_form_display.node.page.default.yml
    │   ├── core.entity_form_display.user.user.default.yml
    │   ├── core.entity_form_mode.user.register.yml
    │   ├── core.entity_view_display.block_content.basic.default.yml
    │   ├── core.entity_view_display.comment.comment.default.yml
    │   ├── core.entity_view_display.node.article.default.yml
    │   ├── core.entity_view_display.node.article.rss.yml
    │   ├── core.entity_view_display.node.article.teaser.yml
    │   ├── core.entity_view_display.node.page.default.yml
    │   ├── core.entity_view_display.node.page.teaser.yml
    │   ├── core.entity_view_display.user.user.compact.yml
    │   ├── core.entity_view_display.user.user.default.yml
    │   ├── core.entity_view_mode.block_content.full.yml
    │   ├── core.entity_view_mode.comment.full.yml
    │   ├── core.entity_view_mode.node.full.yml
    │   ├── core.entity_view_mode.node.rss.yml
    │   ├── core.entity_view_mode.node.search_index.yml
    │   ├── core.entity_view_mode.node.search_result.yml
    │   ├── core.entity_view_mode.node.teaser.yml
    │   ├── core.entity_view_mode.taxonomy_term.full.yml
    │   ├── core.entity_view_mode.user.compact.yml
    │   ├── core.entity_view_mode.user.full.yml
    │   ├── core.extension.yml
    │   ├── core.menu.static_menu_link_overrides.yml
    │   ├── dblog.settings.yml
    │   ├── editor.editor.basic_html.yml
    │   ├── editor.editor.full_html.yml
    │   ├── environment_indicator.settings.yml
    │   ├── field.field.block_content.basic.body.yml
    │   ├── field.field.comment.comment.comment_body.yml
    │   ├── field.field.node.article.body.yml
    │   ├── field.field.node.article.comment.yml
    │   ├── field.field.node.article.field_image.yml
    │   ├── field.field.node.article.field_tags.yml
    │   ├── field.field.node.page.body.yml
    │   ├── field.field.user.user.user_picture.yml
    │   ├── field.settings.yml
    │   ├── field.storage.block_content.body.yml
    │   ├── field.storage.comment.comment_body.yml
    │   ├── field.storage.node.body.yml
    │   ├── field.storage.node.comment.yml
    │   ├── field.storage.node.field_image.yml
    │   ├── field.storage.node.field_tags.yml
    │   ├── field.storage.user.user_picture.yml
    │   ├── field_ui.settings.yml
    │   ├── file.settings.yml
    │   ├── filter.format.basic_html.yml
    │   ├── filter.format.full_html.yml
    │   ├── filter.format.plain_text.yml
    │   ├── filter.format.restricted_html.yml
    │   ├── filter.settings.yml
    │   ├── .htaccess
    │   ├── image.settings.yml
    │   ├── image.style.large.yml
    │   ├── image.style.medium.yml
    │   ├── image.style.thumbnail.yml
    │   ├── image.style.wide.yml
    │   ├── menu_ui.settings.yml
    │   ├── node.settings.yml
    │   ├── node.type.article.yml
    │   ├── node.type.page.yml
    │   ├── olivero.settings.yml
    │   ├── search.page.node_search.yml
    │   ├── search.page.user_search.yml
    │   ├── search.settings.yml
    │   ├── shortcut.set.default.yml
    │   ├── system.action.comment_delete_action.yml
    │   ├── system.action.comment_publish_action.yml
    │   ├── system.action.comment_save_action.yml
    │   ├── system.action.comment_unpublish_action.yml
    │   ├── system.action.node_delete_action.yml
    │   ├── system.action.node_make_sticky_action.yml
    │   ├── system.action.node_make_unsticky_action.yml
    │   ├── system.action.node_promote_action.yml
    │   ├── system.action.node_publish_action.yml
    │   ├── system.action.node_save_action.yml
    │   ├── system.action.node_unpromote_action.yml
    │   ├── system.action.node_unpublish_action.yml
    │   ├── system.action.taxonomy_term_publish_action.yml
    │   ├── system.action.taxonomy_term_unpublish_action.yml
    │   ├── system.action.user_add_role_action.administrator.yml
    │   ├── system.action.user_add_role_action.content_editor.yml
    │   ├── system.action.user_block_user_action.yml
    │   ├── system.action.user_cancel_user_action.yml
    │   ├── system.action.user_remove_role_action.administrator.yml
    │   ├── system.action.user_remove_role_action.content_editor.yml
    │   ├── system.action.user_unblock_user_action.yml
    │   ├── system.advisories.yml
    │   ├── system.cron.yml
    │   ├── system.date.yml
    │   ├── system.diff.yml
    │   ├── system.feature_flags.yml
    │   ├── system.file.yml
    │   ├── system.image.gd.yml
    │   ├── system.image.yml
    │   ├── system.logging.yml
    │   ├── system.mail.yml
    │   ├── system.maintenance.yml
    │   ├── system.menu.account.yml
    │   ├── system.menu.admin.yml
    │   ├── system.menu.footer.yml
    │   ├── system.menu.main.yml
    │   ├── system.menu.tools.yml
    │   ├── system.performance.yml
    │   ├── system.rss.yml
    │   ├── system.site.yml
    │   ├── system.theme.global.yml
    │   ├── system.theme.yml
    │   ├── taxonomy.settings.yml
    │   ├── taxonomy.vocabulary.tags.yml
    │   ├── text.settings.yml
    │   ├── tour.tour.block-layout.yml
    │   ├── tour.tour.views-ui.yml
    │   ├── update.settings.yml
    │   ├── user.flood.yml
    │   ├── user.mail.yml
    │   ├── user.role.administrator.yml
    │   ├── user.role.anonymous.yml
    │   ├── user.role.authenticated.yml
    │   ├── user.role.content_editor.yml
    │   ├── user.settings.yml
    │   ├── views.settings.yml
    │   ├── views.view.archive.yml
    │   ├── views.view.block_content.yml
    │   ├── views.view.comments_recent.yml
    │   ├── views.view.comment.yml
    │   ├── views.view.content_recent.yml
    │   ├── views.view.content.yml
    │   ├── views.view.files.yml
    │   ├── views.view.frontpage.yml
    │   ├── views.view.glossary.yml
    │   ├── views.view.taxonomy_term.yml
    │   ├── views.view.user_admin_people.yml
    │   ├── views.view.watchdog.yml
    │   ├── views.view.who_s_new.yml
    │   └── views.view.who_s_online.yml
    ├── dev
    │   ├── environment_indicator.indicator.yml
    │   ├── .htaccess
    │   └── system.site.yml
    ├── local
    │   ├── environment_indicator.indicator.yml
    │   ├── .htaccess
    │   └── system.site.yml
    ├── prod
    │   ├── environment_indicator.indicator.yml
    │   ├── .htaccess
    │   └── system.site.yml
    └── stage
        ├── environment_indicator.indicator.yml
        ├── .htaccess
        └── system.site.yml
```

