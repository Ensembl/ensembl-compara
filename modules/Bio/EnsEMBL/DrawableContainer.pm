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
 
sub dynamic_use {
  my($self, $classname) = @_;
  my( $parent_namespace, $module ) = $classname =~/^(.*::)(.*?)$/;
  no strict 'refs';
  return 1 if $parent_namespace->{$module.'::'}; # return if already required/imported or used
  eval "require $classname";
  if($@) {
    warn "DrawableContainer: failed to require $classname\nDrawableContainer: $@";
    return 0;
  }
  $classname->import();
  return 1;
}

1;
