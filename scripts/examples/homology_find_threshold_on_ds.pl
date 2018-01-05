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

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

## Print the value of "threshold_on_ds" for a pair of species

my $url = 'mysql://anonymous@ensembldb.ensembl.org/ensembl_compara_'.software_version();

GetOptions(
       'url=s'          => \$url,
);

my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url => $url) or die "Must define a url";
my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

die "$0 must be called with two species names.\n" if scalar(@ARGV) != 2;

## Get the MethodLinkSpeciesSet object describing the orthology between the two species
my $this_mlss = $mlss_adaptor->fetch_by_method_link_type_registry_aliases('ENSEMBL_ORTHOLOGUES', \@ARGV);

printf("The dS threshold for %s is %s\n", $this_mlss->name, $this_mlss->get_value_for_tag('threshold_on_ds'));

