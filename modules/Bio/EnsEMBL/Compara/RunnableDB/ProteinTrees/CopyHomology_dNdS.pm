
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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CopyHomology_dNdS

=head1 DESCRIPTION

To summarize:
 - Check homology map
 - Compare alignments of mapped homologies
 - If alignments are identical, copy the dN/dS data from the previous release
 - If alignments are not identical, dataflow to Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Homology_dNdS

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CopyHomology_dNdS;

use strict;
use warnings;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);

use Statistics::Descriptive;

use Bio::Tools::Run::Phylo::PAML::Codeml;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return { 'group_size' => 500, };
}

sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');

    #my $curr_homology_adaptor = $self->compara_dba->get_HomologyAdaptor || die "Could not get current Adaptor";
    $self->param( 'curr_homology_adaptor', $self->compara_dba->get_HomologyAdaptor ) || die "Could not get current Adaptor";

    #Get previous and current Homology adaptors
    my $prev_dba = $self->get_cached_compara_dba('reuse_db');
    my $prev_homology_adaptor = $prev_dba->get_HomologyAdaptor || die "Could not get previous Adaptor";

    my $homology_ids = $self->param('homology_ids');

    my @prev_homology_ids;
    my @curr_homology_ids;

    #Build curr - prev mappings
    my %curr_homologies_map;
    my %prev_homologies_map;

    foreach my $h ( keys %{ $self->param('homology_ids') } ) {
        push( @prev_homology_ids, $self->param('homology_ids')->{$h} );
        push( @curr_homology_ids, $h );
    }

    #print Dumper @prev_homology_ids;
    my $sorted_prev_homologies;
    my $sorted_curr_homologies;
    my $prev_homologies = $prev_homology_adaptor->fetch_all_by_dbID_list( \@prev_homology_ids );
    my $curr_homologies = $self->param('curr_homology_adaptor')->fetch_all_by_dbID_list( \@curr_homology_ids );

    foreach my $prev_homology (@$prev_homologies) {
        $prev_homologies_map{ $prev_homology->dbID } = $prev_homology;
    }

    foreach my $curr_homology (@$curr_homologies) {
        $curr_homologies_map{ $curr_homology->dbID } = $curr_homology;
    }

    foreach my $prev_homology_id (@prev_homology_ids) {
        push( @$sorted_prev_homologies, $prev_homologies_map{$prev_homology_id} );
    }

    foreach my $curr_homology_id (@curr_homology_ids) {
        push( @$sorted_curr_homologies, $curr_homologies_map{$curr_homology_id} );
    }

    #Create previous and current object map, to be used by direct memory access.

    #MATEUS
    print "$prev_homology_ids[0]|$curr_homology_ids[0]\n";
    print $sorted_prev_homologies->[0]->dbID . "|" . $sorted_curr_homologies->[0]->dbID . "\n";
    print scalar(@prev_homology_ids) . "|" . scalar(@curr_homology_ids) . " => $mlss_id\n";
    print scalar(@$prev_homologies) . "|" . scalar(@$curr_homologies) . "\n";
    print scalar(@$sorted_prev_homologies) . "|" . scalar(@$sorted_curr_homologies) . "\n";

    #Preloading previous homologies
    my $sms_prev = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies( $prev_dba->get_AlignedMemberAdaptor, $prev_homologies );
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences( $prev_dba->get_SequenceAdaptor, undef, $sms_prev );
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences( $prev_dba->get_SequenceAdaptor, 'cds', $sms_prev );
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags( $prev_dba->get_DnaFragAdaptor, $sms_prev );

    #Preloading current homologies
    my $sms_curr = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies( $self->compara_dba->get_AlignedMemberAdaptor, $curr_homologies );
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences( $self->compara_dba->get_SequenceAdaptor, undef, $sms_curr );
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences( $self->compara_dba->get_SequenceAdaptor, 'cds', $sms_curr );
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags( $self->compara_dba->get_DnaFragAdaptor, $sms_curr );

    #Setting up previous and current place holders
    $self->param( 'prev_homologies', $sorted_prev_homologies );
    $self->param( 'curr_homologies', $sorted_curr_homologies );

} ## end sub fetch_input

sub run {
    my $self = shift @_;

    my $prev_homologies = $self->param('prev_homologies');
    my $curr_homologies = $self->param('curr_homologies');

    my %prev_homology_object_map;
    my %curr_homology_object_map;

    #Array with current homology ids to be recomputed
    my @recompute_dataflow;
    my @copy_dataflow;

    for ( my $i = 0; $i < scalar(@$curr_homologies); $i++ ) {

        $prev_homology_object_map{ $curr_homologies->[$i]->dbID } = $prev_homologies->[$i];
        $curr_homology_object_map{ $curr_homologies->[$i]->dbID } = $curr_homologies->[$i];

        #Get previous and current alignments
        my $prev_aln = $prev_homologies->[$i]->get_SimpleAlign( -seq_type => 'cds', -ID_TYPE => 'member' );
        my $curr_aln = $curr_homologies->[$i]->get_SimpleAlign( -seq_type => 'cds', -ID_TYPE => 'member' );

        #Get previous and current sequences
        my ( $prev_seq_1, $prev_seq_2 ) = $prev_aln->each_seq;
        my ( $curr_seq_1, $curr_seq_2 ) = $curr_aln->each_seq;

        #Get previous and current sequences MD5 hashes
        my $prev_seq_1_md5 = lc md5_hex( $prev_seq_1->seq() );
        my $prev_seq_2_md5 = lc md5_hex( $prev_seq_2->seq() );

        my $curr_seq_1_md5 = lc md5_hex( $curr_seq_1->seq() );
        my $curr_seq_2_md5 = lc md5_hex( $curr_seq_2->seq() );

        if ( ( $prev_seq_1_md5 eq $curr_seq_1_md5 ) && ( $prev_seq_2_md5 eq $curr_seq_2_md5 ) ) {
            #$self->warning( "homology_id:" . $curr_homologies->[$i]->dbID . "\tSAME seq: do the copy" );
            push( @copy_dataflow, $curr_homologies->[$i]->dbID );
        }
        else {
            #$self->warning( "homology_id:" . $curr_homologies->[$i]->dbID . "\tDIFF seq: dataflow to Homology_dNdS" );
            push( @recompute_dataflow, $curr_homologies->[$i]->dbID );
        }

    } ## end for ( my $i = 0; $i < scalar...)

    $self->param( 'recompute_dataflow',       \@recompute_dataflow );
    $self->param( 'copy_dataflow',            \@copy_dataflow );
    $self->param( 'prev_homology_object_map', \%prev_homology_object_map );
    $self->param( 'curr_homology_object_map', \%curr_homology_object_map );

} ## end sub run

sub write_output {
    my $self                     = shift @_;
    my $prev_homology_object_map = $self->param('prev_homology_object_map');
    my $curr_homology_object_map = $self->param('curr_homology_object_map');
    my $recompute_dataflow       = $self->param('recompute_dataflow');
    my $copy_dataflow            = $self->param('copy_dataflow');
    my $group_size               = $self->param('group_size');

    #Dataflow the ids to be recomputed
    if ( scalar(@$recompute_dataflow) > 0 ) {
        my $output_id;
        $output_id->{'mlss_id'}      = $self->param('mlss_id');
        $output_id->{'homology_ids'} = $recompute_dataflow  ;
        $self->dataflow_output_id( $output_id, 2 );
    }

    #Copy the dN/dS data from previous homology to current homology
    if ( scalar(@$copy_dataflow) > 0 ) {
        foreach my $current_homology_id (@$copy_dataflow) {

            my $prev_homology_object = $prev_homology_object_map->{$current_homology_id};
            my $curr_homology_object = $curr_homology_object_map->{$current_homology_id};

            #print "\n\n".$curr_homology_object->dbID."|".$prev_homology_object->dbID."\t=>\t".$curr_homology_object->dn."-".$prev_homology_object->ds."\n";
            #die;

            $curr_homology_object->n( $prev_homology_object->n )     if ( defined( $prev_homology_object->n ) );
            $curr_homology_object->s( $prev_homology_object->s )     if ( defined( $prev_homology_object->s ) );
            $curr_homology_object->dn( $prev_homology_object->dn )   if ( defined( $prev_homology_object->dn ) );
            $curr_homology_object->ds( $prev_homology_object->ds )   if ( defined( $prev_homology_object->ds ) );
            $curr_homology_object->lnl( $prev_homology_object->lnl ) if ( defined( $prev_homology_object->lnl ) );
            $self->param('curr_homology_adaptor')->update_genetic_distance($curr_homology_object) if ( $curr_homology_object->s or $curr_homology_object->n );
        }
    }

} ## end sub write_output

1;

