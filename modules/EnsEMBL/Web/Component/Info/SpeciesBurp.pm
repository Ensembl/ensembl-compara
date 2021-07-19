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

package EnsEMBL::Web::Component::Info::SpeciesBurp;

use strict;

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Controller::SSI;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self           = shift;
  my %error_messages = EnsEMBL::Web::Constants::ERROR_MESSAGES;
  my $error_text     = $error_messages{$self->hub->function};

  my $img; # = $self->hub->function eq '404' ? '<img src="/i/monster.png" class="float-right" alt="Here Be Monsters" title="A monster from a 17th century bestiary" />' : '';

  return sprintf '%s<h3>%s</h3><p>%s</p>%s',
    $img,
    $error_text->[0],
    $error_text->[1],
    EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, '/ssi/species/ERROR_4xx.html')
  ;
}

1;
