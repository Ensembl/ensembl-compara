package EnsEMBL::Web::Tools::Encryption;

use strict;
use warnings;

{

sub encryptID {
    my $ID = shift;
    my $rand1 = 0x8000000 + 0x7ffffff * rand();
    my $rand2 = $rand1 ^ ($ID + EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_0);
    my $encrypted = crypt(crypt(crypt(sprintf("%x%x",$rand1,$rand2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_1),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_3);
    my $MD5d = Digest::MD5->new->add($encrypted)->hexdigest();
    return sprintf("%s%x%x%s", substr($MD5d,0,16), $rand1, $rand2, substr($MD5d,16,16));

}

sub decryptID {
    my $encrypted = shift;
    my $rand1  = substr($encrypted,16,7);
    my $rand2  = substr($encrypted,23,7);
    my $ID = ( hex( $rand1 ) ^ hex( $rand2 ) ) - EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_0;
    my $XXXX = crypt(crypt(crypt($rand1.$rand2,EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_1),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_3);
    my $MD5d = Digest::MD5->new->add($XXXX)->hexdigest();
    $ID = substr($MD5d,0,16).$rand1.$rand2.substr($MD5d,16,16) eq $encrypted ? $ID : 0;
}

sub encryptPassword {
  my ($password, $salt) = @_;
  return Digest::MD5->new->add($password.$salt)->hexdigest();
}

}

1;
