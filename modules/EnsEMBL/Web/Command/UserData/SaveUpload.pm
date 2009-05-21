package EnsEMBL::Web::Command::UserData::SaveUpload;

use strict;
use warnings;

use Class::Std;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  
  my $param = {'reload' => 1};

  unless ($object->store_data(type => 'upload', code => $object->param('code'))) {
    $param->{'filter_module'} = 'UserData';
    $param->{'filter_code'} = 'no_file';
  }

  $self->ajax_redirect('/'.$object->data_species.'/UserData/ManageData', $param);
}

}

1;
