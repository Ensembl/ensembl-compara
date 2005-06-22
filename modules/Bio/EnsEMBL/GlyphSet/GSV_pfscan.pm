package Bio::EnsEMBL::GlyphSet::GSV_pfscan;
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

sub init_label {
  my ($self) = @_;
  my $label = new Sanger::Graphics::Glyph::Text({
    'text'      => 'PFScan',
    'font'      => 'Small',
    'absolutey' => 1,
    'href'      => qq[javascript:X=hw('@{[$self->{container}{_config_file_name_}]}','$ENV{'ENSEMBL_SCRIPT'}','domains')],
    'zmenu'     => {
      'caption'                     => 'HELP',
      '01:Track information...'     => qq[javascript:X=hw(\'@{[$self->{container}{_config_file_name_}]}\',\'$ENV{'ENSEMBL_SCRIPT'}\',\'domains\')]
    }
  });
  $self->label($label);
}

sub _init {
  my ($self) = @_;
  my $type = $self->check();
  return unless defined $type;

  return unless $self->strand() == -1;
  my $offset = $self->{'container'}->start - 1;
  my $Config        = $self->{'config'};
    
  my $y             = 0;
  my $h             = 8;   #Single transcript mode - set height to 30 - width to 8!
    
  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  my $fontname      = "Tiny";    
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);

  my $length  = $Config->container_width();
  my $transcript_drawn = 0;
    
  my $voffset = 0;
  my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);
  my $trans_ref = $Config->{'transcript'};
  my $strand = $trans_ref->{'exons'}[0][2]->strand;
    my $gene = $trans_ref->{'gene'};
    my $transcript = $trans_ref->{'transcript'};

  my @bitmap = undef;
  foreach my $domain_ref ( @{$trans_ref->{'pfscan_hits'}||[]} ) {
    my($domain,@pairs) = @$domain_ref;
    my $Composite3 = new Sanger::Graphics::Glyph::Composite({
      'y'         => 0,
      'height'    => $h
    });
    while( my($S,$E) = splice( @pairs,0,2 ) ) {
      $Composite3->push( new Sanger::Graphics::Glyph::Rect({
        'x' => $S,
        'y' => 0,
        'width' => $E-$S,
        'height' => $h,
        'colour' => 'purple4',
        'absolutey' => 1
      }));
    }
    $Composite3->push( new Sanger::Graphics::Glyph::Rect({
      'x' => $Composite3->{'x'},
      'width' => $Composite3->{'width'},
      'y' => $h/2,
      'height' => 0,
      'colour' => 'purple4',
      'absolutey' => 1
    }));
    my $text_label = $domain->hseqname;
    my $width_of_label = length( "$text_label " ) * $font_w_bp;
    $Composite3->push( new Sanger::Graphics::Glyph::Text({
      'x'         => $Composite3->{'x'},
      'y'         => $h+2,
      'height'    => $font_h_bp,
      'width'     => $width_of_label,
      'font'      => $fontname,
      'colour'    => 'purple4',
      'text'      => $text_label,
      'absolutey' => 1,
    }));
    $text_label = $domain->idesc;
    $width_of_label = length( "$text_label " ) * $font_w_bp;
    $Composite3->push( new Sanger::Graphics::Glyph::Text({
      'x'         => $Composite3->{'x'},
      'y'         => $h+4 + $font_h_bp,
      'height'    => $font_h_bp,
      'width'     => $width_of_label,
      'font'      => $fontname,
      'colour'    => 'purple4',
      'text'      => $text_label,
      'absolutey' => 1,
    }));
    my $bump_start = int($Composite3->{'x'} * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($Composite3->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );

    $Composite3->y( $voffset + $Composite3->{'y'} + $row * ($h+$font_h_bp*2+5) );
    $self->push( $Composite3 );
  }

}

1;
