package Bio::EnsEMBL::GlyphSet::TSE_generic_match_label;
use strict;
use Bio::EnsEMBL::GlyphSet;
@Bio::EnsEMBL::GlyphSet::TSE_generic_match_label::ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  my $Config      = $self->{'config'};
  my $height  = $Config->get('spacer','height') || 20;
  $self->push( $self->Space({
    'x'      	=> 1,
    'y'      	=> 0,
    'width'  	=> 1,
    'height' 	=> $height,
    'absolutey' => 1,
    'absolutex' => 1,
  }));
}
1;
