=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::RegulationBase;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub _add_nav_entries {
  my ($self,$evidence) = @_;

  my @zmenu_links = qw(regulation_view);

  my $config = $self->hub->param('config');
  if(grep { $config eq $_ } @zmenu_links) {
    my $cell_type_url = $self->hub->url('Component', {
      type => 'Regulation',
      action   => 'Web',
      function    => 'CellTypeSelector/ajax',
      image_config => $config,
    });
    my $evidence_url = $self->hub->url('Component', {
      type => 'Regulation',
      action => 'Web',
      function => 'EvidenceSelector/ajax',
      image_config => $config,
    });
    $self->add_entry({ label => "Select other cell types", link => $cell_type_url, link_class => 'modal_link' });
    $self->add_entry({ label => "Select evidence to show", link => $evidence_url, link_class => 'modal_link' });
  }
  if($evidence&1) {
    my $signal_url = $self->hub->url({
      action => $self->hub->param('act'),
      plus_signal => $config,
    });
    $self->add_entry({ label => "Also show raw signal", link => $signal_url });
  }
}

1;

