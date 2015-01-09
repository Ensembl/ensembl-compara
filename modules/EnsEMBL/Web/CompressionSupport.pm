=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::CompressionSupport;

use strict;
use Compress::Zlib;
use Compress::Bzip2;
use IO::Uncompress::Bunzip2;

sub uncomp {
######## DEPRECATED ################
warn "DEPRECATED METHOD 'uncomp' - please switch to using EnsEMBL::Web::File::Utils::uncompress. This module will be removed in release 80.";
####################################
  my $content_ref = shift;
  if( ord($$content_ref) == 31 && ord(substr($$content_ref,1)) == 157 ) { ## COMPRESS...
    my $t = Compress::Zlib::uncompress($$content_ref);
    $$content_ref = $t;
  } elsif( ord($$content_ref) == 31 && ord(substr($$content_ref,1)) == 139 ) { ## GZIP...
    my $t = Compress::Zlib::memGunzip($$content_ref);
    $$content_ref = $t;
  } elsif( $$content_ref =~ /^BZh([1-9])1AY&SY/ ) {                            ## GZIP2
    my $t = Compress::Bzip2::decompress($content_ref); ## Try to uncompress a 1.02 stream!
    unless($t) {
      my $T = $$content_ref;
      my $status = IO::Uncompress::Bunzip2::bunzip2 \$T,\$t;            ## If this fails try a 1.03 stream!
    }
    $$content_ref = $t;
  }
  return;
}

1;
