package Bio::EnsEMBL::GlyphSet::Pprotdas;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::ColourMap;
use Sanger::Graphics::Bump;
use Data::Dumper;
use ExtURL;


sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = $self->{'extras'} && $self->{'extras'}->{'name'};
    $label ||= 'ProteinDAS';

    my $label = new Sanger::Graphics::Glyph::Text
      ( { 'text'      => $label,
	  'font'      => 'Small',
	  'absolutey' => 1 });

    $self->label($label);

    return 1;
}



sub _init {

    my ($self) = @_;
    my %hash;
    my $caption       = $self->managed_name || "GeneDAS";
    my @bitmap        = undef;
	my $Config        = $self->{'config'};  
	my $prot_len	  = $self->{'container'}->length;
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int( $prot_len * $pix_per_bp);
    my $y             = 0;
    my $h             = 4;
    my $cmap          = new Sanger::Graphics::ColourMap;
    my $black         = 'black';
    my $red           = 'red';
    my $font          = "Small";
    my $colour        = $Config->get('Ppfam','col');
    my ($fontwidth,
	$fontheight)  = $Config->texthelper->px2bp($font);

    my $das_feat_ref = $self->{extras}->{features};
    ref( $das_feat_ref ) eq 'ARRAY' || 
      ( warn("No feature array for ProteinDAS track") &&  return );
    my @das_feats = @$das_feat_ref;

    foreach my $feat(@das_feats) {
	push(@{$hash{$feat->das_feature_id}},$feat);
    }

    foreach my $key (keys %hash) {
	my @row  = @{$hash{$key}};
	my $desc = $row[0]->das_feature_label();
		
	# Zmenu
	my $zmenu = { 'caption' => $row[0]->das_type(),
		      "01:".$key      => $row[0]->das_link() || undef };
	if( my $m = $row[0]->das_method ){ $zmenu->{"02:Method: $m"} = undef }
	if( my $n = $row[0]->das_note   ){ $zmenu->{"03:Note: $n"  } = undef }
		      

	my $Composite = new Sanger::Graphics::Glyph::Composite
	  ({
	    'x'     => $row[0]->start(),
	    'y'     => $y,
	    'href'  => $row[0]->das_link(),
	    'zmenu' => $zmenu,
	   });

	# Boxes
	my $pfsave;
	my ($minx, $maxx);
	foreach my $pf (@row) {
	    my $x  = $pf->start();
	    $minx  = $x if ($x < $minx || !defined($minx));
	    my $w  = $pf->end() - $x;
	    $maxx  = $pf->end() if ($pf->das_end() > $maxx || !defined($maxx));
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
	    my $text = new Sanger::Graphics::Glyph::Text
	      ({
		'font'   => $font,
		'text'   => $desc,
		'x'      => $row[0]->start(),
		'y'      => $h + 1,
		'height' => $fontheight,
		'width'  => $fontwidth * length($desc),
		'colour' => $black,
	       });
	    #$Composite->push($text);
	}

	#if ($Config->get('Pprotdas', 'dep') > 0){ # we bump
            my $bump_start = int($Composite->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
	    
            my $bump_end = $bump_start + int($Composite->width()*$pix_per_bp);
            if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
            my $row = & Sanger::Graphics::Bump::bump_row(
				      $bump_start,
				      $bump_end,
				      $bitmap_length,
				      \@bitmap
				      );
            $Composite->y($Composite->y() + $row * ($h + 2) );
        #}
	
	$self->push($Composite);
    }

}


sub managed_name{
    my ($self) = @_;
    return $self->{'extras'}->{'name'}
}


1;

