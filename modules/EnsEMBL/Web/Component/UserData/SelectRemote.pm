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
  my $form = $self->modal_form('select_url', "$current_species/UserData/AttachRemote", {'wizard' => 1, 'back_button' => 0});
  my $user = $object->user;
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;

  # URL-based section
  my $format_info = $self->hub->species_defs->DATA_FORMAT_INFO;
  my %format_name = map {$format_info->{$_}{'label'} => 1} (@{$self->hub->species_defs->UPLOAD_FILE_FORMATS}, @{$self->hub->species_defs->REMOTE_FILE_FORMATS});
  my $format_list = join(', ', (sort {lc($a) cmp lc($b)} keys %format_name));

  my $note = qq(
Accessing data via a URL can be slow unless you use an indexed format such as BAM. 
However it has the advantage that you always see the same data as the file on your own machine.<br /><br />
We currently accept attachment of the following formats: $format_list.
  );

  $note .= ' <strong>Note</strong>: VCF files must be indexed prior to attachment.' if grep(/vcf/i, keys %format_name);

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

  return $form->render;
}

1;
