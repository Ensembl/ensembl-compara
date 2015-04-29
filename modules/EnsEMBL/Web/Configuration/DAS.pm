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

package EnsEMBL::Web::Configuration::DAS;

use strict;

use EnsEMBL::Web::Document::Panel;

use base qw(EnsEMBL::Web::Configuration);

sub get_valid_action {
  my $self   = shift;
  my $action = shift;
  my $func   = shift;
  return $func ? "$action/$func" : "action";
}

sub stylesheet   { $_[0]->new_panel('DASSTYLE',    'EnsEMBL::Web::Component::DAS::Annotation::stylesheet');  }
sub features     { $_[0]->new_panel('DASGFF',      'EnsEMBL::Web::Component::DAS::features');                }
sub types        { $_[0]->new_panel('DASTYPES',    'EnsEMBL::Web::Component::DAS::types');                   }
sub sequence     { $_[0]->new_panel('DASSEQUENCE', 'EnsEMBL::Web::Component::DAS::Reference::sequence');     }
sub entry_points { $_[0]->new_panel('DASEP',       'EnsEMBL::Web::Component::DAS::Reference::entry_points'); } # Only applicable to a reference server
sub dna          { $_[0]->new_panel('DASDNA',      'EnsEMBL::Web::Component::DAS::Reference::dna');          } # Only applicable to a reference server


sub new_panel {
  my $self      = shift;
  my $page      = $self->page;
  my $das_panel = EnsEMBL::Web::Document::Panel->new(
    hub     => $self->hub,
    builder => $self->builder,
    object  => $self->object,
    code    => 'das'
  );
  
  $page->set_doc_type('XML', shift);
  $das_panel->add_components('das_features', shift);
  $page->content->add_panel($das_panel);
}

1;
