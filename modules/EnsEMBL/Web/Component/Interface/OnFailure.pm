package EnsEMBL::Web::Component::Interface::OnFailure;

### Module to create generic database feedback for Document::Interface and its associated modules

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Interface);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return $self->object->interface->caption('on_failure') || 'Database Update Failed';
}

sub content {
  my $self = shift;
  my $html;
  my $content = $self->object->interface->panel_content('on_failure');
  unless ($html = $content) {
    $html = qq(<p>Sorry, there was a problem saving your changes.</p>);
  }
  return $html;
}

1;
