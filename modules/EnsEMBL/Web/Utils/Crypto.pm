package EnsEMBL::Web::Utils::Crypto;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(random_key);

sub random_key {
  my ($bytes) = @_;

  my $data;
  if(open(RANDOM,'<:raw','/dev/urandom')) {
    local $/ = \$bytes;
    $data = <RANDOM>;
    close RANDOM;
  } else {
    warn "Using weak crypto\n";
    for(my $i=0;$i<$bytes;$i++) {
      substr($data,$i,$i) = int rand 256;
    }
  }
  return unpack("H[32]",$data);
}

1;
