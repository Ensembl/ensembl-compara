package EnsEMBL::Web::Component::Location::ComparaGenomicAlignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use EnsEMBL::Web::Document::HTML::TwoCol;

sub _init {
    my $self = shift;
    $self->cacheable( 1 );
    $self->ajaxable(  1 );
}

sub caption {
    return undef;
}

sub content {
    my $self = shift;
    my $object = $self->object;
    my $html;
    (my $p_species                 = $object->species ) =~ s/_/ /;
    (my $s_species                 = $object->param('s1')      ) =~ s/_/ /;
    my( $p_chr, $p_start, $p_end ) = $object->param('r')=~/^(.+):(\d+)-(\d+)$/;
    my( $s_chr, $s_start, $s_end ) = $object->param('r1')=~/^(.+):(\d+)-(\d+)$/;
    my $method                     = $object->param( 'method' );
    my $disp_method = $method;
    $disp_method =~ s/BLASTZ_NET/BLASTz net/g;
    $disp_method =~ s/TRANSLATED_BLAT_NET/Trans. BLAT net/g;
    my $compara_db                 = $object->database('compara');
    my $dafa                       = $compara_db->get_DnaAlignFeatureAdaptor;
    my $features;
    eval {
	$features = $dafa->fetch_all_by_species_region(
	    $p_species, undef, $s_species, undef, $p_chr, $p_start, $p_end, $method
	);
    };
    my $objects = [];
    foreach my $f ( @$features ) {
	if( $f->seqname eq $p_chr && $f->start == $p_start && $f->end == $p_end && $f->hseqname eq $s_chr && $f->hstart == $s_start && $f->hend == $s_end ) {
	    push @$objects, $f; ## This IS the aligmnent of which we speak 
	}
    }
    foreach my $align ( @{$objects} ) {
	$html .= sprintf( qq(<h3>%s alignment between %s %s %s and %s %s %s</h3>),
			 $disp_method, $align->species,  $align->slice->coord_system_name, $align->seqname,
			 $align->hspecies, $align->hslice->coord_system_name, $align->hseqname
		     );

	my $BLOCKSIZE = 60;
	my $REG       = "(.{1,$BLOCKSIZE})";
	my ( $ori, $start, $end ) = $align->strand < 0 ? ( -1, $align->end, $align->start ) : ( 1, $align->start, $align->end );
	my ( $hori, $hstart, $hend ) = $align->hstrand < 0 ? ( -1, $align->hend, $align->hstart ) : ( 1, $align->hstart, $align->hend );
	my ( $seq,$hseq) = @{$align->alignment_strings()||[]};
	$html .= '<pre>';
	while( $seq ) {
	    $seq  =~s/$REG//; my $part = $1;
	    $hseq =~s/$REG//; my $hpart = $1;
	    $html .= sprintf( "%9d %-60.60s %9d\n%9s ", $start, $part, $start + $ori * ( length( $part) - 1 ),' ' ) ;
	    my @BP = split //, $part;
	    foreach( split //, ($part ^ $hpart ) ) {
		$html .=  ord($_) ? ' ' : $BP[0] ;
		shift @BP;
	    }
	    $html .= sprintf( "\n%9d %-60.60s %9d\n\n", $hstart, $hpart, $hstart + $hori * ( length( $hpart) - 1 ) ) ;
	    $start += $ori * $BLOCKSIZE;
	    $hstart += $hori * $BLOCKSIZE;
	}
	$html .= '</pre>';
    }
    return $html;
}

1;
