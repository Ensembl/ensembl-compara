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


use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script extracts statistics (number of genes, size of the alignment)
# about the Ensembl Families
#


## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');


## Get the compara family adaptor
my $family_adaptor = $reg->get_adaptor("Multi", "compara", "Family");

my $all_fam = $family_adaptor->fetch_all;
while (my $f = shift @$all_fam) {
    my $a1 = $f->get_all_Members->[0];
    my $c = $f->Member_count_by_source('ENSEMBLPEP');
    print join("\t", $f->stable_id, scalar(@{$f->get_all_Members}), $c, length($a1->alignment_string)), "\n";
}

