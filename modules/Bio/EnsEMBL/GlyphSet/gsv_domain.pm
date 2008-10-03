package Bio::EnsEMBL::GlyphSet::gsv_domain;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;

sub _init {
  my ($self) = @_;
  my $type = $self->check();
  return unless defined $type; warn $type;
  
  return unless $self->strand() == -1; 
  my $key = lc($self->my_config('logicnames')).'_hits'; 
  warn $key;


  my $Config        = $self->{'config'};
  my $trans_ref = $Config->{'transcript'};
  my $offset = $self->{'container'}->start - 1;
    
  my $y             = 0;
  my $h             = 8;   #Single transcript mode - set height to 30 - width to 8!
    
  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font' => $fontname, 'ptsize' => $fontsize );
  my $th = $res[3];
  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'}; 
  
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);

  my $length  = $Config->container_width();
  my $transcript_drawn = 0;
    
  my $voffset = 0;
  my $strand = $trans_ref->{'exons'}[0][2]->strand;
    my $gene = $trans_ref->{'gene'};
    my $transcript = $trans_ref->{'transcript'};

  my @bitmap = undef; #foreach (keys %$trans_ref){ warn $_;}
  foreach my $domain_ref ( @{$trans_ref->{$key}||[]} ) {
    my($domain,@pairs) = @$domain_ref;
    my $Composite3 = $self->Composite({
      'y'         => 0,
      'height'    => $h
    });
    while( my($S,$E) = splice( @pairs,0,2 ) ) {
      $Composite3->push( $self->Rect({
        'x' => $S,
        'y' => 0,
        'width' => $E-$S,
        'height' => $h,
        'colour' => 'purple4',
        'absolutey' => 1
      }));
    }
    $Composite3->push( $self->Rect({
      'x' => $Composite3->{'x'},
      'width' => $Composite3->{'width'},
      'y' => $h/2,
      'height' => 0,
      'colour' => 'purple4',
      'absolutey' => 1
    }));
    my $text_label = $domain->hseqname;
    my @res = $self->get_text_width( 0, $text_label, '', 'font' => $fontname, 'ptsize' => $fontsize );
    $Composite3->push( $self->Text({
      'x'         => $Composite3->{'x'},
      'y'         => $h,
      'height'    => $th,
      'width'     => $res[2]/$pix_per_bp,
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'halign'    => 'left', 
      'colour'    => 'purple4',
      'text'      => $text_label,
      'absolutey' => 1,
    }));
    $text_label = $domain->idesc;
    my @res = $self->get_text_width( 0, $text_label, '', 'font' => $fontname, 'ptsize' => $fontsize );
    $Composite3->push( $self->Text({
      'x'         => $Composite3->{'x'},
      'y'         => $h+2 + $th,
      'height'    => $th,
      'width'     => $res[2]/$pix_per_bp,
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'halign'    => 'left', 
      'colour'    => 'purple4',
      'text'      => $text_label,
      'absolutey' => 1,
    }));
    my $bump_start = int($Composite3->{'x'} * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($Composite3->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );

    $Composite3->y( $voffset + $Composite3->{'y'} + $row * ($h+$th*2+5) );
    $self->push( $Composite3 );
  }

}

1;
