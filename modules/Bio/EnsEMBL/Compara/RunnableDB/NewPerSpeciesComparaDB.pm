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

Bio::EnsEMBL::Compara::RunnableDB::NewPerSpeciesComparaDB

=head1 DESCRIPTION

Creates new MySQL compara database for a single genome_name
E.g. standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::NewPerSpeciesComparaDB \
    -homology_host mysql-ens-compara-prod-2 \
    -genome_name canis_lupus_familiaris \
    -curr_release 103 \
    -schema_file $ENSEMBL_ROOT_DIR/ensembl-compara/sql/table.sql \
    -db_cmd_path ${EHIVE_ROOT_DIR}/scripts/db_cmd.pl

=cut

package Bio::EnsEMBL::Compara::RunnableDB::NewPerSpeciesComparaDB;

use warnings;
use strict;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Database qw/ table_exists db_exists /;
use Bio::EnsEMBL::Utils::Exception qw( warning );

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;

    return {
        %{$self->SUPER::param_defaults()},
        'homology_host'  => 'mysql-ens-compara-prod-2',
    };
}

sub write_output {
    my $self = shift;

    my $release     = $self->param_required( 'curr_release' );
    my $genome_name = $self->param_required( 'genome_name' );
    my $host        = $self->param_required( 'homology_host' );
    # Keep input to fewer parameters
    my $port     = Bio::EnsEMBL::Compara::Utils::Registry::get_port( $host );
    my $rw_user  = Bio::EnsEMBL::Compara::Utils::Registry::get_rw_user( $host );
    my $password = Bio::EnsEMBL::Compara::Utils::Registry::get_rw_pass( $host );

    my $server_uri  = "mysql://" . $rw_user . ":" . $password . "@" . $host . ":" . $port;
    my $new_db_name = $genome_name . "_compara_" . $release;
    my $new_db      = $server_uri . "/" . $new_db_name;
    # To optionally dataflow to the next runnable if needed: e.g. to copy
    $self->param('per_species_db', $new_db);

    my $schema_file = $self->param_required( 'schema_file' );
    my $db_cmd_path = $self->param_required( 'db_cmd_path' );
    # Preferred behaviour is to die if the database already exists
    die $new_db . " already exists" if db_exists( $host, $new_db_name );

    my @cmd;
    my $sql = "CREATE DATABASE IF NOT EXISTS $new_db_name";
    my $cmd = "$db_cmd_path -url $server_uri -sql '$sql'";
    $self->run_command( $cmd, { die_on_failure => 1 } );

    my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $new_db );
    $cmd = "$db_cmd_path -url $new_db < $schema_file";
    $self->run_command( $cmd, { die_on_failure => 1 } );

    $self->dataflow_output_id( { 'per_species_db' => $new_db }, 2 );
}

1;
