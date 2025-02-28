
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
    my $get_current_assemblies_sql = 'SELECT name FROM genome_db WHERE first_release IS NOT NULL AND last_release IS NULL AND name != "ancestral_sequences"';
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

    my $master_dba = $self->param('master_dba');
    my $collection_name = $self->param_required('collection_name');
    my $current_species = $self->param('current_species');
    my $incl_components = $self->param_required('incl_components');

    my @rel_collection_gdbs = map {$master_dba->get_GenomeDBAdaptor->_find_most_recent_by_name($_)} @$current_species;
    if ($incl_components) {
        @rel_collection_gdbs = Bio::EnsEMBL::Compara::Utils::MasterDatabase::_expand_components(\@rel_collection_gdbs);
    }

    my $species_set_dba = $master_dba->get_SpeciesSetAdaptor;
    my $species_set = $species_set_dba->fetch_by_GenomeDBs(\@rel_collection_gdbs);
    if (defined $species_set && $species_set->name ne "collection-$collection_name") {
        $species_set->name("collection-$collection_name");
        $species_set_dba->update_header($species_set);
        $self->complete_early("Release collection already exists under a different name. Updated collection name");
    }

    #Update the release collection.
    Bio::EnsEMBL::Compara::Utils::MasterDatabase::new_collection( $master_dba, $collection_name, $current_species, -DRY_RUN => $dry_run, -RELEASE => $self->param_required('release'), -INCL_COMPONENTS => $incl_components );
}

1;
