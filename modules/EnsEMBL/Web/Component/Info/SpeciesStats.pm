package EnsEMBL::Web::Component::Info::SpeciesStats;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  return 'Statistics';
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $html; 

  my $file = '/'.$object->species.'/ssi/stats.html';
  $html .= EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, $file);

  return $html;
}

1;
