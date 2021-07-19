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

package EnsEMBL::Web::Document::HTML::HelpSearch;

### This module outputs help search form for help & faq page 

use strict;

use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {

  my $form      = EnsEMBL::Web::Form->new({'id' => 'helpsearch', 'action' => '/Help/DoSearch', 'name' => 'helpsearch', 'class' => 'search-form'});
  my $fieldset  = $form->add_fieldset({'no_required_notes' => 1});
  $fieldset->add_field({
    'label'     => '<b>Search for</b>',
    'type'      => 'string',
    'name'      => 'string',
    'size'      => '20',
    'required'  => 1
  });
  $fieldset->add_field({
    'type'      => 'checklist',
    'name'      => 'hilite',
    'values'    => [{
      'value'     => 'yes',
      'caption'   => {'inner_HTML' => '<b>Highlight search term(s)</b>'}
    }]
  });
  $fieldset->add_button({
    'name'      => 'submit',
    'value'     => 'Go',
    'class'     => 'submit'
  });

  $_->set_attribute('data-role', 'none') for @{$form->get_elements_by_tag_name('input')};

  return $form->render;
}

1;
