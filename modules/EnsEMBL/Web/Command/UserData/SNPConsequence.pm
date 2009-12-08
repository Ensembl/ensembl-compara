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
  my $output;
  
  my $param  = {
    _referer => $object->param('_referer'),
    _time    => $object->param('_time'),
    species  => $object->param('species')
  };
  
  foreach my $file_name (@files) {
    next unless $file_name;
    
    my ($file, $name) = split ':', $file_name;
    my ($table, $error) = $object->calculate_consequence_data($file);
    
    $output .= $error ? $table : $table->render_Text;
    
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

