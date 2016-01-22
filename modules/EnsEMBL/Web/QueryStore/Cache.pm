package EnsEMBL::Web::QueryStore::Cache;

use strict;
use warnings;

use JSON;
use Digest::MD5 qw(md5_base64);

my $DEBUG = 0;

sub _key {
  my ($self,$args) = @_; 

  my $json = JSON->new->canonical(1)->encode($args);
  warn "$json\n" if $DEBUG > 1;
  my $key = md5_base64($json);
  warn "$key\n" if $DEBUG > 1;
  $key =~ s#/#_#g; # For filenames
  return $key;
}

sub cache_close {}
sub cache_open {}

1;
