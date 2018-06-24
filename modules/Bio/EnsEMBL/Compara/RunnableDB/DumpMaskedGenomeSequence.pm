=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence

=head1 DESCRIPTION

Module to dump the genome sequences (unmasked, soft-masked and hard-masked of a given genome.
The files are moved to a shared directory.

Input parameters

=over

=item genome_db_id

dbID of the GenomeDB to dump

=item genome_dumps_dir

Base directory in which to dump the genomes

=back

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMaskedGenomeSequence;

use strict;
use warnings;

use File::Basename;
use File::Path qw(make_path);

use base ('Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },

        # Parameters of Bio::EnsEMBL::Utils::IO::FASTASerializer
        # They have a default value in the serializer itself, but can be redefined here
        'seq_width'     => 60,      # Characters per line in the FASTA file. Defaults to 60
        'chunk_factor'  => undef,   # Number of lines to be buffered by the serializer. Defauls to 1,000
    }
}


sub fetch_input {
    my $self = shift;

    # Fetch the GenomeDB
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID( $self->param_required('genome_db_id') )
                     || die "Cannot find a GenomeDB with dbID=".$self->param('genome_db_id');
    $self->param('genome_db', $genome_db);

    # Where the files should be
    $self->param('soft_masked_file', $genome_db->_get_genome_dump_path($self->param('genome_dumps_dir'), 'soft'));
    $self->param('hard_masked_file', $genome_db->_get_genome_dump_path($self->param('genome_dumps_dir'), 'hard'));

    # The expected file size: DNA + line-returns + dnafrag name + ">" + line-return
    my $sql = 'SELECT SUM(length + CEIL(length/?) + CEIL(LOG10(dnafrag_id)) + 2) FROM dnafrag WHERE genome_db_id = ?';
    my ($ref_size) = $self->compara_dba->dbc->db_handle->selectrow_array($sql, undef, $self->param('seq_width'), $genome_db->dbID);

    # If all the files are there, we're good to go
    my $err = 0;
    foreach my $file_param (qw(soft_masked_file hard_masked_file)) {
        unless (-e $self->param($file_param)) {
            $self->warning($self->param($file_param) . " doesn't exist");
            $err = 1;
            last;
        }
        if ($ref_size != -s $self->param($file_param)) {
            $self->warning($self->param($file_param) . " is " . (-s $self->param($file_param)) . " bytes instead of $ref_size" );
            $err = 1;
            last;
        }
    }
    if (!$err) {
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
    $self->param('repeat_masked',               'soft');            # and soft-masked.

    if ($self->param('reg_conf')) {
        $self->load_registry($self->param('reg_conf'));
    }

    $self->SUPER::fetch_input();
}


sub run {
    my $self = shift;

    # Get the filenames
    my $shared_user      = $self->param_required('shared_user');
    my $genome_db        = $self->param('genome_db');
    my $tmp_dump_file    = $self->param('genome_dump_file');
    my $soft_masked_file = $self->param('soft_masked_file');
    my $hard_masked_file = $self->param('hard_masked_file');

    my $ref_size = -s $tmp_dump_file;
    die "$tmp_dump_file is empty" unless $ref_size;

    # Assuming all three files are in the same directory
    my $cmd = ['become', $shared_user, 'mkdir', '-p', dirname($soft_masked_file)];
    $self->run_command($cmd, { die_on_failure => 1 });

    # Copy the file
    $cmd = ['become', $shared_user, 'cp', '--preserve=timestamps', $tmp_dump_file, $soft_masked_file];
    $self->run_command($cmd, { die_on_failure => 1 });
    die "$soft_masked_file size mismatch" if $ref_size != -s $soft_masked_file;

    # Convert to hard-masked
    $cmd = qq{become $shared_user bash -c "tr a-z N < '$tmp_dump_file' > '$hard_masked_file'"};
    $self->run_command($cmd, { die_on_failure => 1 });
    die "$hard_masked_file size mismatch" if $ref_size != -s $hard_masked_file;
}


sub write_output {
    my ($self) = @_;
    $self->dataflow_output_id( {'genome_dump_file' => $self->param('soft_masked_file')}, 2 );
    $self->dataflow_output_id( {'genome_dump_file' => $self->param('hard_masked_file')}, 2 );
    unlink $self->param('genome_dump_file');
}

1;

