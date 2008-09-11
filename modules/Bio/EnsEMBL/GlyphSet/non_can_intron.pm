package Bio::EnsEMBL::GlyphSet::non_can_intron;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my ($self) = @_;
    my $wuc  =   $self->{'config'};
    my $length  = $wuc->container_width();
    my $colour  = $self->my_colour('non_can_intron');
    my $trans_obj = $wuc->cache('trans_object');
    return unless $trans_obj->{'non_can_introns'};
    foreach my $intron (@{$trans_obj->{'non_can_introns'}}) {
	next unless defined $intron;
	my $exon_names = $intron->[4];
	
	# only draw this exon if is inside the slice
	my $box_start = $intron->[0];
	$box_start = 1 if $box_start < 1 ;
	my $box_end   = $intron->[1];
	$box_end    = $length if $box_end > $length;
		
	#Draw an I-bar covering the intron
	my $G = $self->Line({
	    'x'         => $box_start ,
	    'y'         => 1,
	    'width'     => $box_end-$box_start,
	    'height'    => 0,
	    'colour'    => $colour,
	    'absolutey' => 1,
	    'title'     => "$exon_names",
	    'href'      => '',
	});
	$self->push( $G );
	$G = $self->Line({
	    'x'         => $box_start,
	    'y'         => -2,
	    'width'     => 0,
	    'height'    => 6,
	    'colour'    => $colour,
	    'absolutey' => 1,
	    'title'     => "$exon_names",
	    'href'      => '',
	});
	$self->push( $G );
	$G = $self->Line({
	    'x'         => $box_end ,
	    'y'         => -2,
	    'width'     => 0,
	    'height'    => 6,
	    'colour'    => $colour,
	    'absolutey' => 1,
	    'title'     => "$exon_names",
	    'href'      => '',
	});	
	$self->push( $G )
    }
}

1;
