package EnsEMBL::Web::Tools::Misc;

## Just a bunch of useful tools
use LWP::UserAgent;
use EnsEMBL::Web::RegObj;

use base qw(Exporter);
our @EXPORT = qw(pretty_date get_url_content);
our @EXPORT_OK = qw(pretty_date get_url_content);

sub pretty_date {
  my $timestamp = shift;
  my @date = localtime($timestamp);
  my @days = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  my @months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  return $days[$date[6]].' '.$date[3].' '.$months[$date[4]].', '.($date[5] + 1900);
}

sub get_url_content {
  my $url   = shift;
  my $proxy = shift || $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WWW_PROXY;
  my $content;

  my $ua = new LWP::UserAgent;
  $ua->timeout(10);
  $ua->proxy('http', $proxy) if $proxy;

  my $request = new HTTP::Request( 'GET', $url );
  $request->header('Cache-control' => 'no-cache');
  $request->header('Pragma'        => 'no-cache');
  my $response = $ua->request($request);
  my $error = _get_http_error($response);
  if ($error) {
    return {'error' => $error};
  }
  else {
    return {'content' => $response->content};
  }
}

sub get_url_filesize {
## Returns the size of a file in bytes, or an error code if the request fails
  my $url   = shift;
  my $proxy = shift || $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WWW_PROXY;
  my $feedback = {};

  my $ua = new LWP::UserAgent;
  $ua->timeout(10);
  $ua->proxy('http', $proxy) if $proxy;

  my $request = new HTTP::Request( 'GET', $url );
  $request->header('Cache-control' => 'no-cache');
  $request->header('Pragma'        => 'no-cache');
  my $response = $ua->request($request);
  my $error = _get_http_error($response);
  if ($error) {
    $feedback->{'error'} = $error;
  }
  else {
    $file_size = $response->header('Content-Length');
    unless ($file_size) {
      my $content = $response->content;
      if ($content) {
        $feedback->{'filesize'} = length($content);
      }
      else {
        $feedback->{'filesize'} = 0;
      }
    }
  }
  return $feedback;
}

sub _get_http_error {
  my $response = shift;
  my $error;
  if (!$response->code) {
    $error = 'timeout';
  }
  elsif ($response->code >= 400) {
    $error = $response->status_line;
  }
  elsif ($response->content_type =~ /HTML/i) {
    $error = 'mime';
  }
  return $error;
}


sub style_by_filesize {
  my $filesize = shift || 0;
  my $style = $filesize > 1048576 ? 'density' : 'highlight'; ## 1048576 bytes = 1Mb
  return $style;
}

1;
