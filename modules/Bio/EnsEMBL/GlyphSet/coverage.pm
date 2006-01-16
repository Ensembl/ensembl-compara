package Bio::EnsEMBL::GlyphSet::coverage;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);

sub init_label {
  my $self = shift;
  $self->label(new Sanger::Graphics::Glyph::Text({
    'text'      => "Read coverage",
    'font'      => 'Small',
    'absolutey' => 1,
  }));
}


sub _init {
  my ($self) = @_;

  # Data
  #  my $slice          = $self->{'container'};
  my $Config         = $self->{'config'};
  my $transcript     = $Config->{'transcript'}->{'transcript'};
  my $coverage_level = $Config->{'transcript'}->{'coverage_level'};
  my $coverage_obj   = $Config->{'transcript'}->{'coverage_obj'};
  my $sample         = $Config->{'transcript'}->{'sample'};
  return unless @$coverage_obj && @$coverage_level;

  my %level = (
	       $coverage_level->[0] => [1, "plum1"],
	       $coverage_level->[1] => [2, "plum3"],
	      );

  # my $type = $self->check();
  #   return unless defined $type;
  #   return unless $self->strand() == -1;

  # my $EXTENT        = $Config->get('_settings','context');
  #    $EXTENT        = 1e6 if $EXTENT eq 'FULL';
  # my $seq_region_name = $self->{'container'}->seq_region_name();

  # Drawing stuff
  my $fontname      = $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'};
  my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);

  # Bumping 
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);
  my $voffset = 0;
  my @bitmap;
  my $max_row = -1;


  foreach my $coverage (  @$coverage_obj  ) {
    my $level  = $coverage->[2]->level;
    my $y = $level{ $level }->[0] *5 ; #$font_h_bp + 4;  #Single transcript mode: height= 30, width=8


    # Draw ------------------------------------------------
    my $S =  ( $coverage->[0]+$coverage->[1] - $font_w_bp * length( $level ) )/2;
    my $width = $font_w_bp * length( $level );
     my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
     my $start = $coverage->[2]->start() + $offset;
     my $end   = $coverage->[2]->end() + $offset;
     my $pos   = "$start-$end";

    my $bglyph = new Sanger::Graphics::Glyph::Rect({
       'x'         => $S - $font_w_bp / 2,
       'y'         => $y + 2,
       'height'    => 1,                            #$y,
       'width'     => $width + $font_w_bp + 4,
       'colour'    => $level{$level}->[1],
       'absolutey' => 1,
       'zmenu' => {
         'caption' => 'Read coverage: '.$level,
	 "12:bp $pos" => '',
         "14:sample $sample" => '',
       }
						   });
    my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
    $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($bglyph->width()*$pix_per_bp) +1;
    $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
    $max_row = $row if $row > $max_row;
    $bglyph->y( $voffset + $bglyph->{'y'} + ( $row * (2+$y) ) + 1 );
    $self->push( $bglyph);
  }
}

#sub error_track_name { return $_[0]->species_defs->AUTHORITY.' transcripts'; }

1;
