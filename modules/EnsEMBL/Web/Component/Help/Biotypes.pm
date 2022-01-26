=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Help::Biotypes;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable( 0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my %biotypes = $hub->species_defs->multiX('ENSEMBL_BIOTYPES');
  my $rendered_term_tree = render_term(\%biotypes);

  return "<ul>$rendered_term_tree</ul>"
}

sub render_term {
  my $term = shift;

  my $label = $term->{label};
  my $description = join ' ', @{$term->{description}}; # description field is an array;
  my $rendered_children = '';
  my $children = $term->{children};

  if ($children and scalar(@{$children})) {
    $rendered_children = render_children($children);
  }
 
  my $html = "<li><strong>$label:</strong> $description $rendered_children</li>";
  return $html;
}

sub render_children {
  my $children = shift;
  my $rendered_children = '';

  my @sorted_children = sort { $a->{label} cmp $b->{label} } @{$children};
  
  foreach my $term (@sorted_children) {
    $rendered_children = $rendered_children . render_term($term);
  }

  return "<ul>$rendered_children</ul>";
}

1;
