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

Bio::EnsEMBL::Compara::RunnableDB::RecordSpeciesSet

=head1 DESCRIPTION

Records the query species run for each reference in database species_set
E.g. standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::RecordSpeciesSet \
    -compara_db $(mysql-ens-compara-prod-2 details url cristig_blastocyst_106) \
    -genome_name canis_lupus_familiaris \
    -species_set_record /hps/nobackup/flicek/ensembl/compara/shared/species_set_record/106/

=cut

package Bio::EnsEMBL::Compara::RunnableDB::RecordSpeciesSet;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    my @genome_db = @{$self->compara_dba->get_GenomeDBAdaptor->fetch_all_by_name($self->param('genome_name'))};
    my @species_sets = @{$self->compara_dba->get_SpeciesSetAdaptor->fetch_all_by_GenomeDB($genome_db[0])};
    my @genome_list;
    foreach my $ss ( @species_sets ) {
        my @genomes = map { $_->name } @{ $ss->genome_dbs() };
        push @genome_list, @genomes;
    }
    $self->param('ref_genomes', \@genome_list);
}

sub write_output {
    my $self = shift;
    my $base_dir = $self->param('species_set_record');
    my @ref_genomes = @{$self->param('ref_genomes')};
    my $query = $self->param('genome_name');
    foreach my $ref ( @ref_genomes ) {
        next if $ref eq $query;
        my $cmd = "echo '$query' >> $base_dir" . "/$ref.txt";
        $self->run_command($cmd);
    }
}

1;
