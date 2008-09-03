package Bio::EnsEMBL::GlyphSet::Vsnps;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  my $Config    = $self->{'config'};
  my $chr       = $self->{'container'}->{'chr'};
  my $chr_slice = $self->{'container'}->{'sa'}->fetch_by_region('chromosome', $chr);
  my $snps      = $self->{'container'}->{'da'}->fetch_Featureset_by_Slice( $chr_slice,'snpDensity', 150, 1 );
  return unless $snps->size(); 
  my $snps_col = $Config->get( 'Vsnps','col' );
  $snps->scale_to_fit( $Config->get( 'Vsnps', 'width' ) );
  $snps->stretch(0);
  my @snps = @{$snps->get_all_binvalues()};
  foreach (@snps){
    my $g_x = $self->Rect({
      'x' => $_->start,
      'y'      => 0,
			'width'  => $_->end -$_->start,
			'height' => $_->scaledvalue,
			'bordercolour' => $snps_col,
			'absolutey' => 1,
			'href'   => "/@{[$self->{container}{web_species}]}/contigview?chr=$chr;vc_start=$_->start;vc_end=$_->end"
		});
	    $self->push($g_x);
	}
}

1;
