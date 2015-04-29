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

package EnsEMBL::Web::ImageConfig::reg_summary_page;

use strict;
use warnings;

use base qw(EnsEMBL::Web::ImageConfig::reg_detail);

sub init {
  my $self = shift;

  $self->SUPER::init(@_);
 
  foreach my $type (qw(seg_features reg_feats_core reg_feats_non_core)) { 
    my $submenu = $self->get_node($type);
    next unless $submenu;
    foreach my $node (@{$submenu->child_nodes}) {
      $self->modify_configs([$node->id],{ display => 'off' });  
    }
  }
}

1;
