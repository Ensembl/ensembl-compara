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

package EnsEMBL::Web::Document::Content;

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  my ($class, $args) = @_;
  
  my $self = {
    %$args,
    panels => []
  };
  
  bless $self, $class;
  
  return $self;
}

sub add_panel {
  my ($self, $panel) = @_;
  push @{$self->{'panels'}}, $panel;
}

sub panel {
  my ($self, $code) = @_;
  
  foreach (@{$self->{'panels'}}) {
    return $_ if $code eq $_->{'code'};
  }
  
  return undef;
}

sub content {
  my $self = shift;
  my $content;
  
  foreach my $panel (@{$self->{'panels'}}) {
    next if $panel->{'code'} eq 'summary_panel';
    
    $panel->{'disable_ajax'} = 1;
    $panel->renderer = $self->renderer;
    $content .= $panel->component_content;
  }
  
  return $content;
}

sub init {
  my $self       = shift;
  my $controller = shift;
  my $node       = $controller->node;
  
  return unless $node;
  
  my $hub           = $controller->hub;
  my $object        = $controller->object;
  my $configuration = $controller->configuration;
  
  $configuration->{'availability'} = $object ? $object->availability : {};

  my %params = (
    object      => $object,
    code        => 'main',
    omit_header => 1
  );
  
  my $panel = $self->new_panel('Navigation', $controller, %params);
   
  if ($panel) {
    $panel->add_components(@{$node->data->{'components'}});
    $self->add_panel($panel);
  }
}

1;
