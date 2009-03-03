package EnsEMBL::Web::Command::UserData::CheckShare;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Command';

{

sub BUILD {
}

sub process {
  my $self = shift;
  my $url = '/'.$self->object->data_species.'/UserData/';
  my $param;

  my @shares = ($self->object->param('share_id'));
  foreach my $code (@shares) {
    if ($code !~ /^d+$/) {
      my $data = $self->object->get_session->get_data(type => 'upload', code => $code);
      if ($data->{filename}) {
        if (my $ref = $self->object->store_data(type => 'upload', code => $code)) {
          @shares = grep {$_ ne $code} @shares;
          push @shares, $ref;
        } else {
          $param->{'filter_module'} = 'Data';
          $param->{'filter_code'} = 'no_save';
        }
      }
    }
  }
  if (@shares) {
    $url .= 'ShareURL';
    $param->{'share_id'} = \@shares;
  }
  else {
    $url .= 'SelectShare';
  }

  $self->ajax_redirect($url, $param); 

}

}

1;
