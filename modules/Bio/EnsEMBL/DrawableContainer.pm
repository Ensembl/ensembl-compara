package Bio::EnsEMBL::DrawableContainer;
use strict;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);
use Sanger::Graphics::DrawableContainer;
our @ISA = qw(Sanger::Graphics::DrawableContainer);

sub species_defs { return $_[0]->{'config'}->{'species_defs'}; }

sub _init {
  my $class = shift;
  my $self = $class->SUPER::_init( @_ );
  $self->{'prefix'} = 'Bio::EnsEMBL';
  return $self;
} 
 
sub debug {
  my( $self, $pos, $tag ) = @_;
  $tag = "$ENV{'ENSEMBL_SCRIPT'}_$tag";
  if( $pos eq 'start' ) {
    $self->species_defs->{'timer'}->push( "AA".$tag,5 ) if $self->species_defs->{'timer'};
    &eprof_start( $tag ) if $self->species_defs->ENSEMBL_DEBUG_FLAGS & 32;
  } else {
    $self->species_defs->{'timer'}->push( "BB".$tag,5 ) if $self->species_defs->{'timer'};
    &eprof_end( $tag ) if $self->species_defs->ENSEMBL_DEBUG_FLAGS & 32;
  }
}

1;
