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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ChunkAndGroupDnaFrags

=head1 DESCRIPTION

Chunk DnaFrags into smaller pieces, and group them, so that each
"chunk set" has "chunk_size" base-pairs in it.

Also create a file with the size of each dnafrag.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ChunkAndGroupDnaFrags;

use strict;
use warnings;

use File::Basename;
use File::Path qw(make_path);
use List::Util qw(sum);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'chunk_size'        => 1_000_000,
        'bed_chucnks_dir'   => undef,
    }
}

sub fetch_input {
    my $self = shift;
    $self->create_chunks_and_write_chromsize_file;
}


sub write_output {
    my $self = shift;

    my $i = 0;
    foreach my $cs (@{$self->param('all_chunksets')}) {
        $self->dataflow_output_id({'chunkset' => $cs, 'chunkset_id' => $i}, 2);
        $i++;
    }
}



######################################
#
# subroutines
#
#####################################

sub create_chunks_and_write_chromsize_file {
    my $self = shift;

    my $chromsize_file = $self->param_required('chromsize_file');
    make_path(dirname($chromsize_file));
    open(my $fh, '>', $chromsize_file) or die "Cannot open $chromsize_file for writing";

    # Iterator so that we don't use too much memory
    my $dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param_required('compara_db') )->dbc;

    my $sql = q{SELECT name, length FROM dnafrag WHERE genome_db_id = ? AND is_reference = 1 ORDER BY name COLLATE latin1_bin};
    my $sth = $dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute($self->param_required('genome_db_id'));

    my @all_chunksets;
    my $current_chunkset = [];
    my $chunk_size_left = $self->param_required('chunk_size');

    my $tot_size = 0;
    while (my $aref = $sth->fetchrow_arrayref) {
        my ($dnafrag_name, $dnafrag_length) = @$aref;
        print $fh join("\t", @$aref), "\n";

        my $dnafrag_start = 1;
        $tot_size += $dnafrag_length;

        while (1) {
            my $dnafrag_size_left = $dnafrag_length - $dnafrag_start + 1;

            if ($dnafrag_size_left <= $chunk_size_left) {
                # The remainder of the dnafrag doesn't fill the chunkset
                push @$current_chunkset, [$dnafrag_name, $dnafrag_start, $dnafrag_length];
                $chunk_size_left -= $dnafrag_size_left;
                last;

            } else {
                # Let's fill up the chunkset
                my $chunk_end = $dnafrag_start + $chunk_size_left - 1;
                push @$current_chunkset, [$dnafrag_name, $dnafrag_start, $chunk_end];
                $dnafrag_start = $chunk_end + 1;
                push @all_chunksets, $current_chunkset;
                $current_chunkset = [];
                $chunk_size_left = $self->param('chunk_size');
            }
        }
    }

    close $fh;

    push @all_chunksets, $current_chunkset if $current_chunkset and @$current_chunkset;

    # Healthcheck: the sizes must match
    my $tot_chunk_size = 0;
    foreach my $cs (@all_chunksets) {
        $tot_chunk_size += sum(map {$_->[2]-$_->[1]+1} @$cs);
    }
    die "$tot_size vs $tot_chunk_size" if $tot_size != $tot_chunk_size;

    $self->param('all_chunksets', \@all_chunksets);
}

1;
