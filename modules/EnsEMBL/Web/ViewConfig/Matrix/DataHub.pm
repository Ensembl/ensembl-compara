# $Id$

package EnsEMBL::Web::ViewConfig::Matrix::DataHub;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Matrix);

sub matrix_config {
  my $self = shift;
  my $tree = $self->matrix_image_config->tree;
  my $set  = $self->set;
  
  foreach ($tree->nodes) {
    my $data = $_->data;
    
    if ($data->{'label_x'} && $data->{'set'} eq $set) {
      return {
        menu        => $set,
        section     => $tree->get_node($tree->clean_id($data->{'menu_key'}))->get('caption'),
        header      => $data->{'header'},
        description => $data->{'info'},
        axes        => $data->{'axes'},
      };
    }
  }
}

1;
