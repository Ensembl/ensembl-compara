package EnsEMBL::Web::Component::UserData::DasSources;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Filter::DAS;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Select a DAS source';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $form;

  my $url = $object->species_path($object->data_species).'/UserData/ValidateDAS';
  my $elements = [];

  $form = $self->modal_form('select_das', $url, {'wizard' => 1, 'buttons_on_top' => 1, 'buttons_align' => 'centre'});
  my $fieldset = $form->add_fieldset({'name' => 'sources', 'stripes' => 1});

  my $count_added;
  my @all_das = $self->hub->get_all_das;

  my $filter = EnsEMBL::Web::Filter::DAS->new({'object' => $object});
  my $sources = $filter->catch($object->param('das_server'));

  for my $source (@{ $sources }) {
    my $already_added = 0;
    ## If the source is already in the speciesdefs/session/user, skip it
    if ( $all_das[1]->{ $source->full_url } ) {
      $already_added = 1;
      $count_added++;
    }
    $fieldset->add_element(
         'type'     => 'DASCheckBox',
         'das'      => $source,
         'disabled' => $already_added,
         'checked'  => $already_added,
    );
  }
  if ( $count_added ) {
    my $noun    = $count_added > 1 ? 'sources' : 'source';
    my $verb    = $count_added > 1 ? 'are' : 'is';
    my $subject = $count_added > 1 ? 'they' : 'it';
    my $note = sprintf '%d DAS %s cannot be selected here because %s %s already configured within %s.',
                       $count_added, $noun, $subject, $verb,
                       $self->object->species_defs->ENSEMBL_SITETYPE;
    $form->add_notes( {'heading'=>'Note', 'text'=> $note } );
  }

  $form->add_element('type'  => 'Hidden','name'  => 'das_server','value' => $object->param('das_server'));
  return $form->render;
}


1;
