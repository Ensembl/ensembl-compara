package Bio::EnsEMBL::GlyphSet::P_domain;
use strict;
no warnings "uninitialized";
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use  Sanger::Graphics::Bump;

## Variables defined in UserConfig.pm 
## 'caption'   -> Track label
## 'logicname' -> Logic name

sub _init {
  my ($self) = @_;
  my %hash;
  my $y             = 0;
  my $h             = 4;
  my @bitmap        = undef;
  my $protein       = $self->{'container'};
  return unless $protein->dbID;
  return unless $self->check();
  my $Config        = $self->{'config'};
  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $th = $res[3];
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = int($protein->length() * $pix_per_bp);

  my $logic_name    = $self->my_config( 'logic_name' );
  my $URL_key       = $self->my_config( 'url_key'    ) || uc($logic_name);
  my $label         = $self->my_config( 'caption'    ) || uc($logic_name);
  my $depth         = $self->my_config( 'dep'        );
  my $colours       = $self->my_config( 'colours'    )||{};
  my $colour        = $colours->{lc($logic_name)} || $colours->{'default'};
  my $font          = "Small";

#warn ">>> $logic_name <<<";
  my @ps_feat = @{$protein->get_all_ProteinFeatures( $logic_name )};

  foreach my $feat(@ps_feat) {
     push(@{$hash{$feat->hseqname}},$feat);
  }
    
  foreach my $key (keys %hash) {
    my @row = @{$hash{$key}};
    my $desc = $row[0]->idesc();
    my $href = $self->ID_URL( $URL_key, $key );

    my @rect = ();
    my $prsave;
    my ($minx, $maxx);

    my @row = @{$hash{$key}};
    foreach my $pr (@row) {
      my $x  = $pr->start();
      $minx  = $x if ($x < $minx || !defined($minx));
      my $w  = $pr->end() - $x;
      $maxx  = $pr->end() if ($pr->end() > $maxx || !defined($maxx));
      my $id = $pr->hseqname();
      push @rect, $self->Rect({
        'x'        => $x,
        'y'        => $y,
        'width'    => $w,
        'height'   => $h,
        'colour'   => $colour,
      });
      $prsave = $pr;
    }

    my $Composite = $self->Composite({
      'x'     => $minx,
      'y'     => 0,
      'href'  => $href,
      'zmenu' => {
      'caption' => $label." Domain",
        "01: $label: $key"     => $href,
        ($prsave->interpro_ac() ? ("02:InterPro: ".$prsave->interpro_ac, $self->ID_URL( 'INTERPRO', $prsave->interpro_ac ) ) : ()),
        ($prsave->idesc() ? ("03:".$prsave->idesc,'') : ()),
        "04:aa: $minx - $maxx"
      },
    });
    $Composite->push(@rect);

    ##### add a domain linker
    $Composite->push($self->Rect({
      'x'        => $minx,
      'y'        => $y + 2,
      'width'    => $maxx - $minx,
      'height'   => 0,
      'colour'   => $colour,
      'absolutey' => 1,
    }));

    #### add a label
    my $desc = $prsave->idesc() || $key;
    my @res = $self->get_text_width( 0, $desc, '', 'font'=>$fontname, 'ptsize' => $fontsize );
    $Composite->push($self->Text({
      'font'   => $fontname,
      'ptsize' => $fontsize,
      'halign' => 'left',
      'text'   => $desc,
      'x'      => $row[0]->start(),
      'y'      => $h,
      'height' => $th,
      'width'  => $res[2]/$pix_per_bp,
      'colour' => $colour,
      'absolutey' => 1
    }));

    if($depth>0) {
      my $bump_start = int($Composite->x() * $pix_per_bp);
      my $bump_end = $bump_start + int( $Composite->width / $pix_per_bp);
      $bump_start = 0            if $bump_start < 0;
      $bump_end = $bitmap_length if $bump_end > $bitmap_length;
      if( $bump_end > $bump_start ) {
        my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
        $Composite->y($Composite->y() + ( $row * ( 4 + $h + $th))) if $row;
      }
    }
    $self->push($Composite);
  }
}

1;
