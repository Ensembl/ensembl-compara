
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

Bio::EnsEMBL::Compara::RunnableDB::CreateReleaseCollection

=head1 DESCRIPTION

Used to create a new collection given a list of genome_db_ids.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CreateReleaseCollection;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::MasterDatabase;
use Bio::EnsEMBL::Hive::Utils ('go_figure_dbc');

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $master_dba = $self->get_cached_compara_dba('master_db');
    $self->param( 'master_dba', $master_dba);

    my @current_species;

    #Fetching all current assemblies:
    my $get_current_assemblies_sql = "SELECT name FROM genome_db WHERE first_release IS NOT NULL AND last_release IS NULL";
    my $sth = $master_dba->dbc->prepare( $get_current_assemblies_sql, { 'mysql_use_result' => 1 } );
    $sth->execute();
    while ( my $name = $sth->fetchrow() ) {
        push( @current_species, $name);
    }

    $self->param( 'current_species', \@current_species);
}

sub write_output {
    my $self = shift;

    my $dry_run = 0;

    #Update the release collection.
    Bio::EnsEMBL::Compara::Utils::MasterDatabase::new_collection( $self->param('master_dba'), $self->param('collection_name'), $self->param( 'current_species' ), -DRY_RUN => $dry_run, -RELEASE => $self->param('release'), -INCL_COMPONENTS => $self->param('incl_components') );
}

1;

