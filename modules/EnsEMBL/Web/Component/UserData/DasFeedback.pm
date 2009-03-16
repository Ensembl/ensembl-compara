package EnsEMBL::Web::Component::UserData::DasFeedback;

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
  return 'Attached DAS sources';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = EnsEMBL::Web::Form->new('das_feedback', '', 'post');

  my $das     = $self->object->get_session->get_all_das;
  my @added   = grep {$_} $self->object->param('added');
  my @skipped = grep {$_} $self->object->param('skipped');

  if( @added > 0 ) {
    $form->add_element( 'type' => 'SubHeader', 'value' => 'The following DAS sources have now been attached:' );
    foreach my $logic_name (@added) {
      my $source = $das->{$logic_name};
      if( $source ) {
        $form->add_element(
          'type' => 'Information', 'classes' => ['no-bold'],
          'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
            $source->label,
            $source->description,
            $source->homepage
        );
      } else {
        $form->add_element( 'type' => 'Information', 'value' => $logic_name);
      }
    }
    $form->add_element( 'type' => 'ForceReload' );
  }
  if( @skipped > 0 ) {
    $form->add_element( 'type' => 'SubHeader', 'value' => 'The following DAS sources could not be attached:' );
    foreach my $logic_name (@skipped) {
      my $source = $das->{$logic_name};
      if ($source) {
        $form->add_element(
          'type' => 'Information', 'classes' => ['no-bold'],
          'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
            $source->label,
            $source->description,
            $source->homepage
        );
      } else {
        $form->add_element( 'type' => 'Information', 'value' => $logic_name);
      }
    }
  }
  return $form->render;
}

1;
