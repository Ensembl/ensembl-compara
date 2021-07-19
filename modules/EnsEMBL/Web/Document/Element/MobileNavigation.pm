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

package EnsEMBL::Web::Document::Element::MobileNavigation;

# Alternative to the left sided navigation menu, shown on mobile devices

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element::Navigation);

sub content {
  my $self = shift;
  my $tree = $self->tree;
  
  return unless $tree;
  
  my $active = $self->active;
  my @nodes  = grep { $_->can('data') && !$_->data->{'no_menu_entry'} && $_->data->{'caption'} } @{$tree->root->child_nodes};
  my $menu;
  
  if ($tree->get_node($active) || $nodes[0]) {
    $menu .= $_->render for @nodes;
  }
  
  return sprintf('
    <div id="mobile_context">
      <h2>%s</h2>
      <ul class="mobile_context">%s</ul>
    </div>',
    encode_entities($self->strip_HTML($self->caption)),
    $menu
  );
}

1;
