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


use Test::Exception;
use Test::More;

use Bio::EnsEMBL::Compara::Utils::Test;
use Bio::EnsEMBL::Compara::Utils::FlatFile;

sub is_valid_tsv {
    my $filename = shift;
    my $delim    = shift;

    lives_ok(
        sub { Bio::EnsEMBL::Compara::Utils::FlatFile::check_column_integrity($filename, $delim); },
        "All lines of $filename have the same number of columns"
    );
}

my @all_files = Bio::EnsEMBL::Compara::Utils::Test::find_all_files();

foreach my $f (@all_files) {
    if ($f =~ /\.tsv$/) {
        is_valid_tsv($f, '\t');
    } elsif ($f =~ /\.matrix$/) {
        is_valid_tsv($f, ' ');
    }
}

done_testing();

