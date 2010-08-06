package EnsEMBL::Web::Component::Info::IPtop40;

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::Apache::SendDecPage;
use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self   = shift;
  my $html; 

  my $file = '/ssi/species/stats_'.$self->hub->species.'_IPtop40.html';
  $html .= EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, $file);

  return $html;
}

1;
