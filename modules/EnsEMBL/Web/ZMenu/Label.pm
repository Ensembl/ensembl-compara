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

package EnsEMBL::Web::ZMenu::Label;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

use JSON qw(from_json);

# These *_content should probably end up as packages if we get enough of
#   them, say three or more.
sub regulation_content {
  my ($self,$data,$context) = @_;
  my $hub = $self->hub;

  my $cell_line = $data->{'cell_line'};
  return unless $cell_line;

  my $fg_dba = $hub->database('funcgen');
  my $fg_cta = $fg_dba->get_CellTypeAdaptor;
  my $fg_ct = $fg_cta->fetch_by_name($cell_line);
 
  $self->caption('Cell Type');
  $self->add_entry({ type => "Cell Type", label => $cell_line });
  $self->add_entry({ type => "Description", label => $fg_ct->description });

  if(grep { $_ eq $context->{'image_config'} } qw(regulation_view)) {
    my $cell_type_url = $self->hub->url('Component', {
      type => 'Regulation',
      action   => 'Web',
      function    => 'CellTypeSelector/ajax',
      image_config => $context->{'image_config'},
    });
    my $evidence_url = $self->hub->url('Component', {
      type => 'Regulation',
      action => 'Web',
      function => 'EvidenceSelector/ajax',
      image_config => $context->{'image_config'},
    });
    $self->add_entry({ label => "Select other cell types", link => $cell_type_url, link_class => 'modal_link' });
    $self->add_entry({ label => "Select evidence shown", link => $evidence_url, link_class => 'modal_link' });
  }
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $zmdata = from_json($hub->param('zmdata'));
  my $zmcontext = from_json($hub->param('zmcontext'));

  $self->header(' ');
  foreach my $data (@{$zmdata||[]}) {
    $self->new_feature;
    my $type = $data->{'type'};
    if($type eq 'regulation') {
      $self->regulation_content($data,$zmcontext);
    }
  }

}

1;
