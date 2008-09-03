package Bio::EnsEMBL::GlyphSet::chr_band;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

my %SHORT = qw(
  'chromosome'  "Chr."
  'supercontig' "S'ctg"
);

sub _init {
  my ($self) = @_;

  ########## only draw contigs once - on one strand
  return unless ($self->strand() == 1);

  my $col    = undef;
  my $config = $self->{'config'};
  my $white  = 'white';
  my $black  = 'black';
 
  my $no_sequence = $self->{'config'}->species_defs->NO_SEQUENCE;

  my %COL = (
    'gpos100' => [ 'black',     'white' ],
    'tip'     => [ 'slategrey'. 'white' ],
    'gpos75'  => [ 'grey40',    'white' ],
    'gpos66'  => [ 'grey50',    'white' ],
    'gpos50'  => [ 'grey60',    'black' ],
    'gpos33'  => [ 'grey75',    'black' ],
    'gpos25'  => [ 'grey85',    'black' ],
    'gpos'    => [ 'black'.     'white' ],
    'gvar'    => [ 'grey88',    'black' ],
    'gneg'    => [ 'white',     'black' ],
    'acen'    => [ 'slategrey'. 'white' ],
    'stalk'   => [ 'slategrey'. 'white' ]
  );
    
  my $im_width = $self->{'config'}->image_width();
   
  my $prev_end = 0;
    # fetch the chromosome bands that cover this VC.
  my $bands = $self->{'container'}->get_all_KaryotypeBands();
  my $min_start;
  my $max_end; 
  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3];
  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};
  
  my $chr = @$bands ? $bands[0]->slice()->seq_region_name() : '';
  foreach my $band (reverse @$bands){
    my $bandname = $band->name();
       $bandname =~ /(\d+)\w?/;
    my $band_no = $1;
    my $start = $band->start();
    my $end = $band->end();
    my $stain = $band->stain();
    
    my $vc_band_start = $start;
    $vc_band_start    = 0 if ($vc_band_start < 0);
    my $vc_band_end   = $end;
    $vc_band_end      =  $self->{'container'}->length() if ($vc_band_end > $self->{'container'}->length());

    my $min_start = $vc_band_start if(!defined $min_start || $min_start > $vc_band_start); 
    my $max_end   = $vc_band_end   if(!defined $max_end   || $max_end   < $vc_band_end); 
    $self->push($self->Rect({
      'x'      => $vc_band_start -1 ,
      'y'      => 0,
      'width'  => $vc_band_end - $vc_band_start +1 ,
      'height' => $h + 4,
      'colour' => $self->my_colour( $stain ) ||'white',
      'absolutey' => 1,
    });
    
    my $fontcolour = $self->my_colour($stain,'label');
    if( $fontcolour ne 'invisible' ) {
      my @res = $self->get_text_width( ($vc_band_end-$vc_band_start)*$pix_per_bp, $bandname, '', 'font'=>$fontname, 'ptsize' => $fontsize );
    # only add the lable if the box is big enough to hold it...
      if( $res[0] &) {
        $self->push($self->Text({
          'x'      => int(($vc_band_end + $vc_band_start-$res[2]/$pix_per_bp)/2),
          'y'      => 1,
          'width'  => $res[2]/$pix_per_bp,
          'textwidth' => $res[2],
          'font'   => $fontname,
          'height' => $h,
          'ptsize' => $fontsize,
          'colour' => $fontcolour,
          'text'   => $res[0],
          'absolutey'  => 1,
        });
      }
    }
    my $vc_adjust  = 1 - $self->{'container'}->start ;
    my $band_start = $band->{'start'} - $vc_adjust;
    my $band_end   = $band->{'end'}   - $vc_adjust;
    $self->push($self->Rect({
      'x'             => $min_start -1,
      'y'             => 0,
      'width'         => $max_end - $min_start + 1,
      'height'        => $h + 4 ,
      'bordercolour'  => $black,
      'absolutey'     => 1,
      'title'         => "Band: $bandname"
      'href'          => $this->_url({'r'=>"$chr:$band_start-$band_end"})
    }));
  }
}

1;
