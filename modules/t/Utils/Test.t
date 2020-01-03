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

use File::Spec;
use Test::More tests => 2;

use_ok('Bio::EnsEMBL::Compara::Utils::Test');

subtest 'get_repository_root' => sub {
    my $path = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
    ok(-d $path, "Returned a directory");
    foreach my $subdir (qw(modules scripts sql modules/Bio/EnsEMBL/Compara)) {
        my $subpath = File::Spec->catdir($path, $subdir);
        ok(-d $subpath, "$path has a sub-directory named '$subdir'");
    }
};

done_testing();
