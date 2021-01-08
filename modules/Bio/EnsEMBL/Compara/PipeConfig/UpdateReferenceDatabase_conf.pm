=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::UpdateReferenceDatabase_conf

=head1 DESCRIPTION

    This is a PipeConfig for TODO

=cut

package Bio::EnsEMBL::Compara::PipeConfig::UpdateReferenceDatabase_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpFastaDatabases;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub no_compara_schema {};

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'     => 'references',
        'species_list' => $self->o('config_dir') . '/species_list.txt',
        'ref_db'       => 'compara_references',
        'taxonomy_db'  => 'ncbi_taxonomy',

        # how many parts should per-genome files be split into?
        'num_fasta_parts' => 100,

        'pipeline_name' => 'update_references_e' . $self->o('rel_with_suffix'),
        'backups_dir'   => $self->o('pipeline_dir') . '/reference_db_backups/',
        'ref_dumps_dir' => $self->o('shared_hps_dir') . '/reference_dumps/',

        # member loading options
        'include_reference'           => 1,
        'include_nonreference'        => 0,
        'include_patches'             => 1,
        'store_coding'                => 1,
        'store_ncrna'                 => 0,
        'store_others'                => 0,
        'store_exon_coordinates'      => 0,
        'store_related_pep_sequences' => 0, # do we want CDS sequence as well as protein seqs?

        # member HC options
        'allow_ambiguity_codes'         => 1,
        'only_canonical'                => 0,
        'allow_missing_cds_seqs'        => 1, # set to 0 if we store CDS (see above)
        'allow_missing_coordinates'     => 0,
        'allow_missing_exon_boundaries' => 1, # set to 0 if exon boundaries are loaded (see above)
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        $self->pipeline_create_commands_rm_mkdir(['pipeline_dir', 'backups_dir']),

        # In case it doesn't exist yet
        ($self->o('shared_user') ? 'become ' . $self->o('shared_user') : '') . ' mkdir -p ' . $self->o('ref_dumps_dir'),
        # The files are going to be accessed by many processes in parallel
        $self->pipeline_create_commands_lfs_setstripe('ref_dumps_dir', $self->o('shared_user')),
    ];
}


sub pipeline_wide_parameters {
# these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'ref_db'  => $self->o('ref_db'),
        'release' => $self->o('ensembl_release'),

        'backups_dir'   => $self->o('backups_dir'),
        'ref_dumps_dir' => $self->o('ref_dumps_dir'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'backup_ref_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -input_ids  => [{ }],
            -parameters => {
                'src_db_conn' => '#ref_db#',
                'output_file' => '#backups_dir#/compara_references.pre#release#.sql'
            },
            -flow_into => [ 'load_ncbi_node' ],
            -rc_name   => '1Gb_job'
        },

        {   -logic_name => 'load_ncbi_node',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'  => $self->o('taxonomy_db'),
                'dest_db_conn' => '#ref_db#',
                'mode'         => 'overwrite',
                'filter_cmd'   => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/g"',
                'table'        => 'ncbi_taxa_node',
            },
            -flow_into  => ['load_ncbi_name']
        },

        {   -logic_name => 'load_ncbi_name',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'  => $self->o('taxonomy_db'),
                'dest_db_conn' => '#ref_db#',
                'mode'         => 'overwrite',
                'filter_cmd'   => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/g"',
                'table'        => 'ncbi_taxa_name',
            },
            -flow_into  => ['hc_taxon_names'],
        },

        {   -logic_name => 'hc_taxon_names',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::SqlHealthChecks',
            -parameters => {
                'mode'    => 'taxonomy',
                'db_conn' => '#ref_db#',
            },
            -flow_into  => ['reference_factory'],
        },

        {   -logic_name => 'reference_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputfile'    => $self->o('species_list'),
                'column_names' => ['species_name'],
            },
            -flow_into => {
                '2->A' => [ 'update_reference_genome' ],
                'A->1' => [ 'backup_ref_db_again' ],
            },
        },

        {   -logic_name    => 'update_reference_genome',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ReferenceGenomes::UpdateReferenceGenome',
            -parameters    => {
                'compara_db' => '#ref_db#',
            },
            -hive_capacity => 10,
            -flow_into     => ['load_members'],
        },

        {   -logic_name => 'load_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {
                'compara_db'                  => '#ref_db#',
                'store_related_pep_sequences' => $self->o('store_related_pep_sequences'),
                'include_reference'           => $self->o('include_reference'),
                'include_nonreference'        => $self->o('include_nonreference'),
                'include_patches'             => $self->o('include_patches'),
                'store_coding'                => $self->o('store_coding'),
                'store_ncrna'                 => $self->o('store_ncrna'),
                'store_others'                => $self->o('store_others'),
                'store_exon_coordinates'      => $self->o('store_exon_coordinates'),
            },
            -hive_capacity => 10,
            -rc_name => '4Gb_job',
            -flow_into  => ['hc_members_per_genome'],
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                'db_conn'                   => '#ref_db#',
                'mode'                      => 'members_per_genome',
                'allow_ambiguity_codes'     => $self->o('allow_ambiguity_codes'),
                'only_canonical'            => $self->o('only_canonical'),
                'allow_missing_cds_seqs'    => $self->o('allow_missing_cds_seqs'),
                'allow_missing_coordinates' => $self->o('allow_missing_coordinates'),
            },
            -rc_name   => '4Gb_job',
            -flow_into => ['dump_full_fasta'],
        },

        {   -logic_name => 'backup_ref_db_again',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
            -parameters => {
                'src_db_conn' => '#ref_db#',
                'output_file' => '#backups_dir#/compara_references.post#release#.sql'
            },
            -flow_into  => [ 'copy_backups_to_warehouse' ],
            -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'copy_backups_to_warehouse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'shared_user'   => $self->o('shared_user'),
                'warehouse_dir' => $self->o('warehouse_dir'),
                'cmd'           => 'become #shared_user# cp #backups_dir#/*.sql #warehouse_dir#/reference_db_backups/',
            },
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpFastaDatabases::pipeline_analyses_dump_fasta_dbs($self) },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'dump_full_fasta'}->{'-parameters'}->{'compara_db'} = '#ref_db#';
}
1;
