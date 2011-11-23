package EnsEMBL::Web::Command::UserData::CheckRegions;

## Checks the user's input and uploads/creates a file for processing

use strict;

use Digest::MD5 qw(md5_hex);
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $session = $hub->session;
  my $url     = $hub->species_path($hub->data_species) . '/UserData/';

  ## Get the data!
  my ($data, $content, $param);
  my ($method) = grep $hub->param($_), qw(text file url);
  if ($method) {
    my $response = $self->upload($method);
    $data = $session->get_data(code => $response->{'code'});
    my $file = new EnsEMBL::Web::TmpFile::Text(filename => $data->{'filename'}, extension => $data->{'extension'});
    $content = $file->retrieve;
  }

  ## Now limit by region length and feature type
  my %features = map {$_ => 1} ($hub->param('include'));
  my $limit = ($features{'v'} || $features{'r'}) ? 1000000 : 5000000;

  if ($content) {
    my @slices;
    my @regions = split(/\r?\n/, $content);
    foreach my $region (@regions) {
      my ($chr, $start, $end) = split(':|-|\.\.', $region);
      push @slices, {'chr' => $chr, 'start' => $start, 'end' => $end};
    }
    ## Calculate total sequence length
    my $total_length;
    foreach my $slice (@slices) {
      my $l = $slice->{'start'} - $slice->{'end'};
      $total_length += abs($l);
    }
    #warn ">>> LENGTH $total_length";
    if ($total_length > $limit) {
      $param->{'filter_module'} = 'Region';
      $param->{'filter_code'} = 'too_big';
    }
    else {
      ## Pass checkbox options as a single string (same format used by API script)
      $param->{'include'}       = join('', $hub->param('include'));
      $param->{'code'}          = $data->{'code'};
      $param->{'output_format'} = $data->{'format'};
    }

  }
  else {
    $param->{'filter_module'} = 'Region';
    $param->{'filter_code'} = 'no_input';
  }

  if ($param->{'filter_module'}) {
    $url .= 'SelectReportOptions';
  }
  else {
    $url .= 'RunRegionTool';
  }
    
  $self->ajax_redirect($url, $param);
}

1;
