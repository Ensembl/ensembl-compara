package EnsEMBL::Web::CompressionSupport;

use strict;
use Compress::Zlib;
use Compress::Bzip2;
use IO::Uncompress::Bunzip2 qw(bunzip2);

sub uncomp {
  my $content_ref = shift;
  if( ord($$content_ref) == 31 && ord(substr($$content_ref,1)) == 157 ) { ## COMPRESS...
    my $t = Compress::Zlib::uncompress($$content_ref);
    $$content_ref = $t;
  } elsif( ord($$content_ref) == 31 && ord(substr($$content_ref,1)) == 139 ) { ## GZIP...
    my $t = Compress::Zlib::memGunzip($$content_ref);
		warn substr($t,0,100);
    $$content_ref = $t;
  } elsif( $$content_ref =~ /^BZh([1-9])1AY&SY/ ) {                            ## GZIP2
    my $t = Compress::Bzip2::decompress($content_ref); ## Try to uncompress a 1.02 stream!
		unless($t) {
		  my $T = $$content_ref;
      my $status = bunzip2 \$T,\$t;            ## If this fails try a 1.03 stream!
		}
	  $$content_ref = $t;
  }
	return;
}

1;
