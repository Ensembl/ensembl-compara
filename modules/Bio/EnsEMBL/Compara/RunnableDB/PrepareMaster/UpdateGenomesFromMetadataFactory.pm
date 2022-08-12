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

=head1 DESCRIPTION

Returns the list of species/genomes to update, rename and retire in the master
database, obtained from ensembl-metadata

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromMetadataFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw/ map_row_to_header /;

use JSON qw( decode_json );

use List::MoreUtils qw/ uniq /;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my $list_genomes_script = $self->param_required('list_genomes_script');
    my $meta_host = $self->param_required('meta_host');
	my $release = $self->param_required('release');
	my $division = $self->param('division');
	my $metadata_script_options = "\$($meta_host details script) --release $release" . ($division ? " --division $division" : "");
    my $rr_meta_db = $self->param('rr_meta_name');
    my ($rr, $rr_meta_dba);
    if ( $rr_meta_db ) {
        ($rr, $rr_meta_dba) = _get_curr_rr_release($rr_meta_db, $meta_host);
    }

    # If provided, get the list of allowed species
    my $allowed_species_file = $self->param('allowed_species_file');
    my $allowed_species;
    if (defined $allowed_species_file && -e $allowed_species_file) {
        die "The allowed species JSON file ('$allowed_species_file') should not be empty" if -z $allowed_species_file;
        $allowed_species = { map { $_ => 1 } @{ decode_json($self->_slurp($allowed_species_file)) } };
    }
	# use metadata script to report genomes that need to be updated
    my ($genomes_to_update, $renamed_genomes, $updated_annotations) = $self->fetch_genome_report($release, $division, $allowed_species, $rr, $rr_meta_dba);

    # Have we forgotten to update the allowed species JSON file?
    while (my ($new_name, $old_name) = each %$renamed_genomes) {
        $allowed_species->{$new_name} = 1 if exists $allowed_species->{$old_name};
    }

	# check there are no seq_region changes in the existing species
	my $list_cmd = "perl $list_genomes_script $metadata_script_options";
	my @release_genomes = $self->get_command_output($list_cmd);
    # and again for rr if rr is expected
    my $meta_rr_script_options = "\$($meta_host details script) --dbname $rr_meta_db --release $rr";
    my $rr_list_cmd;
    my @rr_genomes;

    if ( $self->param('rr_meta_name') ) {
        $rr_list_cmd = "perl $list_genomes_script $meta_rr_script_options";
        @rr_genomes  = $self->get_command_output($rr_list_cmd);
    }

    if ( scalar(@rr_genomes) > 0 and $rr_genomes[0] =~ /Division/ ) {
        # Remove Division: <division> and any empty elements
        @rr_genomes = grep { $_ ne '' and $_ !~ /^Division/ } @rr_genomes;

        push @release_genomes, @rr_genomes
    }

	chomp @release_genomes;
    if ($release_genomes[0] =~ /Division/) {
        # Remove the first element reported by the script: Division: <division> and any empty elements
        shift @release_genomes;
        @release_genomes = grep { $_ ne '' } @release_genomes;
    }
    if ($allowed_species) {
        # Keep only the species included in the allowed list
        @release_genomes = grep { exists $allowed_species->{$_} } @release_genomes;
        foreach my $species_name (keys %$renamed_genomes) {
            delete $renamed_genomes->{$species_name} if (!exists $allowed_species->{$species_name});
        }
    }

    # if a division is given and it is pan do not die because the list of species used in pan is
    # exclusively described in the parameter additional_species
    if ($division and ($division ne "pan")) {
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
            my ($updated_add_species, $renamed_add_species, $updated_gen_add_species) = $self->fetch_genome_report($release, $additional_div);
            foreach my $add_species_name ( @add_species_for_div ) {
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
            my $current_name = $renamed_genomes->{$species_name};
            if (! exists $current_gdbs{$current_name}) {
                # The genome to be renamed is not present in the database: treat it as to be added instead
                push @$genomes_to_update, $species_name;
                delete $renamed_genomes->{$species_name};
            }
            $current_gdbs{$current_name} = 1;
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
        push @genomes_to_verify, {
            'species_name'  => $species_name,
        };
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

    $self->dataflow_output_id( $self->param('genomes_to_verify'), 5);

    if ( $self->param('annotation_file') ) {
        $self->_spurt(
            $self->param('annotation_file'),
            join("\n", @{$self->param('genomes_to_update')}, @{$self->param('genomes_with_updated_annotation')}),
        );
    }
}

sub fetch_genome_report {
    my ( $self, $release, $division, $allowed_species, $rr, $rr_meta_dba ) = @_;

    my $meta_host = $self->param_required('meta_host');
    my $work_dir = $self->param_required('work_dir');
    my $report_genomes_script = $self->param_required('report_genomes_script');

    my (@new_genomes, @updated_assemblies, @updated_annotations, %renamed_genomes);

    if ( $rr ) {
        my ($new_genomes, $updated_assemblies, $updated_annotations, $renamed_genomes) = $self->_get_rr_reference_genomes($rr_meta_dba, $meta_host, $rr, $report_genomes_script, $work_dir);
        @new_genomes = @$new_genomes;
        @updated_assemblies = @$updated_assemblies;
        @updated_annotations = @$updated_annotations;
        %renamed_genomes = %$renamed_genomes;
    }

    my $metadata_script_options = "\$($meta_host details script) --release $release" . ($division ? " --division $division" : "");
    my $report_cmd = "perl $report_genomes_script $metadata_script_options -output_format json --dump_path $work_dir";
    my $report_out = $self->get_command_output($report_cmd);

    # add the division name output file
    my $report_file = "$work_dir/report_updates.json";
    my $report_file_with_div = $report_file;
    if ($division) {
        $report_file_with_div =~ s/report_updates/report_updates.$division.$release/;
    } else {
        $report_file_with_div =~ s/report_updates/report_updates.all.$release/;
    }
    $self->run_command("mv $report_file $report_file_with_div");

    # read and parse report
    my $decoded_meta_report = decode_json( $report_out );

    foreach my $this_division ( keys %$decoded_meta_report ) {
        next if ($division and ($this_division ne $division));
        my $division_report = $decoded_meta_report->{$this_division};
        push @new_genomes, keys %{$division_report->{new_genomes}};
        push @updated_assemblies, keys %{$division_report->{updated_assemblies}};
        $renamed_genomes{$_->{name}} = $_->{old_name} for values %{$division_report->{renamed_genomes}};
        push @updated_annotations, map {$_->{name}} values %{$division_report->{updated_annotations}};
    }

    # Remove duplicates between main and rr updates
    if ( $rr ) {
        @new_genomes = uniq(@new_genomes);
        @updated_assemblies = uniq(@updated_assemblies);
        @updated_annotations = uniq(@updated_annotations);
    }

    if ($allowed_species) {
        # Remove genomes reported from metadata not included in the allowed species list
        @new_genomes = grep { exists $allowed_species->{$_} } @new_genomes;
        @updated_assemblies = grep { exists $allowed_species->{$_} } @updated_assemblies;
        @updated_annotations = grep { exists $allowed_species->{$_} } @updated_annotations;
    }

    return ([@new_genomes, @updated_assemblies, @updated_annotations], \%renamed_genomes, \@updated_annotations);
}

# Internal method to find the current rapid release number and dba
sub _get_curr_rr_release {
    my ($name, $host) = @_;

    my $port = Bio::EnsEMBL::Compara::Utils::Registry::get_port( $host );
    my $dba  = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
        '-species' => 'multi',
        '-group'   => 'metadata',
        '-host'    => $host,
        '-port'    => $port,
        '-user'    => "ensro",
        '-pass'    => "",
        '-dbname'  => $name, );
    my $helper = $dba->dbc->sql_helper;

    my $sql = 'SELECT MAX(ensembl_genomes_version) FROM data_release WHERE is_current = 1';
    # should only return one result, as there is only one current at a time
    my $rr  = $helper->execute_single_result(-SQL => $sql);

    return ($rr, $dba);
}

sub _parse_name_to_array {
    my $file = shift;

    my $line_count = `cat $file | wc -l`;
    return if $line_count <= 1;

    my $species_names = _parse_rr_genome_files($file);
    return $species_names;
}

sub _get_rr_reference_genomes {
    my ( $self, $metadata_dba, $meta_host, $rr, $report_exe, $dump_path ) = @_;

    # this is the rapid release number
    my $metadata_name = $self->param('rr_meta_name');

    my $meta_options = "\$($meta_host details script) --dbname $metadata_name --release $rr --eg_first 1 --dump_path $dump_path";

    my $cmd = "perl $report_exe $meta_options";
    $self->run_command($cmd);

    # script produces a per-division tsv text file - not support for json yet
    my @new_genomes_files         = glob($dump_path . "/*-new_genomes.txt");
    my @updated_assemblies_files  = glob($dump_path . "/*-updated_assemblies.txt");
    my @updated_annotations_files = glob($dump_path . "/*-updated_annotations.txt");
    my @renamed_genomes_files     = glob($dump_path . "/*-renamed_genomes.txt");

    my ( @new_genomes, @updated_assemblies, @updated_annotations, %renamed_genomes );
    foreach my $file ( @new_genomes_files ) {
        push @new_genomes, _parse_name_to_array($file);
    }
    foreach my $file ( @updated_assemblies_files ) {
        push @updated_assemblies, _parse_name_to_array($file);
    }
    foreach my $file ( @updated_annotations_files ) {
        push @updated_annotations, _parse_name_to_array($file);
    }
    %renamed_genomes = %{_parse_rename_rr_files(\@renamed_genomes_files)};

    return \@new_genomes, \@updated_assemblies, \@updated_annotations, \%renamed_genomes;
}

# Internal method to parse the report file generated by report_genomes_exe for rr - as not json compatible
sub _parse_rr_genome_files {
    my $file = shift;

    open ( my $f, "<", $file ) or die "Cannot open report for new species $!";

    my $header = <$f>;

    $header =~ s/^\#//;

    my @species_names;

    while (<$f>) {
        # header line is commented in output
        next if $_ =~ /^\#name/;
        next if $_ !~ /[a-z]/;
        # the strain column can be blank; therefore, applying "\t" as field separator
        my $row = map_row_to_header( $_, $header, "\t" );
        # only interested in the genome name
        push @species_names, $row->{name};
    }

    close ($f);

    return \@species_names;
}

sub _parse_rename_rr_files {
    my $files = shift;

    my %renamed_genomes;
    foreach my $file ( @$files ) {
        open ( my $f, "<", $file ) or die "Cannot open report for new species $!";
        my $header = <$f>;
        $header =~ s/^\#//;

        while (<$f>) {
            # header line is commented in output
            next if $_ =~ /^\#name/;
            next if $_ !~ /[a-z]/;
            # the strain column can be blank; therefore, applying "\t" as field separator
            my $row = map_row_to_header( $_, $header, "\t" );
            # only interested in the genome name and old_name
            $renamed_genomes{$row->{name}} = $row->{old_name};
        }
        close ($f);
    }

    return \%renamed_genomes;
}

1;
