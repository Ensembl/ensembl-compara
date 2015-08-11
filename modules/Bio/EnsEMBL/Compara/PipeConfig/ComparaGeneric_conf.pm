=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

## Generic configuration module for all Compara pipelines

package Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'compara_innodb_schema' => 1,
    };
}


sub pipeline_create_commands {
    my $self            = shift @_;

    my $pipeline_url    = $self->pipeline_url();
    my $parsed_url      = Bio::EnsEMBL::Hive::Utils::URL::parse( $pipeline_url );
    my $driver          = $parsed_url ? $parsed_url->{'driver'} : '';

    # sqlite: no concept of MyISAM/InnoDB
    return $self->SUPER::pipeline_create_commands if( $driver eq 'sqlite' );

    return [
        @{$self->SUPER::pipeline_create_commands},    # inheriting database and hive table creation

            # Compara 'release' tables will be turned from MyISAM into InnoDB on the fly by default:
        ($self->o('compara_innodb_schema') ? "sed 's/ENGINE=MyISAM/ENGINE=InnoDB/g' " : 'cat ')
            . $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/table.sql | '.$self->db_cmd(),

            # Compara 'pipeline' tables are already InnoDB, but can be turned to MyISAM if needed:
        ($self->o('compara_innodb_schema') ? 'cat ' : "sed 's/ENGINE=InnoDB/ENGINE=MyISAM/g' ")
            . $self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/pipeline-tables.sql | '.$self->db_cmd(),

            # MySQL specific procedures
            $driver eq 'mysql' ? ($self->db_cmd().' < '.$self->o('ensembl_cvs_root_dir').'/ensembl-compara/sql/procedures.'.$driver) : (),
    ];
}

sub init_basic_tables_analyses {
    my ($self, $source_db, $target_analysis, $with_genome_db, $with_species_tree, $with_dnafrag, $input_ids) = @_;

    return [

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist' => [ 'method_link', 'species_set_header', 'species_set', 'method_link_species_set', 'ncbi_taxa_name', 'ncbi_taxa_node',
                                 $with_dnafrag ? ('dnafrag') : (),
                                 $with_genome_db ? ('genome_db') : (),
                                 $with_species_tree ? ('species_tree_node', 'species_tree_root') : (),
                ],
                'column_names' => [ 'table' ],
            },
            -input_ids => $input_ids,
            -flow_into => {
                ($target_analysis ? '2->A' : 2) => { 'copy_table' => { 'table' => '#table#' } },
                ($target_analysis ? ( 'A->1' => [ $target_analysis ] ) : ()),
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => $source_db,
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
            -analysis_capacity => 10,
        },

    ];
}


1;

