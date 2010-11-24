package EnsEMBL::Web::Component::UserData::ConsequenceTool;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '<h2>Variant Effect Predictor  Results:</h2>';

  my @files = ($object->param('code'));
  my $size_limit =  $object->param('variation_limit');

  foreach my $code (@files) {
    my $data = $object->consequence_data_from_file($code); 
    my $table = $object->consequence_table($data);
    $html .= $table->render;
  }

  return $html;
}

1;
