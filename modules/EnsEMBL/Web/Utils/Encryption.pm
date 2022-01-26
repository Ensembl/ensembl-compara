=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Utils::Encryption;

## Handy methods for encrypting and decrypting strings 

use Digest::MD5;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(encrypt_value decrypt_value);

sub encrypt_value {
  ## @function
  my $value     = shift;

  my $rand1     = 0x8000000 + 0x7ffffff * rand();
  my $rand2     = ( $rand1 ^ ($value + $SiteDefs::ENSEMBL_ENCRYPT_0 ) ) & 0x0fffffff;
  my $time      = time() + 86400 * $SiteDefs::ENSEMBL_ENCRYPT_EXPIRY;
  my $encrypted = crypt(sprintf("%08x", $rand1), $SiteDefs::ENSEMBL_ENCRYPT_1).
                  crypt(sprintf("%08x", $time ), $SiteDefs::ENSEMBL_ENCRYPT_2).
                  crypt(sprintf("%08x", $rand2), $SiteDefs::ENSEMBL_ENCRYPT_3);
  my $md5d      = Digest::MD5->new->add($encrypted)->hexdigest;
  return sprintf("%s%08x%08x%08x%s", substr($md5d, 0, 16), $rand1, $time, $rand2, substr($md5d, 16, 16));
}

sub decrypt_value {
  ## @function
  my $string          = shift;

  my $rand1           = substr($string, 16, 8);
  my $time            = substr($string, 24, 8);

#  return (0, 'expired') if hex($time) < time();

  my $rand2           = substr($string, 32, 8);
  my $value           = ( ( hex( $rand1 ) ^ hex( $rand2 ) ) - $SiteDefs::ENSEMBL_ENCRYPT_0 ) & 0x0fffffff;
  my $encrypted       = crypt($rand1, $SiteDefs::ENSEMBL_ENCRYPT_1).
                        crypt($time,  $SiteDefs::ENSEMBL_ENCRYPT_2).
                        crypt($rand2, $SiteDefs::ENSEMBL_ENCRYPT_3);
  my $md5d            = Digest::MD5->new->add($encrypted)->hexdigest;
  return (
    (substr($md5d, 0, 16).$rand1.$time.$rand2.substr($md5d, 16, 16)) eq $string ? $value    : 0,
    hex($time) < time() - $SiteDefs::ENSEMBL_ENCRYPT_REFRESH * 86400            ? 'refresh' : 'ok'
  );
}


1;
