package EnsEMBL::Web::Component::LRG::LRGSummary;

use strict;
use warnings;
no warnings "uninitialized";

use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component::LRG);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self  = shift;
  my $label = 'Prediction Method';
  my $text  = 'Data from LRG database';

  return $self->new_twocol([$label, $text])->render;
}


1;
