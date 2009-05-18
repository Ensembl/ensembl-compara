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
  
  ## Catch any errors at the server end
  my $server = $object->param('other_das') || $object->param('preconf_das');
  my $filter = EnsEMBL::Web::Filter::DAS->new({'object' => $object});
  my $sources = $filter->catch($server);
  my $form;

  my $url = '/'.$object->data_species.'/UserData/';
  if ($filter->error_code) {
    $form = $self->modal_form('select_das', $url.'SelectServer', {'wizard' => 1});
    $object->param('filter_module', 'DAS');
    $object->param('filter_code', $filter->error_code);
  }
  else {
    my $fieldset = {'name' => 'sources'};
    my $elements = [];

    $form = $self->modal_form('select_das', $url.'ValidateDAS', {'wizard' => 1});
    $form->extra_buttons('top'); ## Repeat buttons at top, as this is often a long form

    $fieldset->{'stripes'} = 1;
    my $count_added;
    my @all_das = $ENSEMBL_WEB_REGISTRY->get_all_das();

    for my $source (@{ $sources }) {
      my $already_added = 0;
      ## If the source is already in the speciesdefs/session/user, skip it
      if ( $all_das[1]->{ $source->full_url } ) {
        $already_added = 1;
        $count_added++;
      }

      push @$elements, { 'type'     => 'DASCheckBox',
                         'das'      => $source,
                         'disabled' => $already_added,
                         'checked'  => $already_added  };
    } 

    if ( $count_added ) {
      my $noun    = $count_added > 1 ? 'sources' : 'source';
      my $verb    = $count_added > 1 ? 'are' : 'is';
      my $subject = $count_added > 1 ? 'they' : 'it';
      my $note = sprintf '%d DAS %s %s cannot be selected here because %s %3$s already configured within %s.',
                         $count_added, $noun, $verb, $subject,
                         $self->object->species_defs->ENSEMBL_SITETYPE;
      $form->add_notes( {'heading'=>'Note', 'text'=> $note } );
    }

    $fieldset->{'elements'} = $elements;
    $form->add_fieldset(%$fieldset);
    $form->add_element('type'  => 'Hidden','name'  => 'das_server','value' => $server);
  }
  return $form->render;
}


1;
