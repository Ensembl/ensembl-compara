package EnsEMBL::Web::Command::UserData::FviewRedirect;

### Redirects from the 'FeatureView' form to either Location/Chromosome or Location/Genome

use strict;
use warnings;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $url = '/'.$object->param('species').'/Location/Genome';
  my @ids = split(',', $object->param('id'));
  for (@ids) {
    s/^\s+//;
    s/\s+$//;
  }
  my $params = {
    'ftype' => $object->param('ftype'), 
    'id' => \@ids,
    'colour' => $object->param('colour'), 
    'style' => $object->param('style'), 
    'reload' => 1,
  };
  
  $self->ajax_redirect($url, $params, undef, 'page'); 
}

1;
