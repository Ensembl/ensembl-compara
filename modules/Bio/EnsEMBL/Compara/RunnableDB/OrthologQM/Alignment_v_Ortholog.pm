=pod

=head1 NAME
    
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Alignment_v_Ortholog

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut


# {
#   "dnafrag_coords" => { # gblock
#       13777389 => [49039366,49039514],
#       13955519 => [42615244,42615393]
#   },
#   "dnafrag_gdbs" => { # gblock
#       13777389 => 142,
#       13955519 => 150
#   },
#   "gblock_ids" => ["7190000047153"],
#   "orth_dnafrags" => [13777389,13955519],
#   "orth_id" => 109981076
# }


package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Alignment_v_Ortholog;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;

=head2 fetch_input

    Description: 
    1. pull out all GenomicAlignBlocks
    2. find the GenomicAlign obj matching the required genome_db_id
    3. parse out start and end positions

=cut

sub fetch_input {
    my $self = shift;

    Bio::EnsEMBL::Registry->load_all( $self->param_required('reg_conf') );

    my $orth_id    = $self->param_required( 'orth_id' );
    unless ( $self->param( 'orth_exons' ) ) { $self->param( 'orth_exons', $self->_fetch_exons( $orth_id ) ) };
}

=head2 run

    Description: check input from previous step and prepare report structure

=cut

sub run {
    my $self = shift;

    my @result;

    my %orth_info  = %{ $self->param('orth_ranges') };
    my %orth_exons = %{ $self->param('orth_exons') };
    my %aln_coord  = %{ $self->param('gblock_range') };

    print "ORTH INFO: ";
    print Dumper \%orth_info;

    print "aln_coord: ";
    print Dumper \%aln_coord;

    print "orth_exons: ";
    print Dumper \%orth_exons;

    foreach my $gdb_id ( keys %aln_coord ){
        my $orth = $orth_info{ $aln_coord{$gdb_id} };
        my $perc_match = $self->_percentage_match( $orth_info{$gdb_id}, $aln_coord{$gdb_id}, $orth_exons{$gdb_id} );
        if ( $perc_match ){
            push( @result, {
                homology_id            => $self->param_required('orth_id'),
                genomic_aln_block_id   => $self->param_required('gblock_id'),
                genome_db_id           => $gdb_id,
                exon_coverage          => $perc_match->{exon},
                intron_coverage        => $perc_match->{intron},
                }
            );
        }
    }
    
    $self->param ( 'result', \@result );
}

=head2 write_output

    Description: send data to correct dataflow branch!

=cut

sub write_output {
    my $self = shift;

    # print "RESULT: ";
    # print Dumper $self->param('result');

    print "ORTH EXONS:\n";
    print Dumper $self->param('orth_exons');

    $self->dataflow_output_id( { orth_exon_ranges => $self->param('orth_exons') }, 1 );
    $self->dataflow_output_id( $self->param('result'), 2 );
}

sub _percentage_match {
    my ( $self, $orth, $aln, $orth_exons ) = @_;

    my ( $o_start, $o_end )   = @{ $orth };
    my ( $a_start, $a_end ) = @{ $aln };


    # print "orth: " . commify($o_start) . "-" . commify($o_end) . "\taln: " . commify($a_start) . "-" . commify($a_end) . "\n";
    # &_prettify_orth_aln_overlap([$o_start, $o_end],[$a_start, $a_end]);
    # print "orth_exons: ";
    # print Dumper $orth_exons;

    # check if overlap exists
    unless( ( $a_start >= $o_start && $a_start < $o_end ) 
         || ( $a_end >= $o_start && $a_end < $o_end ) 
         || ( $o_start >= $a_start && $o_start < $a_end ) 
         || ( $o_end >= $a_start && $o_end < $a_end ) ) 
    {
        # print "NO OVERLAP\n";
        return 0;
    }

    # create map of exon coverage
    my %exon_cov;
    foreach my $exon ( @{ $orth_exons } ) {
        foreach my $pos ( $exon->[0]..$exon->[1] ) {
            $exon_cov{$pos} = 1;
        }
    }

    # find overlap and loop through it, checking for exons
    my $max_start = $o_start >= $a_start ? $o_start : $a_start;
    my $min_end   = $o_end <= $a_end ? $o_end : $a_end;
    my ( $ex_c, $in_c ) = ( 0, 0 );
    foreach my $pos ( $max_start..$min_end ) {
        if ( defined $exon_cov{$pos}  ) { $ex_c++; }
        else                            { $in_c++; }
    }

    # get percentage coverage of orth
    my $o_len = $o_end - $o_start + 1;

    # print "!!!!!!!!! Exon count: $ex_c\tIntron count: $in_c; Orth len: $o_end - $o_start = $o_len\n";

    my $ex_perc = ( $ex_c/$o_len ) * 100;
    my $in_perc = ( $in_c/$o_len ) * 100;

    return { 'exon' => $ex_perc, 'intron' => $in_perc };
}

=head2 _fetch_exons

    Description: fetch exon coordinates for each gene member in the homology

    Returns: hash of exon coordinates; key = GeneMember ID; value = array of exon coordinates

    Homology -> get_all_GeneMembers
    GeneMember -> get_all_SeqMembers
    SeqMember -> get_Transcript
    Transcript -> get_all_Exons/get_all_translatable_Exons

=cut

sub _fetch_exons {
    my ( $self, $orth_id ) = @_;

    my %orth_exons;

    my $hom_adapt = $self->compara_dba->get_HomologyAdaptor;
    my $homology  = $hom_adapt->fetch_by_dbID( $orth_id );

    my $gene_members = $homology->get_all_GeneMembers();
    foreach my $gm ( @{ $gene_members } ) {
        $orth_exons{ $gm->genome_db_id } = [];
        my $seqmems = $gm->get_all_SeqMembers;
        foreach my $sm ( @{ $seqmems } ) {
            my $transcript = $sm->get_Transcript;
            my $exon_list = $transcript->get_all_Exons;
            foreach my $exon ( @{ $exon_list } ) {
                my @ex_coords = ( $exon->start, $exon->end );
                push( @{ $orth_exons{ $gm->genome_db_id } }, \@ex_coords );
            }
        }
    }

    # print "EXONS: ";
    # print Dumper \%orth_exons;

    return \%orth_exons;
}

# sub commify {
#     my $text = reverse $_[0];
#     $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
#     return scalar reverse $text
# }

1;