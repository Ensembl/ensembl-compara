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

Bio::EnsEMBL::Compara::PipeConfig::EG::LoadMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EG::LoadMembers_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the LoadMembers pipeline for Ensembl Genomes.
Please, refer to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EG::LoadMembers_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # Genes with these logic_names will be ignored from the pipeline.
        # Format is { genome_db_id (or name) => [ 'logic_name1', 'logic_name2', ... ] }
        # An empty string can also be used as the key to define logic_names excluded from *all* species
        'exclude_gene_analysis'     => { },

    # "Member" parameters:
        # Store ncRNA genes
        'store_ncrna'               => 0,
        # Store other genes
        'store_others'              => 0,

    # connection parameters to various databases:
        'master_db_is_missing_dnafrags' => 1,

        # list of species that got an annotation update
        'expected_updates_file' => undef,

    # Ensembl-specific databases
        #'staging_loc' => {
            #-host   => 'mysql-ens-sta-1',
            #-port   => 4519,
            #-user   => 'ensro',
            #-pass   => '',
            #-db_version => 90,
        #},

        #'livemirror_loc' => {
            #-host   => 'mysql-ensembl-mirror.ebi.ac.uk',
            #-port   => 4240,
            #-user   => 'ensro',
            #-pass   => '',
            #-db_version => 89,
        #},

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        #'curr_core_sources_locs'    => [ $self->o('livemirror_loc') ],

        # Add the database entries for the core databases of the previous release
        #'prev_core_sources_locs'   => [ $self->o('staging_loc1'), $self->o('staging_loc2') ],
        #'prev_core_sources_locs'   => [ ],

    # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        #'reuse_member_db' => '',
        #'reuse_member_db' => 'mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_89',
    };
}


1;

