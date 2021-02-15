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

use File::Spec;
use Test::More;
use Test::Warnings;

use Bio::EnsEMBL::Compara::Utils::Test;

eval {
  require Test::Perl::Critic;
  require Perl::Critic::Utils;
};
if($@) {
  plan( skip_all => 'Test::Perl::Critic required.' );
  note $@;
}

my $root = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();

# Configure critic
Test::Perl::Critic->import(-profile => File::Spec->catfile($root, 'perlcriticrc'), -severity => 5, -verbose => 8);

my @all_files = Bio::EnsEMBL::Compara::Utils::Test::find_all_files();

foreach my $f (@all_files) {
  next unless $f =~ /\.(t|p[lm])$/i;
  # Except the fake libraries
  next if $f =~ /\/fake_libs\//;
  # And the HALXS build directory
  next if $f =~ /\/HALXS\/blib\//;
  critic_ok($f);
}

done_testing();
