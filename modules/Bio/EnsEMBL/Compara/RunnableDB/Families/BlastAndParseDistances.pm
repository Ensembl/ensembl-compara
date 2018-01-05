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

package Bio::EnsEMBL::Compara::RunnableDB::Families::BlastAndParseDistances;

use strict;
use warnings;
use FileHandle;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub load_fasta_sequences_from_db {
    my ($self, $start_seq_id, $end_seq_id) = @_;

    my $idprefixed              = $self->param('idprefixed')  || 0;
    my $debug                   = $self->debug() || $self->param('debug') || 0;

    my $sql = qq {
        SELECT s.sequence_id, m.stable_id, s.sequence
          FROM seq_member m, sequence s
         WHERE s.sequence_id BETWEEN ? AND ?
           AND m.sequence_id=s.sequence_id
      GROUP BY s.sequence_id
      ORDER BY s.sequence_id
    };

    if($debug) {
        print "SQL:  $sql\n";
    }

    my $sth = $self->compara_dba->dbc->prepare( $sql );
    $sth->execute( $start_seq_id, $end_seq_id );

    my @fasta_list = ();
    while( my ($seq_id, $stable_id, $seq) = $sth->fetchrow() ) {
        $seq=~ s/(.{72})/$1\n/g;
        chomp $seq;
        push @fasta_list, ($idprefixed
                                ? ">seq_id_${seq_id}_${stable_id}\n$seq\n"
                                : ">$stable_id sequence_id=$seq_id\n$seq\n") ;
    }
    $sth->finish();

    $self->compara_dba->dbc->disconnect_when_inactive(1);

    return \@fasta_list;
}


sub load_name2index_mapping_from_db {
    my ($self) = @_;

    my $sql = qq {
        SELECT sequence_id, stable_id
          FROM seq_member
         WHERE sequence_id
      GROUP BY sequence_id
    };

    my $sth = $self->compara_dba->dbc->prepare( $sql );
    $sth->execute();

    my %name2index = ();
    while( my ($seq_id, $stable_id) = $sth->fetchrow() ) {
        $name2index{$stable_id} = $seq_id;
    }
    $sth->finish();

    $self->compara_dba->dbc->disconnect_when_inactive(1);

    return \%name2index;
}


sub name2index { # can load the name2index mapping from db/file if necessary
    my ($self, $name) = @_;

    if($name=~/^seq_id_(\d+)_/) {
        return $1;
    } else {
        my $name2index = $self->param('name2index') || $self->param('name2index', $self->load_name2index_mapping_from_db() );

        return $name2index->{$name};
    }
}


sub fetch_input {
    my $self = shift @_;

    my $start_seq_id            = $self->param_required('start_seq_id');
    my $end_seq_id              = $self->param_required('end_seq_id');
    my $minibatch               = $self->param('minibatch')   || 1;
    my $debug                   = $self->debug() || $self->param('debug') || 0;

    my $fasta_list = $self->load_fasta_sequences_from_db($start_seq_id, $end_seq_id);

    if(scalar(@$fasta_list)<$minibatch) {
        die "Could not load all ($minibatch) sequences, please investigate";
    }

    if($debug) {
        print "Loaded ".scalar(@$fasta_list)." sequences\n";
    }

    $self->param('fasta_list', $fasta_list);
}


sub parse_blast_table_into_matrix_hash {
    my ($self, $filename, $min_self_similarity) = @_;

    my $roundto    = $self->param('roundto') || 0.0001;

    my %matrix_hash  = ();

    my $curr_name    = '';
    my $curr_index   = 0;

    open(BLASTTABLE, "<$filename") || die "Could not open the blast table file '$filename'";
    while(my $line = <BLASTTABLE>) {

        if($line=~/^#/) {
            if($line=~/^#\s+Query:\s+(\S+)/) {
                $curr_name  = $1;
                $curr_index = $self->name2index($curr_name)
                    || die "Parser could not map '$curr_name' to sequence_id";

                $matrix_hash{$curr_index}{$curr_index} = $min_self_similarity;  # stop losing singletons whose evalue to themselves is *above* 'evalue_limit' threshold
                                                                                # (that is, the ones that are "not even similar to themselves")
            }
        } else {
            my ($qname, $hname, $evalue) = split(/\s+/, $line);

            my $hit_index = $self->name2index($hname);
                # we MUST be explicitly numeric here:
            my $new_similarity  = ($evalue != 0) ? -log($evalue)/log(10) : 200;

                # do the rounding to prevent the unnecessary growth of tables/files
            $new_similarity = int($new_similarity / $roundto) * $roundto;

            my $prev_similarity = $matrix_hash{$curr_index}{$hit_index};

            $matrix_hash{$curr_index}{$hit_index} = $new_similarity unless(defined($prev_similarity) && $new_similarity<$prev_similarity);
        }
    }
    close BLASTTABLE;

    return \%matrix_hash;
}


sub run {
    my $self = shift @_;

    my $fasta_list              = $self->param('fasta_list'); # set by fetch_input()
    my $debug                   = $self->debug() || $self->param('debug') || 0;

    unless(scalar(@$fasta_list)) { # if we have no more work to do just exit gracefully
        if($debug) {
            warn "No work to do, exiting\n";
        }
        return;
    }

    my $blastdb_dir             = $self->param('blastdb_dir');
    my $blastdb_name            = $self->param_required('blastdb_name');

    my $start_seq_id            = $self->param('start_seq_id');

    my $blast_bin_dir           = $self->param_required('blast_bin_dir');
    my $blast_params            = $self->param('blast_params')  || '';  # no parameters to C++ binary means having composition stats on and -seg masking off
    my $evalue_limit            = $self->param('evalue_limit')  || 0.00001;
    my $tophits                 = $self->param('tophits')       || 250;

    my $worker_temp_directory   = $self->worker_temp_directory;

    my $blast_infile  = $worker_temp_directory . "/blast_${start_seq_id}.in";    # only for debugging
    my $blast_outfile = $worker_temp_directory . "/blast_${start_seq_id}.out";   # looks like inevitable evil (tried many hairy alternatives and failed)

    if($debug) {
        $self->_spurt($blast_infile, join('', @$fasta_list));
    }

    my $blastdb = ($blastdb_dir ? $blastdb_dir.'/' : '').$blastdb_name;
    my $cmd = "${blast_bin_dir}/blastp -db $blastdb $blast_params -evalue $evalue_limit -max_target_seqs $tophits -out $blast_outfile -outfmt '7 qacc sacc evalue'";

    if($debug) {
        warn "CMD:\t$cmd\n";
    }

    open( BLAST, "| $cmd") || die qq{could not execute "${cmd}", returned error code: $!};
    print BLAST @$fasta_list;
    my $peaceful_close = close BLAST;

    unless($peaceful_close) {
        # Possibly an ongoing MEMLIMIT
        # Let's wait a bit to let LSF kill the worker as it should
        sleep(30);
        #
        die "Error caught when closing the pipe to Blast, the child probably killed";
    }

    my $matrix_hash = $self->parse_blast_table_into_matrix_hash($blast_outfile, -log($evalue_limit)/log(10) );

    my $expected_elements   = scalar(@$fasta_list);
    my $parsed_elements     = scalar(keys %$matrix_hash);
    unless($parsed_elements == $expected_elements) {
        die "Could only parse $parsed_elements out of $expected_elements";
    }

    $self->param('matrix_hash', $matrix_hash);        # store it in a parameter

    unless($debug) {
        unlink $blast_outfile;
    }
}


sub write_output {
    my $self = shift @_;

    if(my $matrix_hash = $self->param('matrix_hash')) {
        my @output_ids = ();
        while(my($row_id, $subhash) = each %$matrix_hash) {
            while(my($column_id, $value) = each %$subhash) {
                push @output_ids, { 'row_id' => $row_id, 'column_id' => $column_id, 'value' => $value};
            }
        }
        $self->dataflow_output_id( \@output_ids, 3);
    }
}

1;
