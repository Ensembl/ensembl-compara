#!/usr/bin/env perl
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


# Dump EnsEMBL families into FASTA files, one file per family.
#
# It is more of an example of how to use the API to do things, but it is not optimal for dumping all and everything.

use strict;
use warnings;
use Getopt::Long;
use Bio::EnsEMBL::Registry;

my $continue     =  0;    # skip already dumped families
my $db_version       ;    # needs to be set manually while compara is in production
my $min_fam_size =  1;    # set to 2 to exclude singletons (or even higher)
my $target_dir       ;    # put them there

GetOptions(
    'continue!'      => \$continue,
    'db_version=i'   => \$db_version,
    'min_fam_size=i' => \$min_fam_size,
    'target_dir=s'   => \$target_dir,
);

Bio::EnsEMBL::Registry->load_registry_from_db(
    '-host'       => 'ensembldb.ensembl.org',
    '-user'       => 'anonymous',
    '-db_version' => $db_version,
);

my $family_adaptor = Bio::EnsEMBL::Registry->get_adaptor('multi', 'compara', 'family');

$target_dir = sprintf('family%d_dumps', $family_adaptor->db->get_MetaContainerAdaptor->get_schema_version) unless $target_dir;

my $families = $family_adaptor->fetch_all();

warn "Creating directory '$target_dir'\n";
mkdir($target_dir);

while (my $f = shift @$families) {

    my $family_name = $f->stable_id().'.'.$f->version();
    my $file_name   = "$target_dir/$family_name.fasta";

    if($continue and (-f $file_name)) {
        warn "[Skipping existing $file_name]\n";
        next;
    }

    if (scalar(@{$f->get_all_Members()}) >= $min_fam_size) {
        my $n = $f->print_sequences_to_file($file_name, -id_type => 'VERSION');
        warn "$file_name ($n members)\n";
    }
}

warn "DONE DUMPING\n\n";

