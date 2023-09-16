#!/bin/bash
#
# This script downloads and sets up WordPress for contributing.
#
# WordPressDev, Copyright 2019 Google LLC
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

if [[ -z "$LANDO_MOUNT" ]]; then
    echo "Error: Must be run the appserver.";
    exit 1
fi

set -ex

if [[ ! -e "$LANDO_MOUNT/public/core-dev" ]]; then
    git clone https://github.com/WordPress/wordpress-develop.git "$LANDO_MOUNT/public/core-dev"
fi

if [[ ! -e "$LANDO_MOUNT/public/core-dev/.svn" ]]; then
    cd "$LANDO_MOUNT"
    if svn co --ignore-externals https://develop.svn.wordpress.org/trunk/ tmp-svn; then
        mv tmp-svn/.svn public/core-dev/.svn
        rm -rf tmp-svn
    else
        echo "SVN failed to install. Nevertheless, you should still be able to run WordPress."
        if [[ -e tmp-svn ]]; then
            rm -rf tmp-svn
        fi
    fi
fi

cd "$LANDO_MOUNT/public/core-dev"

if [[ ! -e "wp-config.php" ]]; then
    echo -e "<?php // DO NOT EDIT THIS FILE!\nrequire dirname( __FILE__ ) . '/../wp-config.php';\nrequire_once ABSPATH . 'wp-settings.php';" > wp-config.php
fi
if [[ ! -e "wp-tests-config.php" ]]; then
    echo -e "<?php // DO NOT EDIT THIS FILE!\nrequire dirname( __FILE__ ) . '/../wp-tests-config.php';" > wp-tests-config.php
fi

if [[ ! -e "$LANDO_MOUNT/public/core-dev/vendor" ]]; then
    cd $LANDO_MOUNT/public/core-dev
    composer install
fi

if [[ ! -e "$LANDO_MOUNT/public/core-dev/node_modules" ]]; then
    cd "$LANDO_MOUNT/public/core-dev"
    npm install
fi

if [[ ! -e "$LANDO_MOUNT/public/core-dev/build" ]]; then
    cd "$LANDO_MOUNT/public/core-dev"
    npx grunt
fi

cd "$LANDO_MOUNT/public/core-dev"
if ! git config -l --local | grep -q 'alias.svn-up'; then
    git config alias.svn-up '! ../../bin/svn-git-up $1';
fi

# Sleep for 5 seconds to allow the database to start.
sleep 5

if ! wp core is-installed; then
  wp core install --url="https://$LANDO_APP_NAME.$LANDO_DOMAIN/" --title="WordPress Develop" --admin_name="admin" --admin_email="admin@local.test" --admin_password="password"
  wp rewrite structure '/%year%/%monthnum%/%day%/%postname%/'
fi
