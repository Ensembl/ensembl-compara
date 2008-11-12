package EnsEMBL::Web::Tools::Encryption;

use strict;
use warnings;
use Exporter 'import';
use Digest::MD5 qw(md5 md5_hex md5_base64);

our @EXPORT_OK = qw(checksum validate_checksum);

{

## Deprecated
#sub encryptID {
#    my $ID = shift;
#    my $rand1 = 0x8000000 + 0x7ffffff * rand();
#    my $rand2 = $rand1 ^ ($ID + EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_0);
#    my $encrypted = crypt(crypt(crypt(sprintf("%x%x",$rand1,$rand2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_1),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_3);
#    my $MD5d = Digest::MD5->new->add($encrypted)->hexdigest();
#    return sprintf("%s%x%x%s", substr($MD5d,0,16), $rand1, $rand2, substr($MD5d,16,16));
#
#}
#
#sub decryptID {
#    my $encrypted = shift;
#    my $rand1  = substr($encrypted,16,7);
#    my $rand2  = substr($encrypted,23,7);
#    my $ID = ( hex( $rand1 ) ^ hex( $rand2 ) ) - EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_0;
#    my $XXXX = crypt(crypt(crypt($rand1.$rand2,EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_1),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_3);
#    my $MD5d = Digest::MD5->new->add($XXXX)->hexdigest();
#    $ID = substr($MD5d,0,16).$rand1.$rand2.substr($MD5d,16,16) eq $encrypted ? $ID : 0;
#}

sub encryptPassword {
  my ($password, $salt) = @_;
  return md5_hex($password);
}

sub checksum {
  my $ID = shift;
  ## TODO: move random string to configs
  return substr(md5_hex(crypt($ID, '385dFG0f')), 0, 5);
}

sub validate_checksum {
  return checksum(int shift) eq shift;
}

}

1;
