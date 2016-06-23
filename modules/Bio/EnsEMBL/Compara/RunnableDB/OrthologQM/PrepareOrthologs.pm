=pod

=head1 NAME
    
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs

=head1 SYNOPSIS

    Given two genome_db IDs, fetch and fan out all orthologs that they share.
    If a previous release database is supplied, only the new/updated orthologs will be dataflown

=head1 DESCRIPTION

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs -input_ids "{ species1_id => 150, species2_id => 125 }"

    Inputs:
        species1_id     genome_db_id
        species2_id     another genome_db_id
        alt_homology_db for use as part of a pipeline - specify an alternate location to read homologies from
        previous_rel_db     database URL for previous release - when defined, the runnable will only dataflow homologies that have changed since previous release

    Outputs:
        dataflows homology dbID and start/end positions in a fan
=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;

=head2 fetch_input

    Description: pull orthologs for species 1 and 2 from EnsEMBL and save as param

=cut

sub fetch_input {
    my $self = shift;

    my $species1_id = $self->param_required('species1_id');
    my $species2_id = $self->param_required('species2_id');

    my $dba;
    if ( $self->param('alt_homology_db') ) { 
        $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($self->param('alt_homology_db')); 
    }
    else { $dba = $self->compara_dba }

    my $mlss_adaptor = $dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES', [$species1_id, $species2_id]);

    my $current_homo_adaptor = $dba->get_HomologyAdaptor;
    my $current_homologs     = $current_homo_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);

    my $previous_db = $self->param('previous_rel_db');
    if ( defined $previous_db ){
        my $previous_compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($previous_db);
        my $previous_homo_adaptor = $previous_compara_dba->get_HomologyAdaptor;
        my $previous_homologs     = $previous_homo_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);

        # print "Found " . scalar(@{$current_homologs}) . " in current db\n";
        # print "Found " . scalar(@{$previous_homologs}) . " in prev db\n";

        my ($updated_orthologs, $reuse_orthologs) = $self->_updated_orthologs( $current_homologs, $previous_homologs );

        # print "Found " . scalar(@{$updated_orthologs}) . " changes\n";
        # foreach my $uo ( @{$updated_orthologs} ) {
        #   print $uo->dbID . "\n";
        # }

        #my $exons = $self->_find_exons( $updated_orthologs );
        $self->_copy_reused_orthologs( $reuse_orthologs, $current_homo_adaptor, $previous_homo_adaptor );
        $self->param( 'orth_objects', $updated_orthologs );
    }
    else {
        $self->param( 'orth_objects', $current_homologs );
    }

    # disconnect from compara_db
    $dba->dbc->disconnect_if_idle();
}

=head2 run

    Description: parse Bio::EnsEMBL::Compara::Homology objects to get start and end positions
    of genes

=cut

sub run {
    my $self = shift;

    my @orth_info;
    my $c = 0;

    # prepare SQL statement to fetch the exon boundaries for each gene_members
    my $sql = 'SELECT dnafrag_start, dnafrag_end FROM exon_boundaries WHERE gene_member_id = ?';
    my $sth = $self->db->dbc->prepare($sql);

    my @orth_objects = sort {$a->dbID <=> $b->dbID} @{ $self->param('orth_objects') };
    while ( my $orth = shift( @orth_objects ) ) {
        my @gene_members = @{ $orth->get_all_GeneMembers() };
        my (%orth_ranges, @orth_dnafrags, %orth_exons);
        foreach my $gm ( @gene_members ){
            push( @orth_dnafrags, { id => $gm->dnafrag_id, start => $gm->dnafrag_start, end => $gm->dnafrag_end } );
            $orth_ranges{$gm->genome_db_id} = [ $gm->dnafrag_start, $gm->dnafrag_end ];
            
            # get exon locations
            $sth->execute( $gm->dbID );
            my $ex_bounds = $sth->fetchall_arrayref([]);
            $orth_exons{$gm->genome_db_id} = $ex_bounds;
        }

        push( @orth_info, { 
            id       => $orth->dbID, 
            orth_ranges   => \%orth_ranges, 
            orth_dnafrags => [sort {$a->{id} <=> $b->{id}} @orth_dnafrags],
            exons         => \%orth_exons,
            # may need to add aln_mlss_ids in here!!? 
            # depends next runnable can see the param through the stack..
        } );
        # $c++;
        # last if $c >= 100;
    }
    # print Dumper \@orth_info;
    $self->param( 'orth_info', \@orth_info );
}

=head2 write_output

    Description: send data to correct dataflow branch!

=cut

sub write_output {
    my $self = shift;

    my (@batched_orths, @current_batch);
    foreach my $o ( @{ $self->param('orth_info') } ) {
        if ( scalar @current_batch > $self->param('orth_batch_size') ) {
            my @batch_copy = @current_batch; # need to copy as arrayref will be updated again later
            push( @batched_orths, {'orth_batch' => \@batch_copy} );
            @current_batch = ();
        }
        else {
            push( @current_batch, $o );
        }
    }
    $self->dataflow_output_id( \@batched_orths, 2 ); # to calculate_coverage aka prepare_alignment + combine_coverage..
}

=head2 _updated_orthologs

    Checks whether the Homology object has been updated since the last release
    Do not recalculate if it is unchanged

=cut

sub _updated_orthologs {
    my ( $self, $current_homologs, $previous_homologs, $homology_adaptor ) = @_;

    # reformat data to hashes
    my %current_hh  = %{ $self->_hash_homologs( $current_homologs ) };
    my %previous_hh = %{ $self->_hash_homologs( $previous_homologs ) };

    my (@new_homologs, @old_homologs);
    foreach my $h ( @{ $current_homologs } ){
        my $curr_id = $h->dbID;

        if ( !defined $previous_hh{$curr_id}->{'score'} || (!defined $previous_hh{$curr_id}->{'members'}) || ($current_hh{$curr_id}->{'members'}->[0] != $previous_hh{$curr_id}->{'members'}->[0] || $current_hh{$curr_id}->{'members'}->[1] != $previous_hh{$curr_id}->{'members'}->[1])  ) {
            push( @new_homologs, $h );
        }
        else {
            push( @old_homologs, $h );
        }
    }

    return (\@new_homologs, \@old_homologs);
}

=head2 _hash_homologs

    Reformat homology data

=cut

sub _hash_homologs {
    my ( $self, $hlist ) = @_;

    my %hhash;
    foreach my $h ( @{ $hlist } ) {
        my @members;
        foreach my $gene ( @{ $h->get_all_GeneMembers() } ) {
            push( @members, $gene->dbID );
        }
        my @sorted_members = sort {$a <=> $b} @members;

        $hhash{ $h->dbID }->{'members'} = \@sorted_members;
        $hhash{ $h->dbID }->{'score'} = $h->wga_coverage;
    }
    return \%hhash;
}

=head2 _copy_reused_orthologs

    Takes list of orthologs and homology adaptors for current and prev releases
    Copies wga_coverage score from prev release to current

=cut

sub _copy_reused_orthologs {
    my ( $self, $orths, $current_homo_adaptor, $previous_homo_adaptor ) = @_;

    foreach my $o ( @{ $orths } ) {
        my $orth_id = $o->dbID;
        my $prev_o  = $previous_homo_adaptor->fetch_by_dbID($orth_id);
        my $prev_score = $prev_o->wga_coverage;
        $current_homo_adaptor->update_wga_coverage( $orth_id, $prev_score ); 
    }  
}

sub _fetch_exons_by_gene_member {
    my ( $self, $gm ) = @_;

    my $sql = 'SELECT dnafrag_start, dnafrag_end FROM exon_ranges WHERE gene_member_id = ?';
    my $sth = $self->db->dbc->prepare($sql);

}

1;
