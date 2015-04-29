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

  # Also catch duplicates by logicname (DECIPHER has different URL on mirrors)
  my %logic_name;
  $logic_name{$_} = 1 for(map { $_->logic_name } values %{$all_das[1]});
  #  

  for my $source (@{ $sources }) {
    my $already_added = 0;
    ## If the source is already in the speciesdefs/session/user, skip it
    if ( $all_das[1]->{ $source->full_url } or exists $logic_name{$source->logic_name} ) {
      $already_added = 1;
      $count_added++;
    }
    $fieldset->add_element({
         'type'     => 'DASCheckBox',
         'das'      => $source,
         'disabled' => $already_added,
         'checked'  => $already_added,
    });
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
