package EnsEMBL::Web::Component::UserData;

## Placeholder - no generic methods needed as yet

use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Form;
use base qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

sub is_configurable {
  my $self = shift;
  ## Can we do upload/DAS on this page?
  my $flag = 0;
  my $referer = $self->object->param('_referer');
  my @path = split(/\//, $referer);
  my $type = $path[2];
  if ($type eq 'Location' || $type eq 'Gene' || $type eq 'Transcript') {
    (my $action = $path[3]) =~ s/\?(.)+//;
    my $vc = $self->object->session->getViewConfig( $type, $action);
    $flag = 1 if $vc && $vc->can_upload;
  }
  return $flag;
}

1;

