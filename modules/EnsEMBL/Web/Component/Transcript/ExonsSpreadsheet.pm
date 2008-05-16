package EnsEMBL::Web::Component::Transcript::ExonsSpreadsheet;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

  

sub content {
  my $self = shift;
  my $object   = $self->object;
  my $html = ''; 

return $html;
}

1;

