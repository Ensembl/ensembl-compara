
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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CDHitDiversity

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a ProteinTree as input
This must already have a multiple alignment run on it. It uses that alignment
as input create a HMMER HMM profile

input_id/parameters format eg: "{'gene_tree_id'=>1234}"
    gene_tree_id : use 'id' to fetch a cluster from the ProteinTree

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CDHitDiversity;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);

use base ( 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadModels', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree' );

sub fetch_input {
    my $self = shift @_;

    #Data structure that holds all the members available on the database
    my @all_members;

    #Input fasta file with all the sequences
    my $worker_temp_directory = $self->worker_temp_directory;
    my $input_fasta_file      = "$worker_temp_directory/all_sequences.fasta";
    open my $seq_fh, ">$input_fasta_file" || die "Could not open file: $worker_temp_directory/all_sequences.fasta";

    #Fetching all sequences:
    my $get_all_seqs_sql = "SELECT seq_member_id, sequence FROM seq_member JOIN sequence USING(sequence_id)";
    my $sth = $self->compara_dba->dbc->prepare( $get_all_seqs_sql, { 'mysql_use_result' => 1 } );
    $sth->execute();
    while ( my ( $seq_member_id, $seq ) = $sth->fetchrow() ) {
        print $seq_fh ">$seq_member_id\n$seq\n";
        push( @all_members, $seq_member_id );
    }

    close($seq_fh);

    $self->param( 'all_members',      \@all_members );
    $self->param( 'input_fasta_file', $input_fasta_file );
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs cdhit
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift @_;
    $self->_run_cdhit;
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   ................... 
    Returns :   none
    Args    :   none

=cut

sub write_output {
    my $self = shift @_;

	print "INSERTING" if $self->debug;
    bulk_insert($self->compara_dba->dbc, 'seq_member_projection', $self->param('seq_projections'), ['source_seq_member_id', 'target_seq_member_id', 'identity'], 'INSERT IGNORE');
}

##########################################
#
# internal methods
#
##########################################

sub _run_cdhit {
    my $self = shift;
    $self->require_executable('cdhit_exe');

    #Required parameters
    my $cdhit_exe         = $self->param_required('cdhit_exe');
    my $cdhit_threshold   = $self->param_required('cdhit_identity_threshold');
    my $cdhit_mem         = $self->param_required('cdhit_memory_in_mb');
    my $cdhit_num_threads = $self->param_required('cdhit_num_threads');
    my $input_file        = $self->param('input_fasta_file');


    unless ( defined $self->param('cluster_file')) {
    
        #Run CDHit:
        my $sequences_to_keep_file = $self->worker_temp_directory . "/new_fasta.fasta";
        my $cmd = "$cdhit_exe -i $input_file -o $sequences_to_keep_file -c $cdhit_threshold -M $cdhit_mem -T $cdhit_num_threads";
        print "CDHit COMMAND LINE:$cmd\n" if $self->debug;
    
        #Die in case of any problems with CDHit.
        system($cmd) == 0 or die "Error while running CDHit command: $cmd";
    
        my $cluster_file = $self->worker_temp_directory . "/new_fasta.fasta.clstr";
        $self->param( 'cluster_file',  $cluster_file  );
    }
    
    die "Problem finding cd-hit output: " . $self->param('cluster_file') . "\n"  unless ( -e $self->param('cluster_file') );
    
    my $clusters = $self->parse_clusters; # prepare clusters for seq_member_projection table


    #List of sequences to include. Sequences that are in the CDHit output:
    if ( scalar( @{$clusters} ) == scalar( @{ $self->param('all_members') } ) ) {
        $self->dataflow_output_id(undef, 2);
        $self->input_job->autoflow(0);
        $self->complete_early("CDHit did not exclude any members.");
    }
} ## end sub _run_cdhit


sub parse_clusters {
    my $self = shift;

    my $cluster_file = $self->param_required('cluster_file');
    open my $cluster_fh, $cluster_file || die "Could not open CDHit cluster file";
    
    my @seq_projections;
    my @this_cluster;
    my $c = 1;
    print "Rading cluster file\n";
    while ( my $line = <$cluster_fh> ) {
        chomp $line;

        if ( $line =~ m/^>/ ) { # new cluster start
            if ( @this_cluster ) { 
                push( @seq_projections, @{ $self->_cluster_to_seq_projection( \@this_cluster ) } );
                @this_cluster = ();
            }
        } elsif ( $line =~ m/^[0-9]/ ) { # add to current cluster
            my @parts = split( ',', $line );
            push( @this_cluster, $parts[1] );
        }
        $c++;
    }
    close($cluster_fh);

    # resulting cluster
    push( @seq_projections, @{ $self->_cluster_to_seq_projection( \@this_cluster ) } );

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

    my @projection_arr;

    foreach my $pro (@projection) {
        push(@projection_arr, [ $pro->{'source_seq_member_id'}, $pro->{'target_seq_member_id'}, $pro->{'identity'} ]);
    }

    return \@projection_arr;
}

1;
