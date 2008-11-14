package EnsEMBL::Web::Component::Gene::ExternalData;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Gene);

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
  my $msg1 = 'In the near future this page will display personal annotations '.
             'that you provide for a gene or transcript. This feature is currently in development.';
  my $msg2 = "Click 'configure this page' to change the sources of external ".
             "annotations that are available in the External Data menu.";
  my $html = $self->_info('Coming soon', $msg1, '100%') . $self->_info('Info', $msg2, '100%');
}

1;
