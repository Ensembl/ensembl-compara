package Bio::EnsEMBL::GlyphSet;
use strict;
use Exporter;
use Sanger::Graphics::GlyphSet;

use vars qw(@ISA $AUTOLOAD);

@ISA=qw(Sanger::Graphics::GlyphSet);

#########
# constructor
#
sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
       $self->{'bumpbutton'} = undef;
    return $self;
}

sub bumpbutton {
    my ($self, $val) = @_;
    $self->{'bumpbutton'} = $val if(defined $val);
    return $self->{'bumpbutton'};
}

sub label2 {
    my ($self, $val) = @_;
    $self->{'label2'} = $val if(defined $val);
    return $self->{'label2'};
}

sub check {
    my( $self ) = @_;
    ( my $feature_name = ref $self) =~s/.*:://;
    return $self->{'config'}->is_available_artefact( $feature_name ) ? $feature_name : undef ;
}

## Stuff copied out of scalebar.pm so that contig.pm can use it!

sub zoom_URL {
    my( $self, $PART, $interval_middle, $width, $factor, $highlights ) = @_;
    my $start = int( $interval_middle - $width / 2 / $factor);
    my $end   = int( $interval_middle + $width / 2 / $factor);        
    return qq(/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?$PART&vc_start=$start&vc_end=$end&$highlights);
}

sub zoom_zoom_zmenu {
    my ($self, $chr, $interval_middle, $width, $highlights, $zoom_width) = @_;
    return { 
            'caption'                          => "Navigation",
            '03:Zoom in (x2)'                  => $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights)."&zoom_width=".int($zoom_width/2),
            '04:Centre on this scale interval' => $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights), 
            '05:Zoom out (x0.5)'               => $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights)."&zoom_width=".($zoom_width*2) 
    };
}
sub zoom_zmenu {
    my ($self, $chr, $interval_middle, $width, $highlights) = @_;
    return { 
            'caption'                          => "Navigation",
            '01:Zoom in (x10)'                 => $self->zoom_URL($chr, $interval_middle, $width, 10  , $highlights),
            '02:Zoom in (x5)'                  => $self->zoom_URL($chr, $interval_middle, $width,  5  , $highlights),
            '03:Zoom in (x2)'                  => $self->zoom_URL($chr, $interval_middle, $width,  2  , $highlights),
            '04:Centre on this scale interval' => $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights), 
            '05:Zoom out (x0.5)'               => $self->zoom_URL($chr, $interval_middle, $width,  0.5, $highlights), 
            '06:Zoom out (x0.2)'               => $self->zoom_URL($chr, $interval_middle, $width,  0.2, $highlights), 
            '07:Zoom out (x0.1)'               => $self->zoom_URL($chr, $interval_middle, $width,  0.1, $highlights)                 
    };
}

sub draw_cigar_feature {
  my( $self, $Composite, $f, $h, $feature_colour, $delete_colour ) = @_;
## Find the 5' end of the feature.. (start if on forward strand of forward feature....)
  my $S = (my $O = $self->strand ) == 1 ? $f->start : $f->end;
  my $length = $self->{'container'}->length;

  my @delete;

## Parse the cigar string, splitting up into an array
## like ('10M','2I','30M','I','M','20M','2D','2020M');
## original string - "10M2I30MIM20M2D2020M"
  foreach( $f->cigar_string=~/(\d*[MDI])/g ) {
## Split each of the {number}{Letter} entries into a pair of [ {number}, {letter} ] 
## representing length and feature type ( 'M' -> 'Match/mismatch', 'I' -> Insert, 'D' -> Deletion )
## If there is no number convert it to [ 1, {letter} ] as no-number implies a single base pair...
    my ($l,$type) = /^(\d+)([MDI])/ ? ($1,$2):(1,$_);
## If it is a D (this is a deletion) and so we note it as a feature between the end
## of the current and the start of the next feature...
##                      ( current start, current start - ORIENTATION )
## otherwise it is an insertion or match/mismatch
##  we compute next start sa ( current start, next start - ORIENTATION ) 
##  next start is current start + (length of sub-feature) * ORIENTATION 
    my $s = $S;
    my $e = ( $S += ( $type eq 'D' ? 0 : $l*$O ) ) - $O;
## If a match/mismatch - draw box....
    if($type eq 'M') {
      ($s,$e) = ($e,$s) if $s>$e;      ## Sort out flipped features...
      next if $e < 1 || $s > $length;  ## Skip if all outside the box...
      $s = 1       if $s<1;            ## Trim to area of box...
      $e = $length if $e>$length;
      $Composite->push(new Sanger::Graphics::Glyph::Rect({
        'x'          => $s-1,            'y'          => 0, 
        'width'      => $e-$s+1,         'height'     => $h,
        'colour'     => $feature_colour, 'absolutey'  => 1,
      }));
## If a deletion temp store it so that we can draw after all matches....
    } elsif($type eq 'D') {
      ($s,$e) = ($e,$s) if $s<$e;
      next if $e < 1 || $s > $length;  ## Skip if all outside box
      push @delete, $e;
    }
  }

## Draw deletion markers....
  foreach (@delete) {
    $Composite->push(new Sanger::Graphics::Glyph::Rect({
      'x'          => $_,              'y'          => 0, 
      'width'      => 0,               'height'     => $h,
      'colour'     => $delete_colour,  'absolutey'  => 1,
    }));
  }
}

1;
