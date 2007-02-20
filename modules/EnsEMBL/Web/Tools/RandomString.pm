package EnsEMBL::Web::Tools::RandomString;

sub random_string {
  my $length = shift || 8;
  my @chars = ('a'..'z','A'..'Z','0'..'9','_');
  my $random_string;
  foreach (1..$length)
  {
    $random_string .= $chars[rand @chars];
  }
  return $random_string;
}

1;
