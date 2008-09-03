package Bio::EnsEMBL::GlyphSet::Vgenes;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

use Data::Dumper;

sub _init {
  my ($self) = @_;
  my $Config = $self->{'config'};
  my $chr    = $self->{'extras'}->{'chr'} || $self->{'container'}->{'chr'};
  my $genes_col = $Config->get( 'Vgenes','col_genes' );
  my $known_col = $Config->get( 'Vgenes','col_known' );

  my $slice_adapt   = $self->{'container'}->{'sa'};
  my $density_adapt = $self->{'container'}->{'da'};

  my $chr_slice = $slice_adapt->fetch_by_region('chromosome', $chr);
  my $known_genes = $density_adapt->fetch_Featureset_by_Slice
    ($chr_slice,'knownGeneDensity', 150, 1);
  my $genes = $density_adapt->fetch_Featureset_by_Slice
    ($chr_slice,'geneDensity', 150, 1);

  my $v_offset = $Config->container_width() - ($chr_slice->length() || 1);

  return unless $known_genes->size() && $genes->size();

  $genes->scale_to_fit( $Config->get( 'Vgenes', 'width' ) );
  $genes->stretch(0);
  my $Hscale_factor = $known_genes->max_value / ($genes->max_value || 1 );
  $known_genes->scale_to_fit( $Config->get( 'Vgenes', 'width' ) * $Hscale_factor );  
  $known_genes->stretch(0);
  my @genes = @{$genes->get_all_binvalues()};
  my @known_genes = @{$known_genes->get_all_binvalues()};  

  foreach (@genes){
    my $known_gene = shift @known_genes;  
    my $g_x = $self->Rect({
      'x'      => $v_offset + $known_gene->start,
      'y'      => 0,
      'width'  => $known_gene->end - $known_gene->start,
      'height' => $known_gene->scaledvalue,
      'colour' => $known_col,
      'absolutey' => 1,
    });
    $self->push($g_x);
    $g_x = $self->Rect({
      'x'      => $v_offset + $_->start,
      'y'      => 0,
      'width'  => $_->end - $_->start,
      'height' => $_->scaledvalue,
      'bordercolour' => $genes_col,
      'absolutey' => 1,
      'href'   => "/@{[$self->{container}{web_species}]}/contigview?chr=$chr;vc_start=$_->start;vc_end=$_->end"
    });
    $self->push($g_x);
  }
  
}

1;
