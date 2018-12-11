#!/bin/sh

set -ue

BASE_DIR="/var/task"

cd "/opt" || exit 1

cp "${BASE_DIR}/bootstrap" .
chmod 755 'bootstrap'

zip -r "${BASE_DIR}/lambda-perl-mecab.zip" .
