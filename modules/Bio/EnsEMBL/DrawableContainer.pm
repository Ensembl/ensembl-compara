package Bio::EnsEMBL::DrawableContainer;
use strict;
use Sanger::Graphics::DrawableContainer;
@Bio::EnsEMBL::DrawableContainer::ISA=qw(Sanger::Graphics::DrawableContainer);

sub _init {
  my $class = shift;
  my $self = $class->SUPER::_init( @_ );
  $self->{'prefix'} = 'Bio::EnsEMBL';
  return $self;
} 
 
1;
