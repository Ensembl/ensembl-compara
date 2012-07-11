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

  return $form->render;
}

1;
