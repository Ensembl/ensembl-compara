package EnsEMBL::Web::Component::UserData::RemoteFeedback;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'URL attached';
}

sub content {
  my $self = shift;
  
  my $form = $self->new_form({'id' => 'url_feedback', 'method' => 'post'});

  $form->add_element(
      type  => 'Information',
      value => qq(Thank you - your remote data was successfully attached. Close this Control Panel to view your data),
    );
  $form->add_element( 'type' => 'ForceReload' );

  return $form->render;
}

1;
