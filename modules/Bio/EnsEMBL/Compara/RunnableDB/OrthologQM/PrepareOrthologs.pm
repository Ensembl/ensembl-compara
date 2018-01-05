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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs

=head1 SYNOPSIS

    Given two genome_db IDs, fetch and fan out all orthologs that they share.
    If a previous release database is supplied, only the new/updated orthologs will be dataflowed

=head1 DESCRIPTION

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs -input_ids "{ species1_id => 150, species2_id => 125 }"

    Inputs:
        species1_id       genome_db_id
        species2_id       another genome_db_id
        alt_homology_db   for use as part of a pipeline - specify an alternate location to read homologies from
        previous_rel_db   database URL for previous release - when defined, the runnable will only dataflow homologies that have changed since previous release

    Outputs:
        dataflows homology dbID and start/end positions in a fan

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Description: Pull orthologs for species 1 and 2 from given database. compara_db will be used unless 
    alt_homology_db is defined. Homologies may be reused from previous releases by providing the URL in
    the previous_rel_db param

=cut

sub fetch_input {
    my $self = shift;

    my $species1_id = $self->param_required('species1_id');
    my $species2_id = $self->param_required('species2_id');

    my ($dba, $db_url);
    if ( $self->param('alt_homology_db') ) { 
        #$db_url = $self->param('alt_homology_db');
        $dba = $self->get_cached_compara_dba('alt_homology_db');
    }
    else {
        #$db_url = $self->param('compara_db');
        $dba = $self->compara_dba;
    }
    #$self->param('current_db_url', $db_url);
    $self->param('current_dba', $dba);

    my $mlss_adaptor = $dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES', [$species1_id, $species2_id]);
    $self->param('mlss_id', $mlss->dbID);

    my $current_homo_adaptor = $dba->get_HomologyAdaptor;
    my $current_homologs = $current_homo_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);
    
    if ( defined $self->param('previous_rel_db') ){ # reuse is on
        my $nonreuse_homologs = $self->_reusable_homologies( $dba, $self->get_cached_compara_dba('previous_rel_db'), $current_homologs, $mlss->dbID );
        $self->param( 'orth_objects', $nonreuse_homologs );
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
    
    # my $db = defined $self->db ? $self->db : $self->compara_dba; # mostly for unit test purposes
    my $db = $self->compara_dba;
    my $sth = $db->dbc->prepare($sql);

    my @orth_objects = sort {$a->dbID <=> $b->dbID} @{ $self->param('orth_objects') };
    while ( my $orth = shift( @orth_objects ) ) {
        my @gene_members = @{ $orth->get_all_GeneMembers() };
        my (%orth_ranges, @orth_dnafrags, %orth_exons);
        my $has_transcript_edits = 0;
        foreach my $gm ( @gene_members ){
            $has_transcript_edits ||= $gm->get_canonical_SeqMember->has_transcript_edits;

            push( @orth_dnafrags, { id => $gm->dnafrag_id, start => $gm->dnafrag_start, end => $gm->dnafrag_end } );
            $orth_ranges{$gm->genome_db_id} = [ $gm->dnafrag_start, $gm->dnafrag_end ];
            
            # get exon locations
            $sth->execute( $gm->dbID );
            my $ex_bounds = $sth->fetchall_arrayref([]);
            $orth_exons{$gm->genome_db_id} = $ex_bounds;
        }

        # When there are transcript edits, the coordinates cannot be
        # trusted, so it's better to skip the pair
        next if $has_transcript_edits;

        push( @orth_info, { 
            id       => $orth->dbID, 
            orth_ranges   => \%orth_ranges, 
            orth_dnafrags => [sort {$a->{id} <=> $b->{id}} @orth_dnafrags],
            exons         => \%orth_exons,
            # may need to add aln_mlss_ids in here!!? 
            # depends next runnable can see the param through the stack..
        } );
        $c++;
        # last if $c >= 10;
    }
    $self->param( 'orth_info', \@orth_info );
}

=head2 write_output

    Description: send data to correct dataflow branch!

=cut

sub write_output {
    my $self = shift;

    my $batch_size = $self->param_required('orth_batch_size');

    # split list of orths into chunks/batches
    my @orth_list = @{ $self->param('orth_info') };
    my (@batched_orths, @spliced);
    push @spliced, [ splice @orth_list, 0, $batch_size ] while @orth_list;
    foreach my $batch ( @spliced ){
        push( @batched_orths, { orth_batch => $batch } );
    }

    $self->dataflow_output_id( \@batched_orths, 2 ); # to calculate_coverage

    # split list of reusable scores into chunks/batches
    if ( defined $self->param('previous_rel_db') ){ # reuse is on
        print "about to start batching up reusables...\n";
        my @reuse_list = @{ $self->param('reusables') };
        print scalar(@reuse_list) . " reusable entries...\n";

        my (@reuse_dataflow, @spliced_reuse);
        push @spliced_reuse, [ splice @reuse_list, 0, $batch_size ] while @reuse_list;
        foreach my $batch ( @spliced_reuse ){
            push( @reuse_dataflow, { reuse_list => $batch } );
        }

        $self->dataflow_output_id( \@reuse_dataflow, 3 ); # to reuse_wga_score
    }

    # flow reusable homologies to have their score copied
    # if ( defined $self->param('reusable_homologies') ){
    #     my $current_dba = $self->param('current_dba');
    #     my $dataflow = {
    #         previous_rel_db => $self->param('previous_rel_db'),
    #         current_db      => $self->param('current_db_url'),
    #         homology_ids    => $self->param('reusable_homologies'),
    #     };
    #     $self->dataflow_output_id( $dataflow, 1 ); # to copy_reusable_scores
    # }
}

=head2 _reuse_homologies

    Check through list of homologs and check if they can be reused.
    wga_coverage scores are copied from the previous_rel_db to the current $dba if they meet 2 requirements:
        1. an ID mapping exists for the homology
        2. a score exists in the previous_rel_db
    Homologs not meeting these criteria are returned as an arrayref

=cut

sub _reusable_homologies {
    my ( $self, $dba, $previous_compara_dba, $current_homologs, $mlss_id ) = @_;

    my $previous_homo_adaptor = $previous_compara_dba->get_HomologyAdaptor;

    # first, find reusable homologies based on id mapping table
    my $sql = "SELECT curr_release_homology_id, prev_release_homology_id FROM homology_id_mapping WHERE mlss_id = ?";

    my $sth = $dba->dbc->prepare($sql);
    $sth->execute( $mlss_id );
    my $reuse_homologs = $sth->fetchall_hashref('curr_release_homology_id');

    # next, split the homologies into reusable and non-reusable (new)
    # copy score of reusable homs to new db
    my ( @reusables, @dont_reuse );
    my %old_id_2_new_hom;
    foreach my $h ( @{ $current_homologs } ) {
        my $h_id = $h->dbID;
        my $homolog_map = $reuse_homologs->{ $h_id };
        if ( defined $homolog_map ){
            $old_id_2_new_hom{ $homolog_map->{prev_release_homology_id} } = $h;
        }
        else {
            push( @dont_reuse, $h );
        }
    }
    $sth->finish;

    my $previous_homologies = $previous_homo_adaptor->fetch_all_by_dbID_list([keys %old_id_2_new_hom]);
    # check if wga_coverage has already been calculated for these homologies
    foreach my $previous_homolog (@$previous_homologies) {
        next unless defined $previous_homolog->wga_coverage; # score doesn't exist
        push( @reusables, { homology_id => $old_id_2_new_hom{$previous_homolog->dbID}->dbID, prev_wga_score => $previous_homolog->wga_coverage } );
        delete $old_id_2_new_hom{$previous_homolog->dbID};
    }
    # There is no score for these homologies
    push @dont_reuse, values %old_id_2_new_hom;

    $self->param('reusables', \@reusables);

    # return nonreuable homologies to the pipeline
    return \@dont_reuse;
}

1;
