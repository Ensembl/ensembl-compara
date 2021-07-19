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

package EnsEMBL::Web::Configuration::Search;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub has_tabs { return 1; }

sub query_string   { return ''; }

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'New';
}

sub populate_tree {
  my $self = shift;
  
  $self->create_node('New',     'New Search',      [qw(new EnsEMBL::Web::Component::Search::New)],          {'title' => 'Search'});
  $self->create_node('Results', 'Results Summary', [qw(results EnsEMBL::Web::Component::Search::Results)],  {'title' => 'Search'});
}

1;
