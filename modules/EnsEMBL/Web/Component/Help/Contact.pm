=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Help::Contact;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Component::Help);

use EnsEMBL::Web::Utils::HoneyPot qw(spam_protect_form);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {

  my $self  = shift;
  my $hub   = $self->hub;

  ## Where did the user come from?
  my ($path, $query) = split('\?', $ENV{'HTTP_REFERER'});
  my @A = split('/', $path);
  my $source = $A[-1];

  my $form      = $self->new_form({'id' => 'contact', 'class' => 'compact', 'action' => "/Help/SendEmail", 'method' => 'post', 'enctype'=>'multipart/form-data', 'data-ajax'=>'false'});
  my $fieldset  = $form->add_fieldset;

  if ($hub->param('strong')) {
    $fieldset->add_notes(sprintf('Sorry, no pages were found containing the term <strong>%s</strong> (or more than 50% of articles contain this term).
                        Please <a href="/Help/Search">try again</a> or use the form below to contact HelpDesk:', $hub->param('kw')));
  }
  
  $fieldset->add_field([{
    'type'    => 'String',
    'name'    => 'name',
    'label'   => 'Your name',
    'value'   => $hub->param('name') || '',
  }, {
    'type'    => 'Honeypot',
    'name'    => 'email',
    'label'   => 'Address',
  }, {
    'type'    => 'Email',
    'name'    => 'address',
    'label'   => 'Your Email',
    'value'   => $hub->param('address') || '',
  }, {
    'type'    => 'String',
    'name'    => 'subject',
    'label'   => 'Subject',
    'value'   => $hub->param('subject') || '',
  }, {
    'type'    => 'Honeypot',
    'name'    => 'comments',
    'label'   => 'Comments',
  }, {
    'type'    => 'Text',
    'name'    => 'message',
    'label'   => 'Message',
    'value'   => $hub->param('message') || '',
    'notes'   => 'Tip: drag the bottom righthand corner to make this box bigger.',
  }, {
    'type'    => 'File',
    'name'    => 'attachment',
    'label'   => 'Include a file or screenshot (optional)',
    'value'   => '',
  }]);
  
  $fieldset->add_hidden({
    'name'    => 'string',
    'value'   => $hub->param('string') || '',
  });

  $fieldset->add_hidden({
    'name'    => 'source',
    'value'   => $source || '',
  });

  $fieldset->add_button({
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Send',
  });

  spam_protect_form($hub,$form);

  $_->set_attribute('data-role', 'none') for @{$fieldset->get_elements_by_tag_name([qw(input select textarea)])};

  return $form->render;
}

1;
