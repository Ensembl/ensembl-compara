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

package EnsEMBL::Web::Document::HTML::Glossary;

### This module outputs a selection of FAQs for the help home page, 

use strict;
use warnings;

use EnsEMBL::Web::Component::Help::Glossary;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;

  my $component = EnsEMBL::Web::Component::Help::Glossary->new($self->hub);

  return $component->content;
}

1;
