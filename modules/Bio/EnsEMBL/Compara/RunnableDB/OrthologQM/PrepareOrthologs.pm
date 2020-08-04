=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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
    If a previous wga file is supplied, only the new/updated orthologs will be dataflowed

=head1 DESCRIPTION

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs -input_ids "{ species1_id => 150, species2_id => 125 }"

    Inputs:
        species1_id       genome_db_id
        species2_id       another genome_db_id
        alt_homology_db   for use as part of a pipeline - specify an alternate location to read homologies from
        previous_wga_file file containing scores from previous release - when defined, the runnable will only dataflow homologies that have changed since previous release

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
    Homologies may be reused from previous releases by providing the file in
    the previous_wga_file param

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

    if ( -e $self->param('previous_wga_file') ){ # reuse is on
        my $nonreuse_homologs = $self->_nonreusable_homologies( \@current_homologs );
        my $num_nonreuse = scalar @$nonreuse_homologs;
        my $num_homologs = scalar @current_homologs;
        $self->warning(
            sprintf("%d/%d reusable homologies for mlss_id %d", (
                ($num_homologs-$num_nonreuse),
                $num_homologs,
                $self->param_required('orth_mlss_id')
            ))
        );
        $self->param( 'orth_objects', $nonreuse_homologs );
    }
    else {
        $self->param( 'orth_objects', \@current_homologs );
    }

    # Load member info
    # seq_member.has_transcript_edits
    $self->_load_seq_member_info;

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
    my $member_info = $self->param('member_info');

    my @orth_objects = sort {$a->{homology_id} cmp $b->{homology_id}} @{ $self->param('orth_objects') };
    while ( my $orth = shift( @orth_objects ) ) {
        my @seq_member_ids = ($orth->{seq_member_id}, $orth->{homology_seq_member_id});
        my $has_transcript_edits = 0;
        foreach my $sm_id ( @seq_member_ids ){
            $has_transcript_edits ||= $member_info->{"seq_member_$sm_id"};
        }
        # When there are transcript edits, the coordinates cannot be
        # trusted, so it's better to skip the pair
        next if $has_transcript_edits;
        
        my @gene_member_ids = ([$orth->{gene_member_id}, $orth->{genome_db_id}], [$orth->{homology_gene_member_id}, $orth->{homology_genome_db_id}]);
        push( @orth_info, { 
            id            => $orth->{homology_id},
            gene_members  => \@gene_member_ids,
        } );
    }
    $self->param( 'orth_info', \@orth_info );
}

=head2 write_output

    Description: send data to correct dataflow branch!

=cut

sub write_output {
    my $self = shift;

    if ( $self->param('reuse') ){
        $self->dataflow_output_id( {orth_mlss_id => $self->param('orth_mlss_id')}, 3 ); # to reuse_wga_score
    }

    $self->dataflow_output_id( { orth_info => $self->param('orth_info'), aln_mlss_ids => $self->param('aln_mlss_ids') }, 2 ); # to calculate_coverage

    # Add MLSS tag to indicate that the WGA flatfile should be found and loaded when importing the homology
    my $mlss_id = $self->param('orth_mlss_id');
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    $mlss->store_tag('wga_expected', 1);
}

=head2 _nonreusable_homologies

    Check through list of homologs and check if they can be reused.
    wga_coverage scores are copied from the previous_wga_file to the current file if an ID mapping exists for the homology
    Homologs not meeting these criteria are returned as an arrayref

=cut

sub _nonreusable_homologies {
    my ( $self, $current_homologs ) = @_;

    # if new alignments have been run, do not reuse
    if ( $self->param_required('new_alignment') ) {
        $self->param('reuse', 0);
        return $current_homologs;
    }

    # otherwise, check for reusable homologies based on id mapping file
    my $hom_map_file = $self->param_required('homology_mapping_flatfile');
    # can't reuse anything if the file doesn't exist..
    unless ( -e  $hom_map_file ) {
        $self->warning("id mapping file not found - no reuse possible");
        $self->param('reuse', 0);
        return $current_homologs;
    }

    my $reuse_homologs;
    open( my $hmfh, '<', $hom_map_file ) or die "Cannot open $hom_map_file for reading";
    my $header = <$hmfh>;
    my @head_cols = split(/\s+/, $header);
    while ( my $line = <$hmfh> ) {
        my $row = map_row_to_header( $line, \@head_cols );
        $reuse_homologs->{$row->{curr_release_homology_id}} = $row->{prev_release_homology_id};
    }

    # gather the non-reusable homologies
    my @dont_reuse;
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

    $self->param('reuse', 1);

    # return nonreuable homologies to the pipeline
    return \@dont_reuse;
}

=head2 _load_seq_member_info

Load info for seq_members and gene_memmbers that are members of a homology
- seq_member.has_transcript_edits
Store it in a param 'member_info'

=cut

sub _load_seq_member_info {
    my $self = shift;

    my $dba = $self->param('current_dba');
    my $sm_sql = 'SELECT has_transcript_edits FROM seq_member WHERE seq_member_id = ?';
    my $sm_sth = $dba->dbc->prepare($sm_sql);

    my $homologies = $self->param('orth_objects');
    my $member_info;
    foreach my $hom ( @$homologies ) {
        my ( $sm_id_1, $gm_id_1, $sm_id_2, $gm_id_2 ) = ( $hom->{seq_member_id}, $hom->{gene_member_id}, $hom->{homology_seq_member_id}, $hom->{homology_gene_member_id} );

        $sm_sth->execute($sm_id_1);
        $member_info->{"seq_member_$sm_id_1"} = $sm_sth->fetchrow_arrayref->[0];
        $sm_sth->execute($sm_id_2);
        $member_info->{"seq_member_$sm_id_2"} = $sm_sth->fetchrow_arrayref->[0];
    }

    $self->param('member_info', $member_info);
}

1;
