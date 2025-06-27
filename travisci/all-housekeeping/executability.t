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

use Test::More;

use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::Utils::Test;

my @all_files = Bio::EnsEMBL::Compara::Utils::Test::find_all_files();

my @executable_extensions = qw(pl py r sh);
my $regex_str = join(q{|}, map {qq{\\.$_\$}} @executable_extensions);
my $regex = qr/($regex_str)/;

foreach my $f (@all_files) {
    # General exclusions
    next if $f =~/\/blib\//;
    # General rule
    my $should_be_executable = ($f =~ /$regex/);
    # Exceptions
    $should_be_executable = '' if $f =~ /\bdocs\/conf\.py$/;
    $should_be_executable = '' if $f =~ /(production|dumps).*reg_conf.*\.pl$/;
    $should_be_executable = '' if $f =~ /\bsrc\/python\/.*\.py$/;
    $should_be_executable = '' if $f =~ /\bpipelines\/(.*)\/scripts\/.*\.py$/ && $1 ne 'HalCacheChain';
    $should_be_executable = '' if $f =~ /\/conftest\.py$/;
    $should_be_executable = '' if $f =~ /\bsetup\.py$/;
    # Test
    is(-x $f, $should_be_executable, "$f is executable");
}

done_testing();
