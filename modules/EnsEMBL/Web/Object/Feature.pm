#$Id$
package EnsEMBL::Web::Object::Feature;

use strict;

use base qw(EnsEMBL::Web::Object);

sub features { return $_[0]->Obj->{$_[1]}; }

sub get_feature_by_id {
  my ($self, $type, $param, $id) = @_;
  foreach (@{$self->Obj->{$type}->data_objects||[]}) {
    return $_->[0] if $_->[0]->$param eq $id;
  }
}

sub feature_types {
  return keys %{$_[0]->Obj};
}

sub convert_to_drawing_parameters {
  my ($self, $type) = @_;
  
  return $self->features($type)->convert_to_drawing_parameters if $type;
  
  my %drawable = map { $_ => $self->features($_)->convert_to_drawing_parameters } $self->feature_types;
  return \%drawable;
}

1;
