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

use Bio::EnsEMBL::Compara::Utils::Preloader;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Description: Pull orthologs for species 1 and 2 from given flatfile.
    Homologies may be reused from previous releases by providing the URL in
    the previous_rel_db param

=cut

sub fetch_input {
    my $self = shift;

    my $species1_id = $self->param_required('species1_id');
    my $species2_id = $self->param_required('species2_id');
    my $dba = $self->param('alt_homology_db') ? $self->get_cached_compara_dba('alt_homology_db') : $self->compara_dba;
    $self->param('current_dba', $dba);

    # set up flatfile for reading
    my $homology_flatfile = $self->param_required('homology_flatfile');
    open( my $hom_handle, '<', $homology_flatfile ) or die "Cannot read $homology_flatfile";
    my $header = <$hom_handle>;
    my @head_cols = split(/\s+/, $header);
    my @current_homologs;
    while( my $line = <$hom_handle> ) {
        my $row = map_row_to_header( $line, \@head_cols );
        push @current_homologs, $row;
    }
    
    if ( defined $self->param('previous_rel_db') ){ # reuse is on
        my $nonreuse_homologs = $self->_reusable_homologies( $dba, $self->get_cached_compara_dba('previous_rel_db'), \@current_homologs );
        $self->param( 'orth_objects', $nonreuse_homologs );
    }
    else {
        $self->param( 'orth_objects', \@current_homologs );
    }

    # Load member info
    # seq_member.has_transcript_edits
    # gene_member.dnafrag_id, gene_member.dnafrag_start, gene_member.dnafrag_end
    $self->_load_member_info;

    # Preload the exon boundaries for the whole genomes even though some of the members will be reused
    my $sql = 'SELECT gene_member_id, eb.dnafrag_start, eb.dnafrag_end FROM exon_boundaries eb JOIN gene_member USING (gene_member_id) WHERE genome_db_id IN (?,?)';
    my %exon_boundaries;
    my $sth = $dba->dbc->prepare($sql);
    $sth->execute($species1_id, $species2_id);
    while (my $row = $sth->fetchrow_arrayref()) {
        my ($gene_member_id, $dnafrag_start, $dnafrag_end) = @$row;
        push @{ $exon_boundaries{$gene_member_id} }, [$dnafrag_start, $dnafrag_end];
    }
    $sth->finish;
    $self->param('exon_boundaries', \%exon_boundaries);

    # disconnect from compara_db
    $dba->dbc->disconnect_if_idle();
}

=head2 run

    Description: parse Bio::EnsEMBL::Compara::Homology objects to get start and end positions
    of genes

=cut

sub run {
    my $self = shift;

    $self->dbc->disconnect_if_idle() if $self->dbc;

    my @orth_info;
    my $c = 0;

    my $exon_boundaries = $self->param('exon_boundaries');
    my $member_info     = $self->param('member_info');

    my @orth_objects = sort {$a->{homology_id} <=> $b->{homology_id}} @{ $self->param('orth_objects') };
    while ( my $orth = shift( @orth_objects ) ) {
        my @seq_member_ids = ($orth->{seq_member_id}, $orth->{hom_seq_member_id});
        my (%orth_ranges, @orth_dnafrags, %orth_exons);
        my $has_transcript_edits = 0;
        foreach my $sm_id ( @seq_member_ids ){
            # $has_transcript_edits ||= $sm->has_transcript_edits;
            $has_transcript_edits ||= $member_info->{"seq_member_$sm_id"};
        }
        # When there are transcript edits, the coordinates cannot be
        # trusted, so it's better to skip the pair
        next if $has_transcript_edits;
        
        my @gene_member_ids = ([$orth->{gene_member_id}, $orth->{genome_db_id}], [$orth->{hom_gene_member_id}, $orth->{hom_genome_db_id}]);
        foreach my $gm ( @gene_member_ids ) {
            my ( $gm_id, $gdb_id ) = @$gm;
            push( @orth_dnafrags, { 
                id => $member_info->{"gene_member_$gm_id"}->{dnafrag_id}, 
                start => $member_info->{"gene_member_$gm_id"}->{dnafrag_start}, 
                end => $member_info->{"gene_member_$gm_id"}->{dnafrag_end} 
            } );
            $orth_ranges{$gdb_id} = [ $member_info->{"gene_member_$gm_id"}->{dnafrag_start}, $member_info->{"gene_member_$gm_id"}->{dnafrag_end} ];
            
            # get exon locations
            $orth_exons{$gdb_id} = $exon_boundaries->{$gm_id};
        }

        

        push( @orth_info, { 
            id       => $orth->{homology_id}, 
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
}

=head2 _reuse_homologies

    Check through list of homologs and check if they can be reused.
    wga_coverage scores are copied from the previous_rel_db to the current $dba if they meet 2 requirements:
        1. an ID mapping exists for the homology
        2. a score exists in the previous_rel_db
    Homologs not meeting these criteria are returned as an arrayref

=cut

sub _reusable_homologies {
    my ( $self, $dba, $previous_compara_dba, $current_homologs ) = @_;

    my $previous_homo_adaptor = $previous_compara_dba->get_HomologyAdaptor;

    # first, find reusable homologies based on id mapping file
    my $hom_map_file = $self->param_required('homology_mapping_flatfile');
    my $reuse_homologs;
    open( my $hmfh, '<', $hom_map_file ) or die "Cannot open $hom_map_file for reading";
    my $header = <$hmfh>;
    my @head_cols = split(/\s+/, $header);
    while ( my $line = <$hmfh> ) {
        my $row = map_row_to_header( $line, \@head_cols );
        $reuse_homologs->{$row->{curr_release_homology_id}} = $row->{prev_release_homology_id};
    }

    # now, we split the homologies into reusable and non-reusable (new)
    my ( @reusables, @dont_reuse );
    my %old_id_2_new_hom;
    foreach my $h ( @$current_homologs ) {
        my $h_id = $h->{homology_id};
        my $prev_rel_id = $reuse_homologs->{ $h_id };
        if ( defined $prev_rel_id ){
            $old_id_2_new_hom{ $prev_rel_id } = $h;
        }
        else {
            push( @dont_reuse, $h );
        }
    }

    my $previous_homologies = $previous_homo_adaptor->fetch_all_by_dbID_list([keys %old_id_2_new_hom]);
    # check if wga_coverage has already been calculated for these homologies
    foreach my $previous_homolog (@$previous_homologies) {
        next unless defined $previous_homolog->wga_coverage; # score doesn't exist
        push( @reusables, { homology_id => $old_id_2_new_hom{$previous_homolog->dbID}->{homology_id}, prev_wga_score => $previous_homolog->wga_coverage } );
        delete $old_id_2_new_hom{$previous_homolog->dbID};
    }
    # There is no score for these homologies
    push @dont_reuse, values %old_id_2_new_hom;

    $self->param('reusables', \@reusables);

    # return nonreuable homologies to the pipeline
    return \@dont_reuse;
}

=head2 _load_member_info

Load info for seq_members and gene_memmbers that are members of a homology
- seq_member.has_transcript_edits
- gene_member.dnafrag_id, gene_member.dnafrag_start, gene_member.dnafrag_end
Store it in a param 'member_info'

=cut

sub _load_member_info {
    my $self = shift;
    
    my $dba = $self->param('current_dba');
    my $sm_sql = 'SELECT has_transcript_edits FROM seq_member WHERE seq_member_id = ?';
    my $sm_sth = $dba->dbc->prepare($sm_sql);
    my $gm_sql = 'SELECT dnafrag_id, dnafrag_start, dnafrag_end FROM gene_member WHERE gene_member_id = ?';
    my $gm_sth = $dba->dbc->prepare($gm_sql);

    my $homologies = $self->param('orth_objects');
    my $member_info;
    foreach my $hom ( @$homologies ) {
        my ( $sm_id_1, $gm_id_1, $sm_id_2, $gm_id_2 ) = ( $hom->{seq_member_id}, $hom->{gene_member_id}, $hom->{hom_seq_member_id}, $hom->{hom_gene_member_id} );

        $sm_sth->execute($sm_id_1);
        $member_info->{"seq_member_$sm_id_1"} = $sm_sth->fetchrow_arrayref->[0];
        $sm_sth->execute($sm_id_2);
        $member_info->{"seq_member_$sm_id_2"} = $sm_sth->fetchrow_arrayref->[0];
        
        $gm_sth->execute($gm_id_1);
        $member_info->{"gene_member_$gm_id_1"} = $gm_sth->fetchrow_hashref;
        $gm_sth->execute($gm_id_2);
        $member_info->{"gene_member_$gm_id_2"} = $gm_sth->fetchrow_hashref;
    }
    
    $self->param('member_info', $member_info);
}

1;
