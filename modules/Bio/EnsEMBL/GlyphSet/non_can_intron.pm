package Bio::EnsEMBL::GlyphSet::non_can_intron;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my ($self) = @_;
    my $Config  = $self->{'config'};
    my $length  = $Config->container_width();
    my $colour  = $Config->get('non_can_intron','col');
    my $trans_ref = $Config->{'transcript'};
    return unless ($trans_ref->{'non_con_introns'});
    my @introns = @{$trans_ref->{'non_con_introns'}};

    foreach my $intron (@introns) { 
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
	    'y'         => 0,
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
	    'y'         => -3,
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
	    'y'         => -3,
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
