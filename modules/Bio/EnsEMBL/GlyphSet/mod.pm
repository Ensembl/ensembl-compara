package Bio::EnsEMBL::GlyphSet::mod;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == 1);
  return unless my $mod = $self->species_defs->ENSEMBL_MOD;

  my ($w,$h) = $self->{'config'}->texthelper()->real_px2bp('Small');
  $self->push($self->Text({
    'x'         => int( ($self->{'container'}->length - $w * length($mod))/2 ),, 
    'y'         => 0,
    'height'    => $h,
    'font'      => 'Small',
    'colour'    => 'red3',
    'text'      => $mod,
    'absolutey' => 1,
  }));
}

1;
        
