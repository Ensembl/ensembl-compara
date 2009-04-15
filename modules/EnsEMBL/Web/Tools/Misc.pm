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
## Returns the size of a file, or a message if size is over a given limit
## Set limits to 0 if you just want to get the file size with no checking
  my ($url, $proxy, $size_options) = @_;
  my $abort_size = $size_options->{'abort'} || 1024;
  my $large_size = $size_options->{'large'} || 10;
  my $file_size = 0;
  ## Convert to bytes
  $abort_size = int(1048576 * $abort_size); 
  $large_size = int(1048576 * $large_size); 
  #warn "ABORT AT $abort_size BYTES";
  #warn "LARGE IF $large_size BYTES OR MORE";

  my $ua = new LWP::UserAgent;
  $ua->timeout(10);
  $ua->proxy('http', $proxy) if $proxy;

  my ($request, $response);
  ## First check if file is too large to bother with!
  if ($abort_size) {
    #warn "CHECKING IF WAY TOO LARGE!";
    $ua->max_size($abort_size);

    $request = new HTTP::Request( 'GET', $url );
    $request->header('Cache-control' => 'no-cache');
    $request->header('Pragma'        => 'no-cache');
    $response = $ua->request($request);

    if ($response->header('Client-Aborted') || (my $length = $response->header('Content-Length') && $length > $abort_size)) {
      #warn "!!! ABORTED - exceeded maximum file size";
      return 'aborted';
    }
  }

  ## Now check if it is large enough to require special handling
  $ua->max_size($large_size) if $large_size;

  $request = new HTTP::Request( 'GET', $url );
  $request->header('Cache-control' => 'no-cache');
  $request->header('Pragma'        => 'no-cache');
  $response = $ua->request($request);
  #warn $response->headers_as_string;

  if ($response->header('Client-Aborted') || (my $length = $response->header('Content-Length') && $length > $large_size)) {
    #warn "!!! LARGE FILE";
    return 'large';
  }
  elsif ($response->is_success) {
    #warn "SUCCESS";
    my $file_size = $response->header('Content-Length');
    unless ($file_size) {
      my $content = $response->content;
      if ($content) {
        $file_size = length($content);
      }
    }
    ## Check again in case no useful headers returned
    if ($abort_size && $file_size >= $abort_size) { 
      return 'aborted';
    }
    elsif ($large_size && $file_size >= $large_size) { 
      return 'large';
    }
  }
  #warn "FILE SIZE $file_size BYTES";
  return $file_size;
}

1;
