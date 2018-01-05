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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CDHit 

=head1 DESCRIPTION

Conctenates *.fasta in the param 'fasta_dir' and run cd-hit on it. 
Then parse the output clusters into seq_member_projection.

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
    my $cdhit_threshold = $self->param_required('cdhit_identity_threshold');
    my $fasta_dir       = $self->param_required('fasta_dir');

    my $genome_db_ids = $self->param_required('genome_db_ids'); # die now, rather than running whole thing and dying @ write_output

    unless ( defined $self->param('cluster_file')) {

        my $tmp_dir = $self->param('tmp_dir') || $self->worker_temp_directory;
        my $fasta_db = "$tmp_dir/multispecies_db.fa";
        system("cat $fasta_dir/*.fasta > $fasta_db") == 0 or die "Error concatenating fasta files from $fasta_dir to $fasta_db";
        my $cdhit_mem = $self->param_required('cdhit_memory_in_mb');
        my $cdhit_num_threads = $self->param_required('cdhit_num_threads');
        my $cmd = [$cdhit_exe, -i => $fasta_db, -o => "$tmp_dir/blastdb", -c => $cdhit_threshold, -M => $cdhit_mem, -T => $cdhit_num_threads];
        $self->run_command($cmd, { die_on_failure => 1 });

        my ($cluster_file, $cdhit_outfile) = ("$tmp_dir/blastdb.clstr", "$tmp_dir/cdhit.out");
        $self->param( 'cluster_file',  $cluster_file  );
    }

    die "Problem finding cd-hit output: " . $self->param('cluster_file') . "\n"  unless ( -e $self->param('cluster_file') );
    
    my $clusters = $self->parse_clusters; # prepare clusters for seq_member_projection table
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

    warn "Found ", scalar(@seq_projections), " projections.\n" if $self->debug;

    $self->param('seq_projections', \@seq_projections);
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

    foreach my $pro ( @projection ) {
        $pro->{source_seq_member_id} = $rep_seq;
    }

    return \@projection;
}

1;



