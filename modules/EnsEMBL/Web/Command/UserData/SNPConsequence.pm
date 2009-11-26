package EnsEMBL::Web::Command::UserData::SNPConsequence;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Command';
use EnsEMBL::Web::Component;
use EnsEMBL::Web::Component::Export;

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/'.$object->data_species.'/UserData/PreviewConvertIDs';
  my $param;
  ## Set these separately, or they cause an error if undef
  $param->{'_referer'} = $object->param('_referer');
  $param->{'x_requested_with'} = $object->param('x_requested_with');
  $param->{'_time'} = $object->param('_time');
  my @files = ($object->param('convert_file'));
  $param->{'species'} = $object->param('species');
  my $output;
  my $temp_files = [];


  foreach my $file_name (@files) {
    next unless $file_name;
    my ($file, $name) = split(':', $file_name);
    my $table = $object->calculate_consequence_data($file);

    $output .= $table->render_Text;    
      
  ## Output new data to temp file
    my $temp_file = EnsEMBL::Web::TmpFile::Text->new(
        extension => 'txt',
        prefix => 'export',
        content_type => 'text/plain; charset=utf-8',
    );

    $temp_file->print($output);
    my $converted = $temp_file->filename.':'.$name;
    push @$temp_files, $converted;
  }

  $param->{'converted'} = $temp_files;

  if ($object->param('x_requested_with')) {
    $self->ajax_redirect($url, $param);
  }
  else {
    $object->redirect($self->url($url, $param));
  }
}
}
1;
