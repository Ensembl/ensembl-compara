package EnsEMBL::Web::Tools::Misc;

## Just a bunch of useful tools
use LWP::UserAgent;

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
  my $proxy = shift;
  my $content;

  my $ua = new LWP::UserAgent;
  $ua->timeout(10);
  $ua->proxy('http', $proxy) if $proxy;

  my $request = new HTTP::Request( 'GET', $url );
  $request->header('Cache-control' => 'no-cache');
  $request->header('Pragma'        => 'no-cache');
  my $response = $ua->request($request);

  return $response->is_success && $response->content;
}

sub get_url_filesize {
## Returns the size of a file in bytes, or -1 if the request fails
  my ($url, $proxy) = @_;
  my $file_size = 0;

  my $ua = new LWP::UserAgent;
  $ua->timeout(10);
  $ua->proxy('http', $proxy) if $proxy;

  my $request = new HTTP::Request( 'GET', $url );
  $request->header('Cache-control' => 'no-cache');
  $request->header('Pragma'        => 'no-cache');
  my $response = $ua->request($request);

  if ($response->is_success) {
    #warn "SUCCESS";
    my $file_size = $response->header('Content-Length');
    unless ($file_size) {
      my $content = $response->content;
      if ($content) {
        $file_size = length($content);
      }
    }
  }
  else {
    $file_size = -1;
  }
  #warn "FILE SIZE $file_size BYTES";
  return $file_size;
}

sub style_by_filesize {
  my $filesize = shift || 0;
  my $style = $filesize > 1048576 ? 'density' : 'highlight'; ## 1048576 bytes = 1Mb
  return $style;
}

1;
