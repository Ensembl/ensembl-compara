#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

use JSON qw(decode_json);
use Path::Tiny qw(path);
use Test::More;

use Bio::EnsEMBL::Utils::IO qw/:slurp/;

unless ($ENV{LINUXBREW_HOME}) {
    plan skip_all => 'No linuxbrew installation available ($LINUXBREW_HOME missing)';
}

my $software_config_path = $ARGV[0] || $ENV{ENSEMBL_ROOT_DIR} . '/ensembl-compara/conf/software/SLURM.slurm.json';
die "Cannot find file: $software_config_path\n" unless -e $software_config_path;

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
        my $file = "$ENV{COMPARA_WAREHOUSE}/software/$_[0]";
        ok(-e $file, "$file exists");
        ok(-x $file, "$file is executable");
    } );

find_and_check('check_dir_in_compara', sub {
        my $file = "$ENV{COMPARA_WAREHOUSE}/software/$_[0]";
        ok(-e $file, "$file exists");
        ok(-d $file, "$file is a directory");
    } );

sub find_and_check {
    my ($method, $callback) = @_;
    my $json = decode_json(slurp($software_config_path));

    while (my ($key, $value) = each %$json) {
        if (defined $value && ref($value) eq 'HASH' && exists $value->{'spec'}) {
            $value = $value->{'spec'};
        }

        if (ref($value) eq 'ARRAY') {
            my $func_name = shift @$value;
            next unless $func_name eq $method;
            $callback->(@$value);
        }
    }
}


done_testing();
