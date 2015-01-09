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

package EnsEMBL::Web::Component::UserData::SelectRemote;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $current_species = $object->species_path($object->data_species);
  my $form = $self->modal_form('select_url', "$current_species/UserData/AttachRemote", {'wizard' => 1, 'no_back_button' => 1});
  my $user = $object->user;
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;

  # URL-based section
  my $format_info = $self->hub->species_defs->multi_val('DATA_FORMAT_INFO');
  my %format_name = map {$format_info->{$_}{'label'} => 1} (@{$self->hub->species_defs->multi_val('UPLOAD_FILE_FORMATS')}, @{$self->hub->species_defs->multi_val('REMOTE_FILE_FORMATS')});
  my $format_list = join(', ', (sort {lc($a) cmp lc($b)} keys %format_name));

  my $note = sprintf qq(
    <p>Accessing data via a URL can be slow unless you use an indexed format such as BAM. However it has the advantage that you always see the same data as the file on your own machine.</p>
    <p>We currently accept attachment of the following formats: $format_list.%s</p>), grep(/vcf/i, keys %format_name) ? ' <b>Note</b>: VCF files must be indexed prior to attachment.' : ''
  ;

  $form->add_notes({
    'heading' => 'Tip',
    'text'    => $note
  });

  $form->add_field([{
    'type'      => 'url',
    'name'      => 'url',
    'label'     => 'File URL',
    'size'      => '30',
    'value'     => $object->param('url') || '',
    'notes'     => '( e.g. http://www.example.com/MyProject/mydata.gff )'
  }]);

  $self->add_file_format_dropdown($form);

  $form->add_field([{
    'type'      => 'string',
    'name'      => 'name',
    'label'     => 'Name for this track',
    'size'      => '30',
  }, $user && $user->id ? {
    'type'      => 'checkbox',
    'name'      => 'save',
    'label'     => 'Save URL to my account',
    'notes'     => 'N.B. Only the file address will be saved, not the data itself',
  } : ()]);
  
  # This is turned off by default because there are serious UI issues
  # of confusing existing users who don't need this feature. Also this
  # feature only works some of the time at the moment. Flag will be
  # removed when feature is ready. -- ds23
  my $feature_remote_trackline = 0;
  if($self->hub->species_defs->get_config('MULTI', 'experimental')) {
    $feature_remote_trackline = $self->hub->species_defs->get_config('MULTI', 'experimental')->{'FEATURE_REMOTE_TRACKLINE'};
  }

  if($feature_remote_trackline) {
    $form->add_field([{
      'type'      => 'string',
      'name'      => 'trackline',
      'label'     => 'Additional track line data',
      'size'      => '30',
      'notes'     => '( advanced, blank is ok )',    
    }]);
  }
  return $form->render;
}

1;
