package EnsEMBL::Web::Command::UserData::AttachURL;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $url = '/'.$self->object->data_species.'/UserData/';
  my $param;

  my $name = $self->object->param('name');
  unless ($name) {
    my @path = split('/', $self->object->param('url'));
    $name = $path[-1];
  }

  if (my $url = $self->object->param('url')) {
    my $data = $self->object->get_session->add_data(
      type    => 'url',
      url     => $url,
      name    => $name,
      species => $self->object->data_species,
    );
    if ($self->object->param('save')) {
      $self->object->move_to_user('type'=>'url', 'code'=>$data->{'code'});
    }
    $url .= 'UrlFeedback';
  } else {
    $url .= 'SelectURL';
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_url';
  }

  $self->ajax_redirect($url, $param); 
}

}

1;
