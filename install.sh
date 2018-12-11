#!/bin/sh

set -ue

BASE_DIR="/var/task"
WORK_DIR="tmp"

mkdir "${WORK_DIR}"
cd "${WORK_DIR}"

# mecab https://drive.google.com/open?id=0B4y35FiV1wh7cENtOXlicTFaRUE
curl -L -o mecab.tar.gz "https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7cENtOXlicTFaRUE"
mkdir mecab && tar zxfv mecab.tar.gz -C mecab --strip-components 1
cd mecab
./configure  --enable-utf8-only --prefix=/opt
make
make install
cd ..

# mecab ipadic https://drive.google.com/open?id=0B4y35FiV1wh7MWVlSDBCSXZMTXM
curl -L -o mecab-ipadic.tar.gz "https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7MWVlSDBCSXZMTXM"
mkdir mecab-ipadic && tar zxfv mecab-ipadic.tar.gz  -C mecab-ipadic --strip-components 1
cd mecab-ipadic
./configure --with-mecab-config=/opt/bin/mecab-config --with-charset=utf8 --prefix=/opt
make
make install
cd ..

# perl
curl -L https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - "5.28.0" /opt/
curl -L https://cpanmin.us | /opt/bin/perl - App::cpanminus
/opt/bin/cpanm -n --installdeps --interactive "$BASE_DIR"

rm -rf "${BASE_DIR}/${WORK_DIR}"
