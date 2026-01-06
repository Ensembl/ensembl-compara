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

Bio::EnsEMBL::Compara::RunnableDB::HAL::MafToBigChain

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::MafToBigChain;

use strict;
use warnings;

use File::Copy qw(move);
use File::Basename qw(fileparse);
use File::Path qw(make_path);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub pre_cleanup {
    my $self = shift;

    my $output_bigchain1_file = $self->param_required('output_bigchain1_file');
    my $output_biglink1_file = $output_bigchain1_file =~ s/\.bb$/.link.bb/r;

    my $output_bigchain2_file = $self->param_required('output_bigchain2_file');
    my $output_biglink2_file = $output_bigchain2_file =~ s/\.bb$/.link.bb/r;

    my @cmds = (
        "rm -f $output_bigchain1_file",
        "rm -f $output_biglink1_file",
        "rm -f $output_bigchain2_file",
        "rm -f $output_biglink2_file",
    );

    foreach my $cmd (@cmds) {
        $self->run_command($cmd, { die_on_failure => 1 });
    }
}


sub fetch_input {
    my $self = shift;

    my $output_bigchain1_file = $self->param_required('output_bigchain1_file');
    $self->param('output_biglink1_file', $output_bigchain1_file =~ s/\.bb$/.link.bb/r);

    my $output_bigchain2_file = $self->param_required('output_bigchain2_file');
    $self->param('output_biglink2_file', $output_bigchain2_file =~ s/\.bb$/.link.bb/r);

    if (!$self->param_is_defined('hal_file')) {
        my $mlss_id = $self->param_required('mlss_id');
        my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
        $self->param('hal_file', $mlss->url);
    }

    if (!$self->param_is_defined('target_genomes')) {
        my $mlss_id = $self->param_required('mlss_id');
        my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
        my $species_map = destringify($mlss->get_value_for_tag('hal_mapping', '{}'));
        $self->param('target_genomes', join(',', values %{$species_map}));
    }
    my %maf_genome_name_set = map { $_ => 1 } split(/,/, $self->param('target_genomes'));

    if ($self->param_is_defined('ref_hal_genome')) {
        $maf_genome_name_set{$self->param('ref_hal_genome')} = 1;
    }

    $self->param('maf_genomes', [sort keys %maf_genome_name_set]);
}


sub run {
    my $self = shift;

    my $big_bed_exe = $self->require_executable('big_bed_exe');
    my $chainSwap_exe = $self->require_executable('chainSwap_exe');
    my $chain_to_big_chain_exe = $self->require_executable('chainToBigChain_exe');
    my $hal_stats_exe = $self->require_executable('halStats_exe');
    my $maf_convert_exe = $self->require_executable('maf_convert_exe');
    my $map_maf_src_field_exe = $self->require_executable('map_maf_src_field_exe');

    my $bigchain_autosql = $self->param_required('bigchain_autosql');
    my $biglink_autosql = $self->param_required('biglink_autosql');

    my $hal_file = $self->param('hal_file');
    my $output_maf_file_name = $self->param_required('output_maf_file');
    my $work_dir = $self->param_required('work_dir');
    my $output_maf_file_path = catfile($work_dir, $output_maf_file_name);

    my $ref_hal_genome = $self->param_required('ref_hal_genome');
    my $hal_mapping_dir = $self->param_required('hal_mapping_dir');
    my $ref_hal_mapping_file = catfile($hal_mapping_dir, $ref_hal_genome . '.hal_mapping.tsv');
    my @target_genomes = @{$self->param('maf_genomes')};

    $self->warning("Loading ref HAL mapping ...");
    my %ref_seq_map;
    open(my $fh, '<', $ref_hal_mapping_file) or die "Cannot read $ref_hal_mapping_file";
    my $header = <$fh>;
    chomp($header);
    my @head_cols = split(/\t/, $header);
    while( my $line = <$fh> ) {
        chomp($line);
        my $row = map_row_to_header( $line, \@head_cols );
        if ($row->{'hal_genome_name'} eq $ref_hal_genome) {
            my $hal_seq_name = $row->{'hal_sequence_name'};
            my $ens_seq_name = $row->{'assembly_sequence'};
            $ref_seq_map{$hal_seq_name} = $ens_seq_name;
        }
    }
    close($fh);

    my $output_bigchain1_file_path = $self->param_required('output_bigchain1_file');
    my ($output_bigchain1_file_name, $output_bigchain_dir) = fileparse($output_bigchain1_file_path);

    my $output_biglink1_file_path = $self->param_required('output_biglink1_file');
    my ($output_biglink1_file_name, $output_biglink_dir) = fileparse($output_biglink1_file_path);

    $self->param('bigchain_parent_dir', $output_bigchain_dir);
    my $temp_dir = tempdir( CLEANUP => 1, DIR => $self->worker_temp_directory );
    my $temp_bigchain1_file_path = catfile($temp_dir, $output_bigchain1_file_name);
    my $temp_biglink1_file_path = catfile($temp_dir, $output_biglink1_file_name);
    my $temp_bigchain_autosql = catfile($temp_dir, 'bigChain.as');
    my $temp_biglink_autosql = catfile($temp_dir, 'bigLink.as');

    $self->warning("Fetching bigChain.as ...");
    my $cmd1_args = ['wget', $bigchain_autosql, '--quiet', '--output-document', $temp_bigchain_autosql];
    $self->run_command($cmd1_args, { die_on_failure => 1 });

    $self->warning("Fetching bigLink.as ...");
    my $cmd2_args = ['wget', $biglink_autosql, '--quiet', '--output-document', $temp_biglink_autosql];
    $self->run_command($cmd2_args, { die_on_failure => 1 });

    $self->warning("Creating temp ref chromSizes file ...");
    my $temp_ref_chrom_sizes_file_path = catfile($temp_dir, 'ref.chrom.sizes');
    my $cmd3_args = [$hal_stats_exe, '--chromSizes', $ref_hal_genome, $hal_file];
    my $hal_chrom_size_text = $self->get_command_output($cmd3_args, { die_on_failure => 1 });

    my @maf_chrom_size_lines;
    open(my $fh, '<', \$hal_chrom_size_text);
    while( my $line = <$fh> ) {
        chomp($line);
        my ($hal_seq_name, $seq_size) = split(/\t/, $line);
        if (exists $ref_seq_map{$hal_seq_name}) {
            my $maf_seq_name = $ref_seq_map{$hal_seq_name};
            push(@maf_chrom_size_lines, join("\t", ($maf_seq_name, $seq_size)));
        }
    }
    close($fh);
    my $maf_chrom_size_text = join("\n", @maf_chrom_size_lines);
    $self->_spurt($temp_ref_chrom_sizes_file_path, $maf_chrom_size_text);

    my @hal_mapping_files;
    foreach my $idx (0 .. $#target_genomes) {
        my $hal_mapping_file = catfile($hal_mapping_dir, $target_genomes[$idx] . '.hal_mapping.tsv');
        push(@hal_mapping_files, $hal_mapping_file);
    }

    $self->warning("Renaming MAF src fields ...");
    my @maf_src_map_params = map { ('--src-map-file', $_) } @hal_mapping_files;
    my $relabelled_maf_path = catfile($temp_dir, 'relabelled.maf');
    my $cmd8_args = [
        $map_maf_src_field_exe,
        $output_maf_file_path,
        $relabelled_maf_path,
        '--only-seq-name',
        @maf_src_map_params,
    ];
    $self->warning(join(' ', @{$cmd8_args}));
    $self->run_command($cmd8_args, { die_on_failure => 1 });

    $self->warning("Creating temp chain file ...");
    my $temp_chain1_file_path = catfile($temp_dir, 'temp.chain');
    my @cmd4_args = (
        $maf_convert_exe,
        'chain',
        '--subject',
        '1',
        $relabelled_maf_path,
        '>',
        $temp_chain1_file_path,
    );
    $self->run_command(join(' ', @cmd4_args), { die_on_failure => 1 });

    $self->warning("Creating preliminary bigChain and bigLink files ...");
    my $prelim_bigchain1_file_path = catfile($temp_dir, 'bigChain.pre');  # intermediate BED file
    my $prelim_biglink1_file_path = catfile($temp_dir, 'bigChain.link.pre');  # intermediate BED file
    my $cmd5_args = [
        $chain_to_big_chain_exe,
        $temp_chain1_file_path,
        $prelim_bigchain1_file_path,
        $prelim_biglink1_file_path,
    ];
    $self->run_command($cmd5_args, { die_on_failure => 1 });

    $self->warning("Creating bigChain file ...");
    my $cmd6_args = [
        $big_bed_exe,
        '-type=bed6+6',
        '-as=' . $temp_bigchain_autosql,
        '-tab',
        $prelim_bigchain1_file_path,
        $temp_ref_chrom_sizes_file_path,
        $temp_bigchain1_file_path,
    ];
    $self->run_command($cmd6_args, { die_on_failure => 1 });

    $self->warning("Creating bigLink file ...");
    my $cmd7_args = [
        $big_bed_exe,
        '-type=bed4+1',
        '-as=' . $temp_biglink_autosql,
        '-tab',
        $prelim_biglink1_file_path,
        $temp_ref_chrom_sizes_file_path,
        $temp_biglink1_file_path,
    ];
    $self->run_command($cmd7_args, { die_on_failure => 1 });

    $self->param('temp_bigchain1_file_path', $temp_bigchain1_file_path);
    $self->param('temp_biglink1_file_path', $temp_biglink1_file_path);


    my $output_bigchain2_file_path = $self->param_required('output_bigchain2_file');
    my ($output_bigchain2_file_name, $unused_bigchain_dir) = fileparse($output_bigchain2_file_path);

    my $output_biglink2_file_path = $self->param_required('output_biglink2_file');
    my ($output_biglink2_file_name, $unused_biglink_dir) = fileparse($output_biglink2_file_path);

    my $temp_bigchain2_file_path = catfile($temp_dir, $output_bigchain2_file_name);
    my $temp_biglink2_file_path = catfile($temp_dir, $output_biglink2_file_name);

    $self->warning("Creating temp alt chromSizes file ...");
    my ($alt_hal_genome) = grep { $_ ne $ref_hal_genome} @target_genomes;
    my $alt_hal_mapping_file = catfile($hal_mapping_dir, $alt_hal_genome . '.hal_mapping.tsv');

    $self->warning("Loading alt HAL mapping ...");
    my %alt_seq_map;
    open(my $fh, '<', $alt_hal_mapping_file) or die "Cannot read $alt_hal_mapping_file";
    my $header = <$fh>;
    chomp($header);
    my @head_cols = split(/\t/, $header);
    while( my $line = <$fh> ) {
        chomp($line);
        my $row = map_row_to_header( $line, \@head_cols );
        if ($row->{'hal_genome_name'} eq $alt_hal_genome) {
            my $hal_seq_name = $row->{'hal_sequence_name'};
            my $ens_seq_name = $row->{'assembly_sequence'};
            $alt_seq_map{$hal_seq_name} = $ens_seq_name;
        }
    }
    close($fh);

    my $temp_alt_chrom_sizes_file_path = catfile($temp_dir, 'alt.chrom.sizes');
    my $cmd3_args = [$hal_stats_exe, '--chromSizes', $alt_hal_genome, $hal_file];
    my $hal_chrom_size_text = $self->get_command_output($cmd3_args, { die_on_failure => 1 });

    my @maf_chrom_size_lines;
    open(my $fh, '<', \$hal_chrom_size_text);
    while( my $line = <$fh> ) {
        chomp($line);
        my ($hal_seq_name, $seq_size) = split(/\t/, $line);
        if (exists $alt_seq_map{$hal_seq_name}) {
            my $maf_seq_name = $alt_seq_map{$hal_seq_name};
            push(@maf_chrom_size_lines, join("\t", ($maf_seq_name, $seq_size)));
        }
    }
    close($fh);
    my $maf_chrom_size_text = join("\n", @maf_chrom_size_lines);
    $self->_spurt($temp_alt_chrom_sizes_file_path, $maf_chrom_size_text);

    $self->warning("Creating swapped chain file ...");
    my $temp_chain2_file_path = catfile($temp_dir, 'temp2.chain');
    my @cmd9_args = (
        $chainSwap_exe,
        $temp_chain1_file_path,
        $temp_chain2_file_path,
    );
    $self->run_command(join(' ', @cmd9_args), { die_on_failure => 1 });

    $self->warning("Creating preliminary swapped bigChain and bigLink files ...");
    my $prelim_bigchain2_file_path = catfile($temp_dir, 'bigChain2.pre');  # intermediate BED file
    my $prelim_biglink2_file_path = catfile($temp_dir, 'bigChain2.link.pre');  # intermediate BED file
    my $cmd10_args = [
        $chain_to_big_chain_exe,
        $temp_chain2_file_path,
        $prelim_bigchain2_file_path,
        $prelim_biglink2_file_path,
    ];
    $self->run_command($cmd10_args, { die_on_failure => 1 });

    $self->warning("Creating swapped bigChain file ...");
    my $cmd11_args = [
        $big_bed_exe,
        '-type=bed6+6',
        '-as=' . $temp_bigchain_autosql,
        '-tab',
        $prelim_bigchain2_file_path,
        $temp_alt_chrom_sizes_file_path,
        $temp_bigchain2_file_path,
    ];
    $self->run_command($cmd11_args, { die_on_failure => 1 });

    $self->warning("Creating swapped bigLink file ...");
    my $cmd12_args = [
        $big_bed_exe,
        '-type=bed4+1',
        '-as=' . $temp_biglink_autosql,
        '-tab',
        $prelim_biglink2_file_path,
        $temp_alt_chrom_sizes_file_path,
        $temp_biglink2_file_path,
    ];
    $self->run_command($cmd12_args, { die_on_failure => 1 });

    $self->param('temp_bigchain2_file_path', $temp_bigchain2_file_path);
    $self->param('temp_biglink2_file_path', $temp_biglink2_file_path);
}


sub write_output {
    my $self = shift;

    my $bigchain_parent_dir = $self->param_required('work_dir');
    make_path($bigchain_parent_dir);

    my $temp_bigchain1_file_path = $self->param_required('temp_bigchain1_file_path');
    my $temp_biglink1_file_path = $self->param_required('temp_biglink1_file_path');
    my $bigchain1_file_name = $self->param_required('output_bigchain1_file');
    my $biglink1_file_name = $self->param_required('output_biglink1_file');
    my $bigchain1_file_path = catfile($bigchain_parent_dir, $bigchain1_file_name);
    my $biglink1_file_path = catfile($bigchain_parent_dir, $biglink1_file_name);
    move($temp_bigchain1_file_path, $bigchain1_file_path);
    move($temp_biglink1_file_path, $biglink1_file_path);

    my $temp_bigchain2_file_path = $self->param_required('temp_bigchain2_file_path');
    my $temp_biglink2_file_path = $self->param_required('temp_biglink2_file_path');
    my $bigchain2_file_name = $self->param_required('output_bigchain2_file');
    my $biglink2_file_name = $self->param_required('output_biglink2_file');
    my $bigchain2_file_path = catfile($bigchain_parent_dir, $bigchain2_file_name);
    my $biglink2_file_path = catfile($bigchain_parent_dir, $biglink2_file_name);
    move($temp_bigchain2_file_path, $bigchain2_file_path);
    move($temp_biglink2_file_path, $biglink2_file_path);
}


1;
