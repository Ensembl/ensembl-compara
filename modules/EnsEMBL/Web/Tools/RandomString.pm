package EnsEMBL::Web::Tools::RandomString;

use strict;

### Return a random string of given length (or 8 characters if no length passed)
sub random_string {
  my $len = (shift)+0 || 8;
  my @chars = ('a'..'z','A'..'Z','0'..'9','_');
  return join '', map { $chars[rand @chars] } (1..$len);
}

1;
