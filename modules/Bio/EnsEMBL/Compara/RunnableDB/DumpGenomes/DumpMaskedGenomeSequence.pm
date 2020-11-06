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

Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpMaskedGenomeSequence

=head1 DESCRIPTION

Module to dump the soft- and hard-masked genome sequences.
The files are moved to a shared directory.

Input parameters

=over

=item genome_db_id

dbID of the GenomeDB to dump

=item genome_dumps_dir

Base directory in which to dump the genomes

=back

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpMaskedGenomeSequence;

use strict;
use warnings;

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
    $self->param('soft_masked_file', $genome_db->_get_genome_dump_path($self->param('genome_dumps_dir'), 'soft'));
    $self->param('hard_masked_file', $genome_db->_get_genome_dump_path($self->param('genome_dumps_dir'), 'hard'));

    $self->param('repeat_masked',               'soft');            # and soft-masked.

    return [$self->param('soft_masked_file'), $self->param('hard_masked_file')];
}


sub run {
    my $self = shift;

    # Get the filenames
    my $tmp_dump_file    = $self->param('genome_dump_file');
    my $soft_masked_file = $self->param('soft_masked_file');
    my $hard_masked_file = $self->param('hard_masked_file');

    $self->_install_dump($tmp_dump_file, $soft_masked_file);

    # Convert to hard-masked
    my $cmd = qq{bash -c "tr a-z N < '$tmp_dump_file' > '$hard_masked_file'"};
    $self->run_command($cmd, { die_on_failure => 1 });
    die "$hard_masked_file size mismatch" if -s $tmp_dump_file != -s $hard_masked_file;

    unlink $tmp_dump_file;
}


sub write_output {
    my ($self) = @_;
    $self->dataflow_output_id( {'mask' => 'soft', 'genome_dump_file' => $self->param('soft_masked_file')}, 2 );
    $self->dataflow_output_id( {'mask' => 'hard', 'genome_dump_file' => $self->param('hard_masked_file')}, 2 );
}

1;

