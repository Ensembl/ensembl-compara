#!/bin/bash

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



# Bail out if anything goes wrong
set -e

# Restart from a clean state
rm -rf "$1"
mkdir -p "$1"
cd "$1"

mkdir packages
cd packages
# List of extra packages we need
echo http://archive.ubuntu.com/ubuntu/pool/main/libd/libdbi-perl/libdbi-perl_1.634-1build1_amd64.deb \
     http://archive.ubuntu.com/ubuntu/pool/universe/libd/libdbd-sqlite3-perl/libdbd-sqlite3-perl_1.50-1_amd64.deb \
     http://archive.ubuntu.com/ubuntu/pool/main/libj/libjson-xs-perl/libjson-xs-perl_3.010-2build1_amd64.deb \
     http://archive.ubuntu.com/ubuntu/pool/main/libj/libjson-perl/libjson-perl_2.90-1_all.deb \
     http://archive.ubuntu.com/ubuntu/pool/main/libc/libcommon-sense-perl/libcommon-sense-perl_3.74-1build1_amd64.deb \
     http://archive.ubuntu.com/ubuntu/pool/main/libt/libtypes-serialiser-perl/libtypes-serialiser-perl_1.0-1_all.deb \
     http://archive.ubuntu.com/ubuntu/pool/universe/libx/libxml-xpath-perl/libxml-xpath-perl_1.30-1_all.deb \
     http://archive.ubuntu.com/ubuntu/pool/universe/libp/libparse-recdescent-perl/libparse-recdescent-perl_1.967013+dfsg-1_all.deb \
     http://archive.ubuntu.com/ubuntu/pool/main/libi/libipc-run-perl/libipc-run-perl_0.94-1_all.deb \
     http://archive.ubuntu.com/ubuntu/pool/main/libi/libio-pty-perl/libio-pty-perl_1.08-1.1build1_amd64.deb \
     http://archive.ubuntu.com/ubuntu/pool/universe/libg/libgraphviz-perl/libgraphviz-perl_2.20-1_all.deb \
     http://archive.ubuntu.com/ubuntu/pool/universe/d/doxypy/doxypy_0.4.2-1.1_all.deb \
     http://archive.ubuntu.com/ubuntu/pool/universe/libp/libproc-daemon-perl/libproc-daemon-perl_0.23-1_all.deb \
     http://archive.ubuntu.com/ubuntu/pool/universe/libd/libdbd-mysql-perl/libdbd-mysql-perl_4.033-1build2_amd64.deb \
     http://archive.ubuntu.com/ubuntu/pool/main/m/mysql-5.7/libmysqlclient20_5.7.11-0ubuntu6_amd64.deb \
     http://archive.ubuntu.com/ubuntu/pool/main/m/mysql-5.7/mysql-common_5.7.11-0ubuntu6_all.deb \
| xargs -n 1 curl -O

mkdir ../root
for i in *.deb; do dpkg -x "$i" ../root/; done

