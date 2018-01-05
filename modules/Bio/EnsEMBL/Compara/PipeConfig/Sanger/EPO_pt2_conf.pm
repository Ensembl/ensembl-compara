=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Sanger::EPO_pt2_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Check all default_options, you will probably need to change the following :
        pipeline_db (-host)
        resource_classes 

	'ensembl_cvs_root_dir' - the path to the compara/hive/ensembl GIT checkouts - set as an environment variable in your shell
        'password' - your mysql password
	'compara_anchor_db' - database containing the anchor sequences (entered in the anchor_sequence table)
	'compara_master' - location of your master db containing relevant info in the genome_db, dnafrag, species_set, method_link* tables
        The dummy values - you should not need to change these unless they clash with pre-existing values associated with the pairwise alignments you are going to use

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EPO_pt2_conf.pm

    #5. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

    #6. Fix the code when it crashes
=head1 DESCRIPTION  

    This configuaration file gives defaults for mapping (using exonerate at the moment) anchors to a set of target genomes (dumped text files)

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::EPO_pt2_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EPO_pt2_conf');

sub default_options {
    my ($self) = @_;

    return {
	%{$self->SUPER::default_options},

    'species_set_name' => '17mammals_reuse',
 
    # Where the pipeline lives
    'host'  => 'compara2',

	# database containing the anchors for mapping
	'compara_anchor_db' => 'mysql://ensro@compara3/sf5_TEST_gen_anchors_mammals_cat_100',

	'mapping_exe' => "/software/ensembl/compara/exonerate/exonerate",
    'ortheus_c_exe' => '/software/ensembl/compara/OrtheusC/bin/OrtheusC',
	
	 # place to dump the genome sequences
	'seq_dump_loc' => '/data/blastdb/Ensembl/' . 'compara_genomes_test_' . $self->o('ensembl_release'),
	
    'compara_master' => 'mysql://ensro@compara1/mm14_ensembl_compara_master',
     };
}

1;
