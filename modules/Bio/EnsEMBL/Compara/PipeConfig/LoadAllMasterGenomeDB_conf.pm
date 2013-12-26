=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::LoadAllMasterGenomeDB_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::LoadAllMasterGenomeDB_conf -password <your_password>

=head1 DESCRIPTION  

    This is a test of JobFactory + LoadOneGenomeDB Runnables

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::LoadAllMasterGenomeDB_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => 'load_all_master_genomedb',

        'pipeline_db' => {                                  # connection parameters
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                        # a rule where a previously undefined parameter is used (which makes either of them obligatory)
            -dbname => $ENV{USER}.'_'.$self->o('pipeline_name'),    # a rule where a previously defined parameter is used (which makes both of them optional)
        },

        'reg1' => {
            -host   => 'ens-staging',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'reg2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        master_db => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_master',
        }
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'           => $self->o('master_db'),
                'inputquery'        => 'SELECT genome_db_id, name species_name, assembly assembly_name FROM genome_db WHERE taxon_id AND assembly_default',
                'fan_branch_code'   => 2,
            },
            -input_ids  => [
                { },    # the input_id template is now fully defined by the query's column_names (hence the need to rename them).
                        # If you want to load the latest assembly for the genome, skip 'assembly assembly_name' field from the query.
            ],
            -flow_into => {
                2 => [ 'load_genomedb' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'  => [ $self->o('reg1'), $self->o('reg2'), ],
            },
            -flow_into => {
                1 => [ 'dummy' ],   # each will flow into another one
            },
        },

        {   -logic_name    => 'dummy',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -hive_capacity => 10,       # allow several workers to perform identical tasks in parallel
        },
    ];
}

1;

