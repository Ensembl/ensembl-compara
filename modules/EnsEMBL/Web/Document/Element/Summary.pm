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

package EnsEMBL::Web::Document::Element::Summary;

# Generates the top summary panel in dynamic pages

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub init {
  my $self        = shift;
  my $controller  = shift;
  my $hub         = $self->hub;
  my $object      = $controller->object;
  my $caption     = $object ? $object->caption : $controller->configuration->caption;
  my ($component) = map { $_->[2] eq 'summary' ? "EnsEMBL::Web::Component::$_->[1]::$_->[0]" : () } @{$hub->components};
     $component ||= sprintf 'EnsEMBL::Web::Component::%s::Summary', $hub->type;
  
  return unless $self->dynamic_use($component);
  
  my $panel = $self->new_panel('Summary',
    $controller,
    code    => 'summary_panel',
    caption => $caption
  );
  
  $panel->add_component('summary', $component);
  $controller->page->content->add_panel($panel);
}

1;