#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

use strict;
use warnings;

use Path::Tiny qw(path);
use Test::More;

unless ($ENV{LINUXBREW_HOME}) {
    plan skip_all => 'No linuxbrew installation available ($LINUXBREW_HOME missing)';
}

unless ($ENV{ENSEMBL_CVS_ROOT_DIR}) {
    plan skip_all => '$ENSEMBL_CVS_ROOT_DIR is not set. Cannot find the PipeConfigs';
}

my $pipeconfig_path = "$ENV{ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig";

find_and_check('check_file_in_cellar', sub {
        my $file = "$ENV{LINUXBREW_HOME}/Cellar/$_[0]";
        ok(-e $file, "$file exists");
        ok(-r $file, "$file is readable");
    } );

find_and_check('check_exe_in_cellar', sub {
        my $file = "$ENV{LINUXBREW_HOME}/Cellar/$_[0]";
        ok(-e $file, "$file exists");
        ok(-x $file, "$file is executable");
    } );

find_and_check('check_dir_in_cellar', sub {
        my $file = "$ENV{LINUXBREW_HOME}/Cellar/$_[0]";
        ok(-e $file, "$file exists");
        ok(-d $file, "$file is a directory");
    } );

find_and_check('check_exe_in_linuxbrew_opt', sub {
        my $file = "$ENV{LINUXBREW_HOME}/opt/$_[0]";
        ok(-e $file, "$file exists");
        ok(-x $file, "$file is executable");
    } );

find_and_check('check_exe_in_compara', sub {
        my $file = "/nfs/production/panda/ensembl/warehouse/compara/software/$_[0]";
        ok(-e $file, "$file exists");
        ok(-x $file, "$file is executable");
    } );

find_and_check('check_dir_in_compara', sub {
        my $file = "/nfs/production/panda/ensembl/warehouse/compara/software/$_[0]";
        ok(-e $file, "$file exists");
        ok(-d $file, "$file is a directory");
    } );

sub find_and_check {
    my ($method, $callback) = @_;
    my $out = qx(grep -rFH '\$self->$method\(' '$pipeconfig_path');
    my $lastfile = '';
    while ($out =~ /^([^:]*):.*>$method\(["'](.*)["']\)/gm) {
        if ($1 ne $lastfile) {
            note($1);
            $lastfile = $1;
        }
        $callback->($2);
    }
}


done_testing();
