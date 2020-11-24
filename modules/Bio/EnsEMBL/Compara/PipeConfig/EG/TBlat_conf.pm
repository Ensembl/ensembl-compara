=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::EG::TBlat_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #4. Check all default_options below, especially
        ref_species (if not homo_sapiens)
        default_chunks
        pair_aligner_options

    #5. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EG::TBlat_conf -host mysql-ens-compara-prod-X -port XXXX \
            --mlss_id 574 -ref_species danio_rerio

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION

Version of the TBlat pipeline used on EG databases.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EG::TBlat_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf');


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

	'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',

	    'ref_species' => '',
	    #directory to dump dna files. Note that 2 subdirectories will be appended to this, ${genome_db_id1}_${genome_db_id2}/species_name to
	    #ensure uniqueness across pipelines
	    'dump_dir' => '/nfs/panda/ensemblgenomes/production/compara/' . $ENV{USER} . '/pair_aligner/dna_files/' . 'release_' . $self->o('rel_with_suffix') . '/',
            'bed_dir' => '/nfs/panda/ensemblgenomes/production/compara/' . $ENV{USER} . '/pair_aligner/bed_dir/' . 'release_' . $self->o('rel_with_suffix') . '/',
            'output_dir' => '/nfs/panda/ensemblgenomes/production/compara' . $ENV{USER} . '/pair_aligner/feature_dumps/' . 'release_' . $self->o('rel_with_suffix') . '/',

            # healthcheck
            'do_compare_to_previous_db' => 0,
            # Net
            'bidirectional' => 1,

	   };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'alignment_nets'                                => '2Gb_job',
        'create_alignment_nets_jobs'                    => '2Gb_job',
        'create_alignment_chains_jobs'                  => '4Gb_job',
        'create_filter_duplicates_jobs'                 => '2Gb_job',
        'create_pair_aligner_jobs'                      => '2Gb_job',
        'populate_new_database'                         => '8Gb_job',
        'parse_pair_aligner_conf'                       => '4Gb_job',
        $self->o('pair_aligner_logic_name')             => '4Gb_job',
        $self->o('pair_aligner_logic_name') . "_himem1" => '8Gb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
}

1;
