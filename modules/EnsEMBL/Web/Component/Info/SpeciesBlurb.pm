package EnsEMBL::Web::Component::Info::SpeciesBlurb;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::Apache::SendDecPage;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}


sub content {
  my $self   = shift;
  my $object = $self->object;
  my $html; 

  my $file = '/ssi/species/about_'.$object->species.'.html';
  $html .= EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, $file); 

  return $html;
}

1;
