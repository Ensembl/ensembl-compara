=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::CDHit 

=head1 DESCRIPTION

Conctenates *.fasta in the param 'fasta_dir' and run cd-hit on it. 
Then parse the output into seq_member_projection.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CDHit;

use strict;
use warnings;

use File::Basename;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {}

sub run {
    my $self = shift;

    my $cdhit_exe       = $self->param_required('cdhit_exe');
    # my $fasta_db        = $self->param_required('fasta_name');
    my $cdhit_threshold = $self->param_required('cdhit_identity_threshold');
    my $fasta_dir       = $self->param_required('fasta_dir');

    # die "Database '$fasta_db' does not exist!" unless ( -e $fasta_db );

    unless ( defined $self->param('cluster_file' ) &&
             defined $self->param('cdhit_outfile')) {

        # my $tmp_dir = $self->param('tmp_dir') || $self->worker_temp_directory;
        my $tmp_dir = $fasta_dir;
        my $fasta_db = "$tmp_dir/multispecies_db.fasta";
        system("cat $fasta_dir/*.fasta > $fasta_db"); # == 0 or die "Error concatenating fasta files from $fasta_dir to $fasta_db";
        my $cdhit_mem = $self->param_required('cdhit_memory_in_mb');
        my $cdhit_num_threads = $self->param_required('cdhit_num_threads');
        my $cmd = "$cdhit_exe -i $fasta_db -o $tmp_dir/blastdb -c $cdhit_threshold -M $cdhit_mem -T $cdhit_num_threads > $tmp_dir/cdhit.out";
        print " --- $cmd\n" if $self->debug;
        system($cmd); # == 0 or die "Error running command: $cmd";

        my ($cluster_file, $cdhit_outfile) = ("$tmp_dir/blastdb.clstr", "$tmp_dir/cdhit.out");
        die "Problem finding cd-hit output: $cluster_file\n"  unless ( -e $cluster_file   );
        die "Problem finding cd-hit output: $cdhit_outfile\n" unless ( -e  $cdhit_outfile );
        $self->param( 'cluster_file',  $cluster_file  );
        $self->param( 'cdhit_outfile', $cdhit_outfile );
    }

    #$self->reinclude_filtered_sequences; # cd-hit filters out sequences with ambiguous characters - add them back into blast db
    my $clusters = $self->parse_clusters; # prepare clusters for seq_member_projection table
    my $filtered = $self->parse_filtered_sequences; # cd-hit filters out sequences with ambiguous characters - catch them
    my @seq_projections = ( @$clusters, @$filtered );
    $self->param( 'seq_projections', \@seq_projections );
}

sub write_output {
    my $self = shift;

    # flow genome_db_ids!
    my @br2_dataflow;
    foreach my $gdb ( @{ $self->param_required( 'genome_db_ids' ) } ) {
        push( @br2_dataflow, { genome_db_id => $gdb } );
    }
    $self->dataflow_output_id( \@br2_dataflow, 2 ); # to dump_representative_members analysis
    
    my $br3_dataflow = $self->param('seq_projections');
    $self->dataflow_output_id( $br3_dataflow, 3 ); # to seq_member_projection table
}

sub parse_filtered_sequences {
    my $self = shift;

    open(CDHIT_OUT, '<',  $self->param_required('cdhit_outfile'));
    my @filtered_seq_member_ids;
    while ( my $line = <CDHIT_OUT> ) {
        chomp $line;
        if ( $line =~ m/^>([0-9]+)/ ) {
            push( @filtered_seq_member_ids, $1 );
        }
    }

    my @filtered_projs;
    foreach my $filt ( @filtered_seq_member_ids ) {
        push( @filtered_projs, { source_seq_member_id => $filt  } );
    }
    # $self->param( 'seq_projections', @seq_projections );
    return \@filtered_projs;
}

# sub reinclude_filtered_sequences {
#     my $self = shift;

#     open(CDHIT_OUT, '<',  $self->param_required('cdhit_outfile'));
#     open(BLASTDB,   '>>', $self->param_required('blastdb_file'));
    
#     my ( $fasta_capture, $this_fasta_seq );
#     while ( my $line = <CDHIT_OUT> ) {
#         chomp $line;
#         if ( $line =~ m/^>/ ) { # start of fasta sequence
#             $fasta_capture = 1;
#         }
#         elsif ( $fasta_capture && $line =~ m/[^>A-Z*]+/ ) { # end of fasta sequence - append it to blastdb
#             print BLASTDB "$this_fasta_seq";
            
#             $fasta_capture = 0;
#             $this_fasta_seq = '';
#         }

#         $this_fasta_seq .= "$line\n" if ( $fasta_capture ); # capture open fasta sequences
#     }

#     close CDHIT_OUT;
#     close BLASTDB;
# }

# >Cluster 19801
# 0       45aa, >621010... *
# 1       45aa, >622175... at 100.00%
# 2       45aa, >622235... at 100.00%
# >Cluster 19802
# 0       45aa, >943204... *

sub parse_clusters {
    my $self = shift;

    my $cluster_file = $self->param_required('cluster_file');
    open( CLSTR, '<', $cluster_file );
    
    my @seq_projections;
    my @this_cluster;
    my $c = 1;
    while ( my $line = <CLSTR> ) {
        chomp $line;

        if ( $line =~ m/^>/ ) { # new cluster start
            if ( @this_cluster ) { 
                push( @seq_projections, @{ $self->_cluster_to_seq_projection( \@this_cluster ) } );
                @this_cluster = ();
            }
        } elsif ( $line =~ m/^[0-9]/ ) { # add to current cluster
            my @parts = split( ',', $line );
            push( @this_cluster, $parts[1] );
        } else {
            die "File format violation in $cluster_file, line $c :\n\t$line\n";
        }
        $c++;
    }
    # catch final cluster!
    push( @seq_projections, @{ $self->_cluster_to_seq_projection( \@this_cluster ) } );

    # $self->param('seq_projections', \@seq_projections);
    return \@seq_projections;
}

sub _cluster_to_seq_projection {
    my ( $self, $cluster ) = @_;

    my @projection;
    my $rep_seq;
    foreach my $cl_member ( @{$cluster} ) {
        if ( $cl_member =~ m/>([0-9]+)\.\.\. at ([0-9\.]+)%/ ) {
            push( @projection, { target_seq_member_id => $1, identity => $2 } );
        }
        elsif ( $cl_member =~ m/>([0-9]+)\.\.\. \*/ ) {
            $rep_seq = $1;
        }
    }

    # even if nothing is projected (i.e. only one seq in cluster), we still want to flow
    # it as a representative sequence for downstream dumping of sequences which will rely on
    # the seq_member_projection table
    @projection = ({}) unless defined $projection[0];
    foreach my $pro ( @projection ) {
        $pro->{source_seq_member_id} = $rep_seq;
    }

    return \@projection;
}

1;



