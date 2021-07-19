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

package EnsEMBL::Web::Component::Help::Search;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;
  my $html = qq(<h3>Search $sitename Help</h3>);

  my $dir = $hub->species_path;
  $dir = '' if $dir !~ /_/;
  my $form = EnsEMBL::Web::Form->new( 'help_search', "$dir/Help/DoSearch", 'get' );

  $form->add_element(
    'type'    => 'String',
    'name'    => 'string',
    'label'   => 'Search for',
  );

  $form->add_element(
    'type'    => 'CheckBox',
    'name'    => 'hilite',
    'label'   => 'Highlight search term(s)',
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Go',
    'class'   => 'modal_link',
  );

  $html .= $form->render;

  $html .= qq(
  <h4>Search Tips</h4>
<p>Ensembl Help now uses MySQL full text searching. This performs a case-insensitive natural language search
on the content of the help database. This gives better results than a simple string search, with some caveats:</p>
<ul>
<li>Words that occur in more than 50% of the records are ignored.</li>
<li>Wildcards such as '%' (zero or one occurences of any character) and '_' (exactly one character) are no longer available.</li>
</ul>
);

  return $html;
}

1;
