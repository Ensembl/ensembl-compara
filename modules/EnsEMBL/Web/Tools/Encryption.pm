package EnsEMBL::Web::Tools::Encryption;

use strict;
use warnings;
use Exporter 'import';
use Digest::MD5 qw(md5 md5_hex md5_base64);

our @EXPORT_OK = qw(encryptPassword checksum validate_checksum);

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

1;
