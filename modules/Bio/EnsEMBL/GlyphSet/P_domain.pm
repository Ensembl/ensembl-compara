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
  my $protein       = $self->{'container'};
  return unless $protein->dbID;

  $self->_init_bump;

  my $label         = $self->my_config( 'caption'    ) || uc($logic_name);
  my $depth         = $self->my_config( 'depth'      );
  my $h             = $self->my_config( 'height'     ) || 4;
  my $th            = $self->get_textheight;
  my $pix_per_bp    = $self->scalex;
  my $y             = 0;

#warn ">>> $logic_name <<<";

  foreach my $logic_name { @{$self->my_config( 'logic_name' )||[]} } {
    my %hash;
    my @ps_feat = @{$protein->get_all_ProteinFeatures( $logic_name )};
    push @{$hash{$_->hseqname}},$_ foreach @ps_feat;

    foreach my $key (keys %hash) {
      my $href = $self->ID_URL( $logic_name, $key );
      my( @rect, $prsave, $minx, $maxx );
      foreach my $pr (@{$hash{$key}}) {
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
        $prsave ||= $pr;
      }
      my $title =  sprintf '%s domain: %s; Positions: %d-%d', $label, $key, $minx, $maxx;
         $title .= '; Interpro: '. $prsave->interpro_ac if $prsave->interpro_ac;
         $title .= '; '.$prsave->idesc                  if $prsave->idesc;
      my $Composite = $self->Composite({
        'x'     => $minx,
        'y'     => 0,
        'href'  => $href,
        'title' => $title
      },
    });
    $Composite->push(@rect,
      $Composite->push($self->Rect({
        'x'        => $minx,
        'y'        => $y + $h/2,
        'width'    => $maxx - $minx,
        'height'   => 0,
        'colour'   => $colour,
        'absolutey' => 1,
      })
    );

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
      my $bump_end   = $bump_start + int( $Composite->width / $pix_per_bp );
      my $rowa       = $self->bump_row( $bump_start, $bump_end );
      $Composite->y($Composite->y() + ( $row * ( 4 + $h + $th))) if $row;
    }
    $self->push($Composite);
  }
}

1;
