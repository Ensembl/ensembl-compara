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

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the compara seqmember adaptor
my $seq_member_adaptor = $reg->get_adaptor("Multi", "compara", "SeqMember");

## Get the member for SwissProt entry O93279
my $seq_member = $seq_member_adaptor->fetch_by_stable_id("O93279");

## Print the stable ID and the sequence
print ">", $seq_member->stable_id(), ":", $seq_member->source_name, "\n";
print $seq_member->sequence(), "\n";

