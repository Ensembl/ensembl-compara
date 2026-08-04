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

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromRegFactory

=head1 DESCRIPTION

Returns the list of species/genomes to add to the master database from the core
databases in the registry file

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromRegFactory \
        -compara_db $(mysql-ens-compara-prod-9-ensadmin details url jalvarez_prep_vertebrates_master_for_rel_103) \
        -master_db $(mysql-ens-compara-prod-1 details url ensembl_compara_master)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromRegFactory;

use warnings;
use strict;

use Data::Dumper;
use JSON qw(decode_json);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;
    # Get the core database adaptors for all the current species specified in the registry
    my $species_list = Bio::EnsEMBL::Registry->get_all_species();
    my %core_dbas;
    foreach my $species_name ( @$species_list ) {
        my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species_name, 'core');
        $core_dbas{$species_name} = $dba;
    }

    # If provided, get the list of allowed species
    my $allowed_species_file = $self->param('allowed_species_file');
    my $allowed_species_set = {};
    if (defined $allowed_species_file && -e $allowed_species_file) {
        die "The allowed species JSON file ('$allowed_species_file') should not be empty" if -z $allowed_species_file;
        $allowed_species_set = { map { $_ => 1 } @{ decode_json($self->_slurp($allowed_species_file)) } };
    }

    # If available, get the set of additional species
    my $additional_species_set = {};
    if ($self->param_is_defined('additional_species_file')) {
        my $additional_species_file = $self->param('additional_species_file');
        die "Additional species JSON file ('$additional_species_file') does not exist" unless -e $additional_species_file;
        die "Additional species JSON file ('$additional_species_file') should not be empty" if -z $additional_species_file;
        my $additional_species;
        my $additional_species = decode_json($self->_slurp($additional_species_file));
        foreach my $additional_div ( keys %$additional_species ) {
            foreach my $species_name (@{$additional_species->{$additional_div}}) {
                $additional_species_set->{$species_name} = 1;
            }
        }
    }

    # Filter core database set, keeping only those that are in the allowed-species/additional-species lists.
    if ($allowed_species_set || $additional_species_set) {
        my @excluded_species = grep { ! (exists $allowed_species_set->{$_} || exists $additional_species_set->{$_}) } keys %core_dbas;
        delete @core_dbas{@excluded_species};
    }

    my $master_dba = $self->get_cached_compara_dba('master_db');
    my $current_genomes = [grep { $_->name ne 'ancestral_sequences' && !defined $_->genome_component } @{$master_dba->get_GenomeDBAdaptor->fetch_all_current()}];
    my (@genomes_to_update, @genomes_to_retire, @genomes_to_verify);
    if ( @$current_genomes ) {
        foreach my $genome ( @$current_genomes ) {
            if ( $core_dbas{$genome->name} ) {
                if ( $genome->assembly eq $core_dbas{$genome->name}->assembly_name ) {
                    push @genomes_to_verify, $genome->name;
                } else {
                    push @genomes_to_update, $genome->name;
                }
            } else {
                # Retire the genomes not included in the registry or the list of allowed species
                push @genomes_to_retire, $genome->name;
            }
        }
    }

    # Add allowed/additional species not yet stored as a GenomeDB.
    my %current_gdb_name_set = map { $_->name => 1 } @$current_genomes;
    my @new_gdb_names = grep { !exists $current_gdb_name_set{$_} } keys %core_dbas;
    push @genomes_to_update, @new_gdb_names;

    print "GENOME_LIST!! ";
    print Dumper [sort keys %core_dbas];

    print "GENOMES_TO_UPDATE!! ";
    print Dumper \@genomes_to_update;

    print "GENOMES_TO_RETIRE!! ";
    print Dumper \@genomes_to_retire;

    print "GENOMES_TO_VERIFY!! ";
    print Dumper \@genomes_to_verify;

    $self->param('genomes_to_update', \@genomes_to_update);
    $self->param('genomes_to_retire', \@genomes_to_retire);
    $self->param('genomes_to_verify', \@genomes_to_verify);
}


sub write_output {
    my $self = shift;
    my @genomes_to_update = map { {species_name => $_, force => 0} } @{ $self->param('genomes_to_update') };
    $self->dataflow_output_id(\@genomes_to_update, 2);
    my @genomes_to_retire = map { {species_name => $_} } @{ $self->param('genomes_to_retire') };
    $self->dataflow_output_id(\@genomes_to_retire, 3);
    my @genomes_to_verify = map { {species_name => $_} } @{ $self->param('genomes_to_verify') };
    $self->dataflow_output_id(\@genomes_to_verify, 5);
}


1;
