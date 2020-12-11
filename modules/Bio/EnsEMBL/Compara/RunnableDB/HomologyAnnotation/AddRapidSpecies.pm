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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::AddRapidSpecies

=head1 DESCRIPTION

Runnable to add species as a new genome_db directly into pipeline database from core.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::AddRapidSpecies;

use warnings;
use strict;
use List::Util qw(any);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'force'        => 1,
        'hard_limit'   => 50,
    };
}

sub fetch_input {
    my ($self) = @_;

    my $species_names    = $self->param('species_list');
    print Dumper $species_names;
    my $spec_hard_limit  = $self->param('hard_limit');
    my @species_list;

    foreach my $species_name ( @$species_names ) {
        if ( scalar(@species_list) < $spec_hard_limit ) {
            push @species_list, $species_name if scalar(@species_list) < $spec_hard_limit;
            print Dumper $species_name if $self->debug;
        }
        else {
            $self->warning( "The hard limit of" . $spec_hard_limit . "genomes in this pipeline has been exceeded: " . $species_name . " has been discarded." );
        }
    }

    $self->param( 'max_species_list', \@species_list );

    my $master_dba = $self->get_cached_compara_dba('master_db');
    $self->param( 'master_dba', $master_dba );
}

sub run {
    my $self = shift @_;

    my $species_list = $self->param('max_species_list');
    my $new_genome_dbs = [];

    foreach my $species_name ( @$species_list ) {
        print Dumper $species_name;
        push @$new_genome_dbs, _add_new_genomedb($self->param('master_dba'), $species_name, -RELEASE => $self->param('release'), -FORCE => $self->param('force') );
    }
}

sub write_output {
    my $self = shift @_;

    my $genome_dbs = $self->get_cached_compara_dba('master_db')->get_GenomeDBAdaptor->fetch_all();

    foreach my $genome_db ( sort { $a->dbID() <=> $b->dbID() } @$genome_dbs ) {
        $self->dataflow_output_id( { 'genome_db_id' => $genome_db->dbID(), 'species_name' => $genome_db->name() }, 2 );
    }
}

sub _add_new_genomedb {
    my $compara_dba = shift;
    my $species = shift;

    my ($release, $force, $taxon_id, $offset) = rearrange([qw(RELEASE FORCE TAXON_ID OFFSET)], @_);
    my $species_no_underscores = $species;
    $species_no_underscores =~ s/\_/\ /;

    my $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core") ? Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core") : Bio::EnsEMBL::Registry->get_DBAdaptor($species_no_underscores, "core");

    throw ("Cannot connect to database [${species_no_underscores} or ${species}]") if (!$species_db);

    my ( $new_genome_db );
    my $gdbs = $compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
        $new_genome_db = Bio::EnsEMBL::Compara::Utils::MasterDatabase::_update_genome_db($species_db, $compara_dba, $release, $force, $taxon_id, $offset);
        print "GenomeDB after update: ", $new_genome_db->toString, "\n\n";
    } );
    $species_db->dbc()->disconnect_if_idle();
    return $new_genome_db;
}

1;
