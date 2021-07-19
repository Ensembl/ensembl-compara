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

package EnsEMBL::Web::Configuration::Marker;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Details';
}

sub caption { 
  my $self = shift;
  my $marker = $self->hub->param('m');
  return "Marker $marker"; 
}

sub availability {
  my $self = shift;
  return $self->default_availability;
}

sub populate_tree {
  my $self  = shift;
  $self->create_node('Details', 'Details', [qw(details EnsEMBL::Web::Component::Marker::Details)]);
}

1;
