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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::BaseDumpGenomeSequence

=head1 DESCRIPTION

Pseudo Runnable with the functionality that is needed and shared by
DumpMaskedGenomeSequence and DumpUnmaskedGenomeSequence.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::BaseDumpGenomeSequence;

use strict;
use warnings;

use File::Basename;

use base ('Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },

        'is_reference'  => 1,       # Set this to 0 to only dump the non-reference dnafrags. This Runnable does not support dumping all dnafrags at once

        # Parameters of Bio::EnsEMBL::Utils::IO::FASTASerializer
        # They have a default value in the serializer itself, but can be redefined here
        'seq_width'     => 60,      # Characters per line in the FASTA file. Defaults to 60
        'chunk_factor'  => undef,   # Number of lines to be buffered by the serializer. Defaults to 1,000
    }
}


sub fetch_input {
    my $self = shift;

    # Fetch the GenomeDB
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID( $self->param_required('genome_db_id') )
                     || die "Cannot find a GenomeDB with dbID=".$self->param('genome_db_id');
    $self->param('genome_db', $genome_db);

    # Where the files should be
    $self->param_required('genome_dumps_dir');

    # The expected file size: DNA + line-returns + dnafrag name + ">" + line-return
    my $sql = 'SELECT SUM(length + CEIL(length/?) + FLOOR(LOG10(dnafrag_id)) + 3) FROM dnafrag WHERE genome_db_id = ? AND is_reference = ?';
    my ($ref_size) = $self->compara_dba->dbc->db_handle->selectrow_array($sql, undef, $self->param('seq_width'), $genome_db->dbID, $self->param_required('is_reference'));
    $self->param('ref_size', $ref_size);

    my $paths = $self->set_dump_paths();

    # If all the files are there, we're good to go
    my $dump_needed = 0;
    foreach my $path (@$paths) {
        unless (-e $path) {
            $self->warning("$path doesn't exist");
            $dump_needed = 1;
            last;
        }
        if ($ref_size != -s $path) {
            $self->warning("$path is " . (-s $path) . " bytes instead of $ref_size" );
            $dump_needed = 1;
            last;
        }
    }
    if (!$dump_needed) {
        if (grep {$_ eq $genome_db->name} @{$self->param_required('force_redump')}) {
            $self->warning('Dumps of ' . $genome_db->name . ' look fine, but redump requested');
        } else {
            $self->write_output();
            $self->input_job->autoflow(0);
            $self->complete_early('All dumps already there');
        }
    }

    my $tmp_dump_file = $self->worker_temp_directory . '/' . $self->param_required('genome_db_id') . '.fa';

    $self->param('cellular_components_exclude', []);                # Dump everything
    $self->param('cellular_components_only',    []);                # I said everything
    $self->param('genome_dump_file',            $tmp_dump_file);    # Somewhere under /tmp

    $self->SUPER::fetch_input();
}


sub _install_dump {
    my ($self, $tmp_dump_file, $target_file) = @_;

    my $ref_size = $self->param('ref_size');
    if ($ref_size != -s $tmp_dump_file) {
        die "$tmp_dump_file is " . (-s $tmp_dump_file) . " bytes instead of $ref_size";
    }

    # Assuming all three files are in the same directory
    my $cmd = ['mkdir', '-p', dirname($target_file)];
    $self->run_command($cmd, { die_on_failure => 1 });

    # Copy the file (making sure the file permissions are correct regarless of the user's umask)
    $cmd = ['install', '--preserve-timestamps', '--mode=664', $tmp_dump_file, $target_file];
    $self->run_command($cmd, { die_on_failure => 1 });
    die "$target_file size mismatch" if $ref_size != -s $target_file;
}


1;

