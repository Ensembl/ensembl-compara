package Bio::EnsEMBL::GlyphSet::Pprotdas;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::ColourMap;
use Sanger::Graphics::Bump;
use POSIX; #floor

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );

  my $numchars = 16;
  my $indent   = 1;
  my $Config   = $self->{'config'};
  my $confkey  = $self->{'extras'}->{'confkey'};
  my $text     = $self->{'extras'}->{'label'} || $self->{'extras'}->{'name'};
  my $colour   = $Config->get($confkey,'col') || 'black';


  my $print_label = ( length($text) > ( $numchars - $indent ) ? 
		      substr( $text, 0, ( $numchars - $indent - 2 ) )."..": 
		      $text );
  $self->init_label_text( $print_label );
  $self->{'label'}->{'ptsize'} *= 0.8;
}



sub _init {

    my ($self) = @_;
    my %hash;
    my $caption       = $self->managed_name || "GeneDAS";
    my @bitmap        = undef;
    my $Config        = $self->{'config'};  
    my $prot_len      = $self->{'container'}->length;
    my $pix_per_bp    = $Config->transform->{'scalex'};

    my $bml = floor( $prot_len * $pix_per_bp);
    my $bitmap_length = floor( $prot_len * $pix_per_bp);

    my $transcript = $self->{'container'}->adaptor->db->get_TranscriptAdaptor->fetch_by_translation_stable_id( $self->{'container'}->stable_id );
    my $y             = 0;
    my $h             = 4;
    my $black         = 'black';
    my $red           = 'red';
    my $font          = "Small";
    my $das_confkey   = $self->{'extras'}->{'confkey'};

    my $colour        = $Config->get($das_confkey,'col') || 'black';
    my ($fontwidth,$fontheight)  = $Config->texthelper->px2bp($font);

    my $das_feat_ref = $self->{extras}->{features};
    ref( $das_feat_ref ) eq 'ARRAY' || ( warn("No feature array for ProteinDAS track") &&  return );

    my @features;

    foreach my $feat (@$das_feat_ref) {
	next if ( ! $feat->end); # Draw only features that have location	
	if ($self->{'extras'}->{'source_type'} !~ /^ensembl_location/) {
	    push(@{$hash{$feat->das_feature_id}},$feat);
	    next;
	}

	my @coords =  grep { $_->isa('Bio::EnsEMBL::Mapper::Coordinate') } $transcript->genomic2pep($feat->das_segment->start, $feat->das_segment->end, $feat->strand);

	if (@coords) {
	    my $c = $coords[0];
	    my $end = ($c->end > $prot_len) ? $prot_len : $c->end; 
	    $feat->{translation_end} =  $end;

	    my $start = ($c->start < $end) ? $c->start : $end;
	    $feat->{translation_start} =  $start;
	    push (@features, $feat);
	}
    }

    foreach my $f (@features) {
	my $desc = $f->das_feature_label() || $f->das_feature_id;

	# Zmenu
	my $zmenu = { 'caption' => $desc };

	if( my $m = $f->das_feature_id ){ $zmenu->{"03:ID: $m"}     = undef }
	if( my $m = $f->das_type       ){ $zmenu->{"05:TYPE: $m"}   = undef }
	if( my $m = $f->das_method     ){ $zmenu->{"10:METHOD: $m"} = undef }
	my $ids = 15;
	my $href;
	foreach my $dlink ($f->das_links) {
	    my $txt = $dlink->{'txt'} || $dlink->{'href'};
	    my $dlabel = sprintf("%02d:LINK: %s", $ids++, $txt);
	    $zmenu->{$dlabel} = $dlink->{'href'};
	    $href =  $dlink->{'href'} if (! $href);
	}
	if( my $m = $f->das_note       ){ $zmenu->{"40:NOTE: $m"}   = undef }
		      

	my $Composite = new Sanger::Graphics::Glyph::Composite
	  ({
	    'x'     => $f->{translation_start},
	    'y'     => $y,
	    'href'  => $href,
	    'zmenu' => $zmenu,
	   });

	# Boxes
	my $pfsave;
	my ($minx, $maxx);

	my $x  = $f->{translation_start};
	my $w  = $f->{translation_end} - $x;
	my $id = $f->das_feature_id();

	my $rect = new Sanger::Graphics::Glyph::Rect({
	    'x'        => $x,
	    'y'        => $y,
	    'width'    => $w,
	    'height'   => $h,
	    'colour'   => $colour,
	});
	$Composite->push($rect);


#	my $rect = new Sanger::Graphics::Glyph::Rect({
#	    'x'         => $x,
#	    'y'         => $y + 2,
#	    'width'     => $maxx - $minx,
#	    'height'    => 0,
#	    'colour'    => $colour,
#	    'absolutey' => 1,
#	});
#	$Composite->push($rect);

	my $bump_start = floor($Composite->x() * $pix_per_bp);
	$bump_start = 0 if ($bump_start < 0);
	next if ($bump_start > $bitmap_length);

	my $bump_end = $bump_start + floor($Composite->width()*$pix_per_bp);

	if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
	my $row = Sanger::Graphics::Bump::bump_row(
						   $bump_start,
						   $bump_end,
						   $bitmap_length,
						   \@bitmap
						   );
	$Composite->y($Composite->y() + $row * ($h + 2) );
	$self->push($Composite);
    }


    foreach my $key (keys %hash) {
	my @row = @{$hash{$key}};
	my $f = $row[0];
	my $desc = $f->das_feature_label() || $f->das_feature_id;

	# Zmenu
	my $zmenu = { 'caption' => $desc };

	if( my $m = $f->das_feature_id ){ $zmenu->{"03:ID: $m"}     = undef }
	if( my $m = $f->das_type       ){ $zmenu->{"05:TYPE: $m"}   = undef }
	if( my $m = $f->das_method     ){ $zmenu->{"10:METHOD: $m"} = undef }
	my $ids = 15;
	my $href;
	foreach my $dlink ($f->das_links) {
	    my $txt = $dlink->{'txt'} || $dlink->{'href'};
	    my $dlabel = sprintf("%02d:LINK: %s", $ids++, $txt);
	    $zmenu->{$dlabel} = $dlink->{'href'};
	    $href =  $dlink->{'href'} if (! $href);
	}
	if( my $m = $f->das_note       ){ $zmenu->{"40:NOTE: $m"}   = undef }
		      

	my $Composite = new Sanger::Graphics::Glyph::Composite
	  ({
	    'x'     => floor($f->start),
	    'y'     => $y,
	    'href'  => $href,
	    'zmenu' => $zmenu,
	   });

	# Boxes
	my $pfsave;
	my ($minx, $maxx);
	foreach my $pf (@row) {
	    my $x  = floor($pf->start );
	    $minx  = $x if (! defined($minx) || $x < $minx);
	    my $w  = floor($pf->end ) - $x;
	    $maxx  = floor($pf->end) if (! defined($maxx) || (floor($pf->das_end)) > $maxx);
	    my $id = $pf->das_feature_id();

	    my $rect = new Sanger::Graphics::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'colour'   => $colour,
	    });
	    $Composite->push($rect);
	    $pfsave = $pf;
	}

	my $rect = new Sanger::Graphics::Glyph::Rect({
	    'x'         => $minx,
	    'y'         => $y + 2,
	    'width'     => $maxx - $minx,
	    'height'    => 0,
	    'colour'    => $colour,
	    'absolutey' => 1,
	});
	$Composite->push($rect);

	# Label - disabled for now
	if( 0 ){
	    my $desc = $pfsave->das_feature_label() || $key;
	    my $text = new Sanger::Graphics::Glyph::Text({
		'font'   => $font,
		'text'   => $desc,
		'x'      => $row[0]->start(),
		'y'      => $h,
		'height' => $fontheight,
		'width'  => $fontwidth * length($desc),
		'colour' => $black,
	       });
	    #$Composite->push($text);
	}

	my $bump_start = floor($Composite->x() * $pix_per_bp);
	$bump_start = 0 if ($bump_start < 0);
	next if ($bump_start > $bitmap_length);

	my $bump_end = $bump_start + floor($Composite->width()*$pix_per_bp);
	if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
	my $row = Sanger::Graphics::Bump::bump_row(
				      $bump_start,
				      $bump_end,
				      $bitmap_length,
				      \@bitmap
				      );
	$Composite->y($Composite->y() + $row * ($h + 2) );
	$self->push($Composite);
    }
    if( ! scalar %hash ){ # Add a spacer glyph to force an empty track
      my $spacer = new Sanger::Graphics::Glyph::Space
	({
	  'x'         => 0,
	  'y'         => 0,
	  'width'     => 0,
	  'height'    => $h,
	  'absolutey' => 1,
	 });
      $self->push($spacer); 
    }

}


#----------------------------------------------------------------------
# Returns the order corresponding to this glyphset
sub managed_name{
  my $self = shift;
  return $self->{'extras'}->{'order'} || 0;
}


1;

