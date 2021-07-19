=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
