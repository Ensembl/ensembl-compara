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
use Bio::EnsEMBL::Compara::Utils::Registry;
use Bio::EnsEMBL::MetaData::Base qw(fetch_and_set_release process_division_names);
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use JSON qw( decode_json );

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my $list_genomes_script = $self->param_required('list_genomes_script');
    my $meta_host = $self->param_required('meta_host');
    my $meta_dbname = $self->param('meta_dbname') || 'ensembl_metadata';
	my $release = $self->param_required('release');
	my $division = $self->param_required('division');
	my $metadata_script_options = "\$($meta_host details script) --release $release --division $division";

    # If provided, get the list of allowed species
    my $allowed_species_file = $self->param('allowed_species_file');
    my $allowed_species;
    if (defined $allowed_species_file && -e $allowed_species_file) {
        die "The allowed species JSON file ('$allowed_species_file') should not be empty" if -z $allowed_species_file;
        $allowed_species = { map { $_ => 1 } @{ decode_json($self->_slurp($allowed_species_file)) } };
    }
	# use metadata script to report genomes that need to be updated
    my ($genomes_to_update, $renamed_genomes, $updated_annotations, $meta_report) = $self->fetch_genome_report($release, $division, $allowed_species);

	# check there are no seq_region changes in the existing species
	my $list_cmd = "perl $list_genomes_script $metadata_script_options";
	my @release_genomes = $self->get_command_output($list_cmd);
	chomp @release_genomes;
    if ($release_genomes[0] =~ /Division/) {
        # Remove the first element reported by the script: Division: <division> and any empty elements
        shift @release_genomes;
        @release_genomes = grep { $_ ne '' } @release_genomes;
    }
    if ($allowed_species) {
        # Keep only the species included in the allowed list
        @release_genomes = grep { exists $allowed_species->{$_} } @release_genomes;
    }

    # get default metadata for relevant genomes in current division
    my $default_meta = _fetch_genome_metadata($meta_host, $meta_dbname, $division, $release, \@release_genomes);

    #if pan do not die because the list of species used in pan is
    #exclusively described in param('additional_species')
    if ($division ne "pan"){
        die "No genomes reported for release" unless @release_genomes;
    }

    my $additional_species;
    if ($self->param_is_defined('additional_species') && $self->param_is_defined('additional_species_file')) {
        $self->throw("Only one of parameters 'additional_species' or 'additional_species_file' can be defined")
    } elsif ($self->param_is_defined('additional_species')) {
        $additional_species = $self->param('additional_species');
    } elsif ($self->param_is_defined('additional_species_file')) {
        my $additional_species_file = $self->param('additional_species_file');
        die "Additional species JSON file ('$additional_species_file') does not exist" unless -e $additional_species_file;
        die "Additional species JSON file ('$additional_species_file') should not be empty" if -z $additional_species_file;
        $additional_species = decode_json($self->_slurp($additional_species_file));
    }

    # check if additional species have been defined and include them
    # in the appropriate data structures
    if (defined $additional_species) {
        foreach my $additional_div ( keys %$additional_species ) {
            # first, add them to the release_genomes
            my @add_species_for_div = @{$additional_species->{$additional_div}};
            push( @release_genomes, @add_species_for_div );

            # get default metadata for relevant genomes in additional division
            my $additional_metadata = _fetch_genome_metadata($meta_host, $meta_dbname, $additional_div, $release, \@add_species_for_div);
            while (my ($genome_name, $genome_meta) = each %{$additional_metadata}) {
                $default_meta->{$genome_name} = $genome_meta;
            }

            # check for each additonal species in each division that the production name is correct
            $metadata_script_options = "\$($meta_host details script) --release $release --division $additional_div";
            $list_cmd = "perl $list_genomes_script $metadata_script_options";
            my @additional_release_genomes = $self->get_command_output($list_cmd);
            chomp @additional_release_genomes;
            if ($additional_release_genomes[0] =~ /Division/) {
                # Remove the first element reported by the script: Division: <division> and any empty elements
                shift @additional_release_genomes;
                @additional_release_genomes = grep { $_ ne '' } @additional_release_genomes;
            }
            my %additional_genome = map {$_ => 1} @additional_release_genomes;
            foreach my $genome (@add_species_for_div) {
                if (not exists($additional_genome{$genome})){
                    die "'$genome' from division $additional_div does not exist in the metadata database!\n";
                }
            }
            # check if they've been updated this release too
            my ($updated_add_species, $renamed_add_species, $updated_gen_add_species, $add_meta_report) = $self->fetch_genome_report($release, $additional_div);
            foreach my $add_species_name ( @add_species_for_div ) {
                $meta_report->{$add_species_name} = $add_meta_report->{$add_species_name};
                push( @$genomes_to_update, $add_species_name ) if grep { $add_species_name eq $_ } @$updated_add_species;
                push( @$updated_annotations, $add_species_name ) if grep { $add_species_name eq $_ } @$updated_gen_add_species;
                if (my $old_name = $renamed_add_species->{$add_species_name}) {
                    # We have the new name in the PipeConfig. Still need to update the database
                    $renamed_genomes->{$add_species_name} = $old_name;
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

    # check for species that have disappeared and need to be retired or those that have been introduced manually
    my $master_dba = $self->get_cached_compara_dba('master_db');
    my %current_gdbs = map { $_->name => 0 } @{$master_dba->get_GenomeDBAdaptor->fetch_all_current};
    $current_gdbs{'ancestral_sequences'} = 1; # never retire ancestral_sequences
    foreach my $species_name ( @release_genomes ) {
        if (exists $renamed_genomes->{$species_name}) {
            $current_gdbs{$renamed_genomes->{$species_name}} = 1;
        } else {
            # If the species has been added in this release, include it in the list of genomes to add
            push @$genomes_to_update, $species_name unless (exists $current_gdbs{$species_name});
            $current_gdbs{$species_name} = 1;
        }
    }
    my @to_retire = grep { $current_gdbs{$_} == 0 } keys %current_gdbs;

    # check that there have been no changes in dnafrags vs core slices
    my %g2update = map { $_ => 1 } @$genomes_to_update;
    my @genomes_to_verify;
    foreach my $species_name ( @release_genomes ) {
        next if $g2update{$species_name}; # we already know these have changed
        next if $renamed_genomes->{$species_name}; # renamed genomes are checked in their own analysis
        push @genomes_to_verify, $species_name;
    }

    if ($self->param_is_defined('force_retire_genomes') || $self->param_is_defined('force_update_genomes')) {

        my $force_retire_genomes = $self->param('force_retire_genomes') // [];
        my $force_update_genomes = $self->param('force_update_genomes') // [];

        my %forced_genome_set = map { $_ => 1 } (@$force_retire_genomes, @$force_update_genomes);
        _remove_genomes_from_output_lists(
            \%forced_genome_set,
            $genomes_to_update,
            $updated_annotations,
            \@to_retire,
            \@genomes_to_verify,
            $renamed_genomes,
        );

        push @$genomes_to_update, @$force_update_genomes;
        push @to_retire, @$force_retire_genomes;
    }

    print "GENOME_LIST!! ";
    print Dumper \@release_genomes;

    print "GENOMES_TO_UPDATE!! ";
    print Dumper $genomes_to_update;

    print "GENOMES_WITH_UPDATED_ANNOTATION!! ";
    print Dumper $updated_annotations;

    print "GENOMES_TO_RENAME!! ";
    print Dumper $renamed_genomes;

    print "GENOMES_TO_RETIRE!! ";
    print Dumper \@to_retire;

    print "GENOMES_TO_VERIFY!! ";
    print Dumper \@genomes_to_verify;

    if ($self->param_is_defined('compara_updates_file')) {
        my $compara_updates = {
            'genomes_to_update'     => {map { $_ => ($meta_report->{$_} // $default_meta->{$_}) } @{$genomes_to_update}},
            'annotations_to_update' => {map { $_ => $meta_report->{$_} } @{$updated_annotations}},
            'genomes_to_rename'     => {map { $_ => $meta_report->{$_} } keys %{$renamed_genomes}},
            'genomes_to_verify'     => \@genomes_to_verify,
            'genomes_to_retire'     => \@to_retire,
        };
        $self->_spurt($self->param('compara_updates_file'), JSON->new->pretty->encode($compara_updates));
    }

    my $perc_to_retire = (scalar @to_retire/scalar @release_genomes)*100;
    die "Percentage of genomes to retire seems too high ($perc_to_retire\%)" if $perc_to_retire >= $self->param_required('perc_threshold');

    $self->param('genomes_to_update', $genomes_to_update);
    $self->param('genomes_with_updated_annotation', $updated_annotations);
	$self->param('genomes_to_retire', \@to_retire);
    $self->param('renamed_genomes', $renamed_genomes);
    $self->param('genomes_to_verify', \@genomes_to_verify);
}

sub write_output {
	my $self = shift;

	my @new_genomes_dataflow = map { {species_name => $_, force => 0} } @{ $self->param('genomes_to_update') };
	$self->dataflow_output_id( \@new_genomes_dataflow, 2 );

	my @retire_genomes_dataflow = map { {species_name => $_} } @{ $self->param('genomes_to_retire') };
	$self->dataflow_output_id( \@retire_genomes_dataflow, 3 );

    my $renamed_genomes = $self->param('renamed_genomes');
    my @rename_genomes_dataflow = map { {new_name => $_, old_name => $renamed_genomes->{$_}} } keys %{ $renamed_genomes };
    $self->dataflow_output_id( \@rename_genomes_dataflow, 4 );

    my @verify_genomes_dataflow = map { {species_name => $_} } @{ $self->param('genomes_to_verify') };
    $self->dataflow_output_id( \@verify_genomes_dataflow, 5);

    $self->_spurt(
        $self->param_required('annotation_file'),
        join("\n", @{$self->param('genomes_to_update')}, @{$self->param('genomes_with_updated_annotation')}),
    );
}

sub fetch_genome_report {
    my ( $self, $release, $division, $allowed_species ) = @_;

    my $meta_host = $self->param_required('meta_host');
    my $work_dir = $self->param_required('work_dir');
    my $report_genomes_script = $self->param_required('report_genomes_script');
    my $metadata_script_options = "\$($meta_host details script) --release $release --division $division";
    my $report_cmd = "perl $report_genomes_script $metadata_script_options -output_format json --dump_path $work_dir";
    my $report_out = $self->get_command_output($report_cmd);

    # add the division name output file
    my $report_file = "$work_dir/report_updates.json";
    my $report_file_with_div = $report_file;
    $report_file_with_div =~ s/report_updates/report_updates.$division.$release/;
    $self->run_command("mv $report_file $report_file_with_div");

    # read and parse report
    my $decoded_meta_report = decode_json( $report_out );
    $decoded_meta_report = $decoded_meta_report->{$division};
    # print Dumper $decoded_meta_report;

    my @new_genomes = keys %{$decoded_meta_report->{new_genomes}};
    my @updated_assemblies = keys %{$decoded_meta_report->{updated_assemblies}};
    my %renamed_genomes = map { $_->{name} => $_->{old_name} } values %{$decoded_meta_report->{renamed_genomes}};
    my @updated_annotations = map {$_->{name}} values %{$decoded_meta_report->{updated_annotations}};

    if ($allowed_species) {
        # Remove genomes reported from metadata not included in the allowed species list
        @new_genomes = grep { exists $allowed_species->{$_} } @new_genomes;
        @updated_assemblies = grep { exists $allowed_species->{$_} } @updated_assemblies;
        @updated_annotations = grep { exists $allowed_species->{$_} } @updated_annotations;
        # Filter renamed genomes:
        my @allowed_keys = grep { exists $allowed_species->{$_} } keys %renamed_genomes;
        %renamed_genomes = map { $_ => $renamed_genomes{$_} } @allowed_keys;
    }

    my $flattened_meta_report;
    while (my ($update_type, $meta_recs) = each %{$decoded_meta_report}) {
        while (my ($genome_name, $meta_rec) = each %{$meta_recs}) {
            $flattened_meta_report->{$genome_name} = $meta_rec;
        }
    }

    return ([@new_genomes, @updated_assemblies], \%renamed_genomes, \@updated_annotations, $flattened_meta_report);
}

sub _fetch_genome_metadata {
    my ($metadata_host, $metadata_dbname, $division, $release, $relevant_genomes) = @_;

    my $meta_port =  Bio::EnsEMBL::Compara::Utils::Registry::get_port($metadata_host);
    my $metadata_dba = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
        -host    => $metadata_host,
        -port    => $meta_port,
        -user    => 'ensro',
        -dbname  => $metadata_dbname,
        -group   => 'metadata',
        -species => 'multi',
    );

    my $gdba = $metadata_dba->get_GenomeInfoAdaptor();
    my $rdba = $metadata_dba->get_DataReleaseInfoAdaptor();
    ($rdba, $gdba, $release) = fetch_and_set_release($release, $rdba, $gdba);
    my ($division_short_name, $division_name) = process_division_names($division);

    my %genome_details;
    my $division_genomes = $gdba->fetch_all_by_division($division_name);
    foreach my $genome (@{$division_genomes}) {
        my $genome_name = $genome->name();

        next unless grep { $genome_name eq $_ } @{$relevant_genomes};

        $genome_details{$genome_name} = {
            name        => $genome_name,
            assembly    => $genome->assembly_default(),
            genebuild   => $genome->genebuild(),
            database    => $genome->dbname(),
            strain      => $genome->organism()->strain(),
            taxonomy_id => $genome->organism()->taxonomy_id(),
        };
    }
    return \%genome_details;
}

sub _remove_genomes_from_output_lists {
    my ($genome_name_set, $genomes_to_update, $updated_annotations, $genomes_to_retire, $genomes_to_verify, $renamed_genomes) = @_;

    @{$genomes_to_update} = grep { !exists($genome_name_set->{$_}) } @{$genomes_to_update};
    @{$updated_annotations} = grep { !exists($genome_name_set->{$_}) } @{$updated_annotations};
    @{$genomes_to_retire} = grep { !exists($genome_name_set->{$_}) } @{$genomes_to_retire};
    @{$genomes_to_verify} = grep { !exists($genome_name_set->{$_}) } @{$genomes_to_verify};

    my @keys_to_delete = grep { exists($genome_name_set->{$_}) || exists($genome_name_set->{$renamed_genomes->{$_}}) } keys %{$renamed_genomes};
    foreach my $key_to_delete (@keys_to_delete) {
        delete $renamed_genomes->{$key_to_delete};
    }
}

1;
