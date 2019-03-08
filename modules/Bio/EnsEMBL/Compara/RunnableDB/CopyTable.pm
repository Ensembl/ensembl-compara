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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CopyTable

=head1 SYNOPSIS

	

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CopyTable;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },

        'mode' => 'ignore',
        'skip_disable_keys' => 0,
    };
}

sub run {
	my $self = shift;

	my $from_dbc   = $self->get_cached_compara_dba('src_db_conn')->dbc;
	my $to_dbc     = $self->get_cached_compara_dba('dest_db_conn')->dbc;
	my $table_name = $self->param('table');
	my $query      = $self->param('query') ? $self->param('query') : "SELECT * FROM $table_name";
	my $replace    = $self->param('mode') eq 'ignore' ? 0 : 1;

	my $from_str = $from_dbc->host . '/' . $from_dbc->dbname;
	my $to_str   = $to_dbc->host . '/' . $to_dbc->dbname;
	$self->warning("Copying $table_name from $from_str to $to_str using query '$query'");

	copy_data( $from_dbc, $to_dbc, $table_name, $query, $replace, $self->param('skip_disable_keys'), $self->debug );
}

1;
