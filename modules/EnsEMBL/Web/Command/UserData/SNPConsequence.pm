package EnsEMBL::Web::Command::UserData::SNPConsequence;

use strict;
use warnings;

use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self   = shift;
  my $object = $self->object;
  my $url    = $object->species_path($object->data_species) . '/UserData/PreviewConvertIDs';
  my @files  = ($object->param('convert_file'));
  my $temp_files = [];
  my $size_limit =  $object->param('variation_limit');
  my $output;
  
  my $param  = {
    _time    => $object->param('_time'),
    species  => $object->param('species')
  };
  
  foreach my $file_name (@files) {
    next unless $file_name;
    
    my ($file, $name) = split ':', $file_name;
    my ($table, $file_count) = $object->calculate_consequence_data($file, $size_limit);

    if ($file_count){
      $output .= 'Your file contained '.$file_count .' features however this web tool will only conver the first '. $size_limit .' features in the file.'."\n\n";
      $output .= $table->render_Text;
    } else {      
     $output .= $table->render_Text;
    }

    # Output new data to temp file
    my $temp_file = new EnsEMBL::Web::TmpFile::Text(
      extension    => 'txt',
      prefix       => 'export',
      content_type => 'text/plain; charset=utf-8',
    );
    
    $temp_file->print($output);
    
    push @$temp_files, $temp_file->filename . ':' . $name;
  }
  
  $param->{'converted'} = $temp_files;
  
  $self->ajax_redirect($url, $param);
}

1;

