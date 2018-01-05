
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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassify

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::ComputeHmmThresholds;

use strict;
use warnings;

use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my ($self) = @_;
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs ....  http://blog.nextgenetics.net/?e=84
    Returns :   none
    Args    :   none

=cut

sub run {
    my ($self) = @_;

    #Keep in memory all the root_id_list in order to use it on write_output. Just in case a particular ID is missing in either of the final thresholds hashes.
    #In addition to have it all in a single loop, avoiding fetching the tree twice.
    my %root_id_list;

    my %trusted_cutoff;
    my %noise_cutoff;

    my $get_scores_sql = "SELECT root_id, seq_member_id, score FROM hmm_thresholding ORDER BY root_id";
    #my $get_scores_sql = "SELECT root_id, seq_member_id, evalue FROM hmm_thresholding FORCE INDEX (root_id) ORDER BY root_id;";
    my $sth_scores     = $self->compara_dba->dbc->prepare($get_scores_sql, { 'mysql_use_result' => 1 } );
    $sth_scores->execute();

    my $last_root_id = "";
    my %scores      = ();

    #The mysql object can only have one active query or result on it at a time
    # Otherwise it will generate a "Commands out of sync" error.
    my $dbc_copy = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $self->compara_dba->dbc);
    my $seqs_in_tree_sql = "SELECT seq_member_id FROM gene_tree_root JOIN gene_tree_node USING (root_id) WHERE tree_type = 'tree' AND clusterset_id = 'filter_level_4' AND root_id = ? AND seq_member_id IS NOT NULL";

    # Prepare query outside the while loop, in order to improve efficiency.
    my $sth_seqs = $dbc_copy->prepare($seqs_in_tree_sql);

    while ( my ( $root_id, $seq_member_id, $score ) = $sth_scores->fetchrow() ) {

        if ( ( $root_id ne $last_root_id ) && ( $last_root_id ne "" ) ) {
            $root_id_list{$root_id} = 1;
            $self->_compute_thresholds( $last_root_id, \%scores, \%noise_cutoff, \%trusted_cutoff, $sth_seqs );
            undef %scores;
            %scores = ();
        }
        $scores{$seq_member_id} = $score;
        $last_root_id = $root_id;

    }

    $self->param( 'root_id_list',   \%root_id_list );
    $self->param( 'noise_cutoff',   \%noise_cutoff );
    $self->param( 'trusted_cutoff', \%trusted_cutoff );

} ## end sub run

sub write_output {
    my ($self) = @_;

    foreach my $root_id ( keys %{ $self->param('root_id_list') } ) {

        my $gene_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_root_id($root_id) || die "Could not fetch gene_tree:'$root_id'";

        if ( defined( $self->param('noise_cutoff')->{$root_id} ) ) {
            $gene_tree->store_tag( 'noise_cutoff', $self->param('noise_cutoff')->{$root_id} );
        }

        if ( defined( $self->param('trusted_cutoff')->{$root_id} ) ) {
            $gene_tree->store_tag( 'trusted_cutoff', $self->param('trusted_cutoff')->{$root_id} );
        }

        #Releasing the tree to save RAM
        $gene_tree->release_tree;
    }
}

##########################################
#
# internal methods
#
##########################################

sub _compute_thresholds {
    my ( $self, $root_id, $scores_ref, $noise_cutoff_ref, $trusted_cutoff_ref, $sth_seqs_ref ) = @_;

    $sth_seqs_ref->execute($root_id);

    my %seqs_in_tree = ();

    # Compute trusted cutoff:

    # Get all sequences within the HMM alignment:
    while ( my $seq_member_id = $sth_seqs_ref->fetchrow() ) {
        my $score = $scores_ref->{$seq_member_id};
        if ( defined($score) ) {
            $seqs_in_tree{$seq_member_id} = 1;
            if ( defined( $trusted_cutoff_ref->{$root_id} ) ) {
                $trusted_cutoff_ref->{$root_id} = $score if ( $score < $trusted_cutoff_ref->{$root_id} );
            }
            else {
                $trusted_cutoff_ref->{$root_id} = $score;
            }
        }
    }

    #Compute the Noise cutoff:
    my @tmp_seqs_in_tree = keys(%seqs_in_tree);
    my @tmp_all_hits     = keys( %{$scores_ref} );
    my %tmp_seqs_not_in_tree;
    @tmp_seqs_not_in_tree{@tmp_all_hits} = undef;
    delete @tmp_seqs_not_in_tree{@tmp_seqs_in_tree};

    foreach my $seq ( keys %tmp_seqs_not_in_tree ) {
        my $score = $scores_ref->{$seq};
        if ( defined($score) ) {
            if ( defined( $noise_cutoff_ref->{$root_id} ) ) {
                $noise_cutoff_ref->{$root_id} = $score if ( $score > $noise_cutoff_ref->{$root_id} );
            }
            else {
                $noise_cutoff_ref->{$root_id} = $score;
            }
        }
    }

    print ">>>" . $root_id . "\n"                                        if ( $self->debug );
    print "seqs_in_tree:\t" . scalar(@tmp_seqs_in_tree) . "\n"           if ( $self->debug );
    print "all_hits:\t" . scalar(@tmp_all_hits) . "\n"                   if ( $self->debug );
    print "not_in_tree:\t" . scalar( keys %tmp_seqs_not_in_tree ) . "\n" if ( $self->debug );

    print "\tnoise_cutoff:\t" . $noise_cutoff_ref->{$root_id} . "\n"     if ( $self->debug );
    print "\ttrusted_cutoff:\t" . $trusted_cutoff_ref->{$root_id} . "\n" if ( $self->debug );

} ## end sub _compute_thresholds

1;
