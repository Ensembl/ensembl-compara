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

package EnsEMBL::Web::Component::UserData::SelectServer;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption { return 'Select a DAS server or data file'; }

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $preconf  = $hub->param('preconf_das');
  my $other    = $hub->param('other_das');
  my $filter   = $hub->param('das_name_filter');
  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE; 
  my $form     = $self->modal_form('select_server', $hub->url({ action => 'CheckServer', __clear => 1 }), { wizard => 1, no_back_button => 1 });
  
  $form->add_notes({
    heading => 'Tip',
    text    => sprintf('
      <p>
        %s supports the <a href="/info/docs/das/index.html">Distributed Annotation System</a>, 
        a network of data sources accessible over the web. DAS combines the advantages of 
        <a href="%s" class="modal_link">URL</a> and <a href="%s" class="modal_link">upload</a> data, but requires special software.
      </p>',
      $sitename,
      $hub->url({ function => 'AttachURL', __clear => 1 }),
      $hub->url({ function => 'Upload',    __clear => 1 })
    )
  });
  
  # DAS server section
  $form->add_field([{
    type   => 'dropdown',
    name   => 'preconf_das',
    select => 'select',
    label  => "$sitename DAS sources",
    values => [ $self->object->get_das_servers ],
    value  => $preconf
  }, {
    type  => 'URL',
    name  => 'other_das',
    label => 'or other DAS server',
    size  => '30',
    value => $other,
    notes => '(e.g. http://www.example.com/MyProject/das)'
  }, {
    type  => 'String',
    name  => 'das_name_filter',
    label => 'Filter sources',
    size  => '30',
    value => $filter,
    notes => 'by name, description or URL'
  }]);
  
  $form->add_notes('Please note that the next page may take a few moments to load.');
  
  return $form->render;
}

1;
