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

=cut

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromMetadataFactory

=head1 SYNOPSIS

Returns the list of species/genomes to update, rename and retire in the master
database, obtained from ensembl-metadata

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromMetadataFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;
use JSON qw( decode_json );

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my $list_genomes_script = $self->param_required('list_genomes_script');
    my $meta_host = $self->param_required('meta_host');
	my $release = $self->param_required('release');
	my $division = $self->param_required('division');
	my $metadata_script_options = "\$($meta_host details script) --release $release --division $division";
	my $genome_db_adaptor = $self->get_cached_compara_dba('master_db')->get_GenomeDBAdaptor;

	# use metadata script to report genomes that need to be updated
    my ($genomes_to_update, $renamed_genomes, $genomes_with_assembly_patches, $updated_annotations) = $self->fetch_genome_report($release, $division);

    # prepare renaming SQL cmds
    my @rename_cmds;
    foreach my $new_name ( keys %$renamed_genomes ) {
        my $old_name = $renamed_genomes->{$new_name};
        push(@rename_cmds, "UPDATE genome_db SET name = '$new_name' WHERE name = '$old_name' AND first_release IS NOT NULL AND last_release IS NULL");
    }
    $self->param('rename_cmds', \@rename_cmds);

	# check there are no seq_region changes in the existing species
	my $list_cmd = "perl $list_genomes_script $metadata_script_options";
	my @release_genomes = $self->get_command_output($list_cmd);
	chomp @release_genomes;

    #if pan do not die becasue the list of species used in pan is
    #exclusively described in param('additional_species')
    if ($division ne "pan"){
        die "No genomes reported for release" unless @release_genomes;
    }

    # check if additional species have been defined and include them
    # in the appropriate data structures
    if ( $self->param('additional_species') ) {
        my $additional_species = $self->param('additional_species');
        foreach my $additional_div ( keys %$additional_species ) {
            # first, add them to the release_genomes
            my @add_species_for_div = @{$additional_species->{$additional_div}};
            push( @release_genomes, @add_species_for_div );
            # check for each additonal species in each division that the productioin name is correct
            $metadata_script_options = "\$($meta_host details script) --release $release --division $additional_div";
            $list_cmd = "perl $list_genomes_script $metadata_script_options";
            my @additional_release_genomes = $self->get_command_output($list_cmd);
            chomp @additional_release_genomes;
            my %additional_genome = map {$_ => 1} @additional_release_genomes;
            foreach my $genome (@add_species_for_div) {
                if (not exists($additional_genome{$genome})){
                    die "'$genome' from division $additional_div does not exist in the metadata database!\n";
                }
            }
            # check if they've been updated this release too
            my ($updated_add_species, $renamed_add_species, $patched_add_species, $updated_gen_add_species) = $self->fetch_genome_report($release, $additional_div);
            foreach my $add_species_name ( @add_species_for_div ) {
                push( @$genomes_to_update, $add_species_name ) if grep { $add_species_name eq $_ } @$updated_add_species;
                push( @$genomes_with_assembly_patches, $add_species_name ) if grep { $add_species_name eq $_ } @$patched_add_species;
                push( @$updated_annotations, $add_species_name ) if grep { $add_species_name eq $_ } @$updated_gen_add_species;
                if (my $old_name = $renamed_add_species->{$add_species_name}) {
                    # We have the new name in the PipeConfig. Still need to update the database
                    push @rename_cmds, "UPDATE genome_db SET name = '$add_species_name' WHERE name = '$old_name' AND first_release IS NOT NULL AND last_release IS NULL";
                } else {
                    # We have the old name in the PipeConfig. Update it there first and rerun the pipeline
                    my @new_name = grep {$renamed_add_species->{$_} eq $add_species_name} (keys %$renamed_add_species);
                    if (@new_name) {
                        die "'$add_species_name' has been renamed to ".$new_name[0].". Please update your PipeConfig(s) and rerun the pipeline !\n";
                    }
                }
            }
        }
    }

    print "GENOMES_TO_UPDATE!! ";
    print Dumper $genomes_to_update;

    print "GENOME_LIST!! ";
    print Dumper \@release_genomes;

    print "GENOMES_WITH_ASSEMBLY_PATCHES!! ";
    print Dumper $genomes_with_assembly_patches;

    print "GENOMES_WITH_UPDATED_ANNOTATION!! ";
    print Dumper $updated_annotations;

    print "GENOMES_TO_RENAME!! ";
    print Dumper $renamed_genomes;

    # check that there have been no changes in dnafrags vs core slices
    my %g2update = map { $_ => 1 } @$genomes_to_update;
    my $master_dba = $self->get_cached_compara_dba('master_db');
	foreach my $species_name ( @release_genomes ) {
		next if $g2update{$species_name}; # we already know these have changed
        my $core_dba;
        if ( $renamed_genomes->{$species_name} ) { # if it's been renamed only, still check if frags are stable
            $core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species_name, 'core');
            $species_name = $renamed_genomes->{$species_name};
        }
        print "fetching and checking $species_name\n";
		my $gdb = $genome_db_adaptor->fetch_by_name_assembly($species_name);
        $gdb->db_adaptor($core_dba) if defined $core_dba;
        my $slices_to_ignore;
        $slices_to_ignore = 'LRG' if $species_name eq 'homo_sapiens';
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
    $self->param('genomes_with_assembly_patches', $genomes_with_assembly_patches);
    $self->param('genomes_with_updated_annotation', $updated_annotations);
	$self->param('genomes_to_retire', \@to_retire);
}

sub write_output {
	my $self = shift;

	my @new_genomes_dataflow = map { {species_name => $_, force => 0} } @{ $self->param('genomes_to_update') };
	$self->dataflow_output_id( \@new_genomes_dataflow, 2 );

	my @retire_genomes_dataflow = map { {species_name => $_} } @{ $self->param('genomes_to_retire') };
	$self->dataflow_output_id( \@retire_genomes_dataflow, 3 );

    my @rename_genomes_dataflow = map { {sql => [$_]} } @{ $self->param('rename_cmds') };
    $self->dataflow_output_id( \@rename_genomes_dataflow, 4 );

    my @patched_genomes_dataflow = map { {species_name => $_} } @{ $self->param('genomes_with_assembly_patches') };
    $self->dataflow_output_id( \@patched_genomes_dataflow, 5 );

    $self->_spurt(
        $self->param_required('annotation_file'),
        join("\n", @{$self->param('genomes_with_updated_annotation')}),
    );
}

sub fetch_genome_report {
    my ( $self, $release, $division ) = @_;

    my $meta_host = $self->param_required('meta_host');
    my $work_dir = $self->param_required('work_dir');
    my $report_genomes_script = $self->param_required('report_genomes_script');
    my $metadata_script_options = "\$($meta_host details script) --release $release --division $division";
    my $report_cmd = "perl $report_genomes_script $metadata_script_options -output_format json --dump_path $work_dir";
    my $report_out = $self->get_command_output($report_cmd);

    # add the division name output file
    my $report_file = "$work_dir/report_updates.json";
    my $report_file_with_div = $report_file;
    $report_file_with_div =~ s/report_updates/report_updates.$division/;
    $self->run_command("mv $report_file $report_file_with_div");

    # read and parse report
    my $decoded_meta_report = decode_json( $report_out );
    $decoded_meta_report = $decoded_meta_report->{$division};
    # print Dumper $decoded_meta_report;

    my @new_genomes = keys %{$decoded_meta_report->{new_genomes}};
    my %renamed_genomes = map { $_->{name} => $_->{old_name} } values %{$decoded_meta_report->{renamed_genomes}};
    my @updated_annotations = map {$_->{name}} values %{$decoded_meta_report->{updated_annotations}};

    my @genomes_with_assembly_patches;
    my @updated_assemblies;
    foreach my $genome (keys %{$decoded_meta_report->{updated_assemblies}}) {
        my $genome_report = $decoded_meta_report->{updated_assemblies}->{$genome};
        if ($genome_report->{old_assembly} eq $genome_report->{assembly}) {
            if ($genome_report->{old_assembly} =~ /^GRC[a-z][0-9]+/) {
                # GRC patch assembly update
                push @genomes_with_assembly_patches, $genome;
                next;
            } else {
                # Update of an assembly with the same name, this can be
                # quite dangerous but we don't do anything here as it will
                # be assessed when update_genome fails.
            }
        }
        push @updated_assemblies, $genome;
    }

    return ([@new_genomes, @updated_assemblies], \%renamed_genomes, \@genomes_with_assembly_patches, \@updated_annotations);
}

1;
