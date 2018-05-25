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



=head
desc: This script takes as input the desired coordinates on the genome of a given species and uses the genomic aligns block object and the mapper object to map those coordinates
to their corresponding aligned coordinates on a target species genome.
output: the output is an array of paired hash objects each pair respresenting a one to one mapping of the aligned coordinates on both source and target species

ex: perl map_coordinates.pl --mlss_id 225 --source_sp Stickleback --target_sp (optional) --coord_system_name scaffold --seq_region_name scaffold_150 --start 167602 --end 167999
	perl map_coordinates.pl --mlss_id 1134 --source_sp macaca_fascicularis --coord_system_name chromosome --seq_region_name 5 --start 890166 --end 890366 --target_sp nomascus_leucogenys
=cut





use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::Projection;
use Bio::AlignIO;
use Getopt::Long;
use Data::Dumper;
use POSIX qw[ _exit ];
my $start_run = time();

my ($mlss_id, $source_sp, $target_sp, $coord_system_name, $seq_region_name, $start, $end, $verbose);

GetOptions ("mlss_id=s" 			=> \$mlss_id,    # numeric
			"source_sp=s" 				=> \$source_sp,
			"target_sp=s"				=> \$target_sp, #optional only needed if we are using multiple genome alignments
			"coord_system_name=s" 	=> \$coord_system_name, #for the slice adaptor object , scaffold
			"seq_region_name=s" 		=> \$seq_region_name, #scaffold_150
            "start=i"   			=> \$start,     #slice start 
            "end=i"  				=> \$end,   # slice end 
            "verbose|v"  => \$verbose)   # flag
or die("Error in command line arguments\n");

#my $reg_conf  = '/nfs/production/panda/ensembl/compara/waakanni/SCRIPTS/Example_reg.conf';
my $DB_species = 'Multi';
my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org/92');
#$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");


my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
my $methodLinkSpeciesSet = $method_link_species_set_adaptor->fetch_by_dbID($mlss_id);


if ($methodLinkSpeciesSet->method()->class ne 'GenomicAlignBlock.pairwise_alignment' && $target_sp eq '') {
	die "you have given an mlss_id for a multiple WGA but have forgotten to give your preferred target species";
}

my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($source_sp, "core", "Slice");
my $slice = $slice_adaptor->fetch_by_region($coord_system_name,$seq_region_name, $start, $end );#'scaffold','scaffold_150',167602,167999
my $overall_linked = Bio::EnsEMBL::Compara::Utils::Projection::project_Slice_to_target_genome($slice,$methodLinkSpeciesSet,$target_sp);
print Dumper($overall_linked);
