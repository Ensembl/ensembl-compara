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
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::AlignIO;
use Data::Dumper;


#
# Simple example to retrieve the constrained elements from the eutherian 
# mammals 33way EPO_LOW_COVERAGE alignment
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $spp = "Homo sapiens";
my $chr = "15";
my $start = 76336417;
my $end = 76337417;

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved => 0, -fh => \*STDOUT, -format => 'clustalw');

#Create slice from $spp, $chr, $start and $end
my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($spp, "core", "Slice");
my $query_slice = $query_slice_adaptor->fetch_by_region("chromosome",$chr, $start, $end);

# Getting the MethodLinkSpeciesSet adaptor: 
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'MethodLinkSpeciesSet');

#Get constrained element method_list_species_set
my $ce_mlss =  $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name("GERP_CONSTRAINED_ELEMENT", "mammals");

my $orig_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name("EPO_LOW_COVERAGE", "mammals");
throw("Unable to find method_link_species_set") if (!defined($orig_mlss));

#Get constrained_element adaptor
my $ce_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'ConstrainedElement');

#Fetch all constrained elements
my $cons = $ce_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($ce_mlss,$query_slice);

#print Dumper $cons;
print "Number of constrained elements: " . @$cons . "\n";

#Print out information
#Note: where constrained elements occur in overlapping genomic_align_blocks there will be ambiguities
#in aassociating an alignment with the correct constrined_element_id. 
foreach my $ce (@$cons) {
    print "dbID:" . $ce->dbID . " from:" . ($ce->slice->start + $ce->start - 1 ) . " to:" . 
	($ce->slice->start + $ce->end - 1) . " Constrained element score:" . $ce->score . 
	" length:" . ($ce->end - $ce->start)  . " p_value:" . $ce->p_value . " dnafrag_id:". $ce->reference_dnafrag_id . "\n";
	print $alignIO $ce->get_SimpleAlign($orig_mlss, "uc");
}

