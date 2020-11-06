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

Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpUnmaskedGenomeSequence

=head1 DESCRIPTION

Module to dump the unmasked genome sequences.
The files are moved to a shared directory.

Input parameters

=over

=item genome_db_id

dbID of the GenomeDB to dump

=item genome_dumps_dir

Base directory in which to dump the genomes

=back

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpUnmaskedGenomeSequence;

use strict;
use warnings;

use File::Basename;

use base ('Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::BaseDumpGenomeSequence');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },

        # Parameters of Bio::EnsEMBL::Utils::IO::FASTASerializer
        # They have a default value in the serializer itself, but can be redefined here
        'seq_width'     => 60,      # Characters per line in the FASTA file. Defaults to 60
        'chunk_factor'  => undef,   # Number of lines to be buffered by the serializer. Defaults to 1,000
    }
}


sub set_dump_paths {
    my $self = shift;

    my $genome_db = $self->param('genome_db');

    # Where the files should be
    $self->param('unmasked_file',    $genome_db->_get_genome_dump_path($self->param('genome_dumps_dir')));

    return [$self->param('unmasked_file')];
}


sub run {
    my $self = shift;

    # Get the filenames
    my $tmp_dump_file    = $self->param('genome_dump_file');
    my $unmasked_file    = $self->param('unmasked_file');

    my $ref_size = -s $tmp_dump_file;
    die "$tmp_dump_file is empty" unless $ref_size;

    # Make the directory
    my $cmd = ['mkdir', '-p', dirname($unmasked_file)];
    $self->run_command($cmd, { die_on_failure => 1 });

    # Copy the file (making sure the file permissions are correct regarless of the user's umask)
    $cmd = ['install', '--preserve-timestamps', '--mode=664', $tmp_dump_file, $unmasked_file];
    $self->run_command($cmd, { die_on_failure => 1 });
    die "$unmasked_file size mismatch" if $ref_size != -s $unmasked_file;

    unlink $tmp_dump_file;
}


sub write_output {
    my ($self) = @_;
    $self->dataflow_output_id( {'genome_dump_file' => $self->param('unmasked_file')} );
}

1;

