package EnsEMBL::Web::Command::UserData::SNPConsequence;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self   = shift;
  my $object = $self->object;
  my $hub    = $self->hub;

  my $url    = $object->species_path($object->data_species) . '/UserData/SelectOutput';
  my @files  = ($object->param('convert_file'));
  my $temp_files = [];
  my $size_limit =  $object->param('variation_limit');
  my $output;
  
  my $param  = {
    _time    => $object->param('_time'),
    species  => $object->param('species'),
    consequence_mapper  => $object->param('consequence_mapper'),
  };
  
  foreach my $file_name (@files) {
    next unless $file_name;

    my ($file, $name) = split ':', $file_name;
    my ($results, $nearest, $file_count) = $object->calculate_consequence_data($file, $size_limit);
    my $table = $object->consequence_table($results);

    # Output new data to temp file
    my $temp_file = new EnsEMBL::Web::TmpFile::Text(
      extension    => 'txt',
      prefix       => 'user_upload',
      content_type => 'text/plain; charset=utf-8',
    );
    
    $temp_file->print($table->render_Text);
    
    push @$temp_files, $temp_file->filename . ':' . $name;
 
    ## Resave this file location to the session
    my @split = split('-', $file);
    my $code = $split[-1];
    my $session_data = $hub->session->get_data('code' => $code);
    $session_data->{'filename'} = $temp_file->filename;
    $session_data->{'filesize'} = length($temp_file->content);
    $session_data->{'format'}   = 'SNP_EFFECT';
    $session_data->{'md5'}      = $temp_file->md5;
    $session_data->{'nearest'}  = $nearest;

    $hub->session->set_data(%$session_data);
    $param->{'code'} = $code;
    $param->{'count'} = $file_count;
    $param->{'size_limit'} = $size_limit;
  }
 
  $param->{'convert_file'} = $temp_files;

  $url = encode_entities($self->url($url, $param));

  $self->r->content_type('text/html; charset=utf-8');

  print qq#
    <html>
    <head>
      <script type="text/javascript">
        if (!window.parent.Ensembl.EventManager.trigger('modalOpen', { href: '$url', title: 'File uploaded' })) {
          window.parent.location = '$url';
        }
      </script>
    </head>
    <body><p>UP</p></body>
    </html>#;
}

1;

