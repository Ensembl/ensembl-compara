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
  my $html = '<h2>SNP Effect Predictor  Results:</h2>';
  my $referer =  $object->param('_referer');
  $html .= qq(<br /><a href="$referer">Back to previous view</a><br />);


  my @files = ($object->param('convert_file'));
  my $size_limit =  $object->param('variation_limit');

  foreach my $file_name (@files) {
    my ($file, $name) = split(':', $file_name);  
    my ($table, $file_count) = $object->calculate_consequence_data($file, $size_limit);
    if ($file_count){
      $html .= $self->_hint ('', '<p>' .'Your file contained '.$file_count .' features however 
       this web tool will only convert the first '. $size_limit .' features in the file.</p>');
    }
    $html .= $table->render;
  }

  return $html;
}

1;
