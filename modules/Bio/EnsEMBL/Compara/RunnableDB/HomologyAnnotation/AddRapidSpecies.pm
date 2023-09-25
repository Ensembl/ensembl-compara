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
        'release'      => 1,
        'skip_dna'     => 1,
    };
}

sub fetch_input {
    my ($self) = @_;

    my $species_names    = $self->param_required('species_list');
    print Dumper $species_names if $self->debug;
    my $spec_hard_limit  = $self->param('hard_limit');
    my @species_list;

    foreach my $species_name ( @$species_names ) {
        if ( scalar(@species_list) < $spec_hard_limit ) {
            push @species_list, $species_name if scalar(@species_list) < $spec_hard_limit;
            print Dumper $species_name if $self->debug;
        }
        else {
            # We have a hard limit to prevent overlapping ids between reference database and pipeline database
            $self->die_no_retry( "The hard limit of" . $spec_hard_limit . "genomes in this pipeline has been exceeded: " . $species_name . " has been discarded." );
        }
    }

    $self->param( 'max_species_list', \@species_list );
}

sub run {
    my $self = shift @_;

    my $species_list = $self->param('max_species_list');
    my $new_genome_dbs = [];

    foreach my $species_name ( @$species_list ) {
        push @$new_genome_dbs, Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_genome($self->compara_dba, $species_name, -RELEASE => $self->param('release'), -FORCE => $self->param('force'), -SKIP_DNA => $self->param('skip_dna') ); # skip dna loading to save table space
    }

    $self->param('genome_dbs', $new_genome_dbs);
}

sub write_output {
    my $self = shift @_;

    my $genome_dbs = $self->param('genome_dbs');

    foreach my $genome_db ( sort { $a->dbID() <=> $b->dbID() } @$genome_dbs ) {
        $self->dataflow_output_id( { 'genome_db_id' => $genome_db->dbID(), 'species_name' => $genome_db->name() }, 2 );
    }
}

1;
