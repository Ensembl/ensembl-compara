package Bio::EnsEMBL::DrawableContainer;
use strict;
use EnsWeb;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);
use Sanger::Graphics::DrawableContainer;
@Bio::EnsEMBL::DrawableContainer::ISA=qw(Sanger::Graphics::DrawableContainer);

sub _init {
  my $class = shift;
  my $self = $class->SUPER::_init( @_ );
  $self->{'prefix'} = 'Bio::EnsEMBL';
  return $self;
} 
 
sub debug {
  my( $class, $pos, $tag ) = @_;
  $tag = "$ENV{'ENSEMBL_SCRIPT'}_$tag";
  if( $pos eq 'start' ) {
    &eprof_start( $tag ) if $EnsWeb::species_defs->ENSEMBL_DEBUG_FLAGS & 32;
  } else {
    &eprof_end( $tag ) if $EnsWeb::species_defs->ENSEMBL_DEBUG_FLAGS & 32;
  }
}
1;
