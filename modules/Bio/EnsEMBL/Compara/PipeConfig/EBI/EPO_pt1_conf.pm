=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_pt1_conf

=head1 SYNOPSIS

    EBI-specific configuration for the EPO_pt1 pipeline. Options to check before
    initializing the pipeline:

	    'compara_pairwise_db' - I'm assuiming that all of your pairwise alignments are in one compara db
	    'reference_genome_db_name' - the production name of the species which is in all your pairwise alignments
	    
      'main_core_dbs' - the servers(s) hosting most/all of the core (species) dbs
	    'core_db_urls' - any additional core dbs (not in 'main_core_dbs')

    #1. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_pt1_conf -core_db_version

    #2. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

=head1 DESCRIPTION  

    This configuaration file gives defaults for the first part of the EPO pipeline (this part generates the anchors from pairwise alignments). 

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EPO_pt1_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EPO_pt1_conf');

sub default_options {
    my ($self) = @_;

    return {
      	%{$self->SUPER::default_options},

        # When initializing the pipeline, give it the mlss_id of type EPO_GEN_ANCHORS that contains the species of interest.

        # And then choose one of these
        # 'species_set_name' => 'sauropsids',
        # 'reference_genome_db_name' => 'gallus_gallus',
        #'species_set_name' => 'mammals',
        #'reference_genome_db_name' => 'homo_sapiens',
        #'species_set_name' => 'fish',
        #'reference_genome_db_name' => 'oryzias_latipes',

        'division' => 'vertebrates',

        'master_db' => 'compara_master',
      	  
        # database containing the pairwise alignments needed to get the overlaps
      	'compara_pairwise_db' => 'compara_curr',
    };
}


1;
