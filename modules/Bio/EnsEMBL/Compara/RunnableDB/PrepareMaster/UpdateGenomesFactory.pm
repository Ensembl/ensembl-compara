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

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFactory

=head1 SYNOPSIS



=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;
use JSON qw( decode_json );

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'param'   => undef,
    }
}

sub fetch_input {
	my $self = shift;

	my $list_genomes_script = $self->param_required('list_genomes_script');
	my $release = $self->param_required('release');
	my $division = $self->param_required('division');
	my $metadata_script_options = "\$(mysql-ens-meta-prod-1 details script) --release $release --division $division";
	my $genome_db_adaptor = $self->get_cached_compara_dba('master_db')->get_GenomeDBAdaptor;

	# use metadata script to report genomes that need to be updated
	my ($genomes_to_update, $renamed_genomes) = $self->fetch_genome_report($release, $division);

	# check there are no seq_region changes in the existing species
	my $list_cmd = "perl $list_genomes_script $metadata_script_options";
	my $list_run = $self->run_command($list_cmd);
	my @release_genomes = split( /\s+/, $list_run->out );
	chomp @release_genomes;
    die "No genomes reported for release" unless @release_genomes;

    # check if additional species have been defined and include them
    # in the appropriate data structures
    if ( $self->param('additional_species') ) {
        my $additional_species = $self->param('additional_species');
        foreach my $additional_div ( keys %$additional_species ) {
            # first, add them to the release_genomes
            my @add_species_for_div = @{$additional_species->{$additional_div}};
            push( @release_genomes, @add_species_for_div );

            # check if they've been updated this release too
            my ($updated_add_species, $renamed_add_species) = $self->fetch_genome_report($release, $additional_div);
            foreach my $add_species_name ( @add_species_for_div ) {
                push( @$genomes_to_update, $add_species_name ) if grep { $add_species_name eq $_ } @$updated_add_species;
            }
        }
    }

    print "GENOMES_TO_UPDATE!! ";
    print Dumper $genomes_to_update;

    print "GENOME_LIST!! ";
    print Dumper @release_genomes;

    # check that there have been no changes in dnafrags vs core slices
    my %g2update = map { $_ => 1 } @$genomes_to_update;
    my $master_dba = $self->get_cached_compara_dba('master_db');
	foreach my $species_name ( @release_genomes ) {
		next if $g2update{$species_name}; # we already know these have changed
        $species_name = $renamed_genomes->{$species_name} if $renamed_genomes->{$species_name}; # if it's been renamed only, still check if frags are stable
        print "fetching and checking $species_name\n";
		my $gdb = $genome_db_adaptor->fetch_by_name_assembly($species_name);
        my $slices_to_ignore = 'LRG' if $species_name eq 'homo_sapiens';
		my $dnafrags_match = Bio::EnsEMBL::Compara::Utils::MasterDatabase->dnafrags_match_core_slices($master_dba, $gdb, $slices_to_ignore);
		die "DnaFrags do not match core for $species_name" unless $dnafrags_match;
	}

	# check for species that have disappeared and need to be retired
	my %current_gdbs = map { $_->name => 0 } @{$genome_db_adaptor->fetch_all_current};
    $current_gdbs{'ancestral_sequences'} = 1; # never retire ancestral_sequences
	foreach my $species_name ( @release_genomes ) {
		$current_gdbs{$species_name} = 1;
	}
	my @to_retire = grep { $current_gdbs{$_} == 0 } keys %current_gdbs;

    my $perc_to_retire = (scalar @to_retire/scalar @release_genomes)*100;
    die "Percentage of genomes to retire seems too high ($perc_to_retire\%)" if $perc_to_retire >= 20;

    $self->param('genomes_to_update', $genomes_to_update);
	$self->param('genomes_to_retire', \@to_retire);
}

sub write_output {
	my $self = shift;

	my @new_genomes_dataflow = map { {species_name => $_, force => 0} } @{ $self->param('genomes_to_update') };
	$self->dataflow_output_id( \@new_genomes_dataflow, 2 );

	my @retire_genomes_dataflow = map { {species_name => $_} } @{ $self->param('genomes_to_retire') };
	$self->dataflow_output_id( \@retire_genomes_dataflow, 3 );
}

sub fetch_genome_report {
    my ( $self, $release, $division ) = @_;

    my $report_genomes_script = $self->param_required('report_genomes_script');
    my $metadata_script_options = "\$(mysql-ens-meta-prod-1 details script) --release $release --division $division";
    my $report_cmd = "perl $report_genomes_script $metadata_script_options -output_format json";
	my $report_run = $self->run_command($report_cmd);

    my $decoded_meta_report = decode_json( $report_run->out );
    $decoded_meta_report = $decoded_meta_report->{$division};
    # print Dumper $decoded_meta_report;

    my @new_genomes = keys %{$decoded_meta_report->{new_genomes}};
    my @updated_assemblies = keys %{$decoded_meta_report->{updated_assemblies}};
    my %renamed_genomes = map { $_->{name} => $_->{old_name} } values %{$decoded_meta_report->{renamed_genomes}};

	return ([@new_genomes, @updated_assemblies], \%renamed_genomes);
}

1;
