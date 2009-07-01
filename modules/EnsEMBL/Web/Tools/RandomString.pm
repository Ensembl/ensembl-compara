package EnsEMBL::Web::Tools::RandomString;

use strict;
use Time::HiRes qw(gettimeofday);

our @random_chars = ('a'..'z','A'..'Z','0'..'9','_');
our @random_ticket_chars = ('A'..'Z','a'..'f');

### Return a random string of given length
### (or 8 characters if no length passed)
sub random_string {
  my $len = (shift)+0 || 8;
  return join '', map { $random_chars[rand @random_chars] } (1..$len);
}

### Returns a random-ish ticket string
### former EnsEMBL::Web::Root->ticket
### this is not a normal distribution - first several letters depend on time
### so that generated strings alphabetically "grow" as time passes
sub ticket {
  my $self = shift;
  my $date = time() + shift;
  my($sec, $msec) = gettimeofday;
  my $rand = rand( 0xffffffff );
  my $fn = sprintf "%08x%08x%06x%08x", $date, $rand, $msec, $$;
  my $fn2 = '';
  while($fn=~s/^(.....)//) {
    my $T = hex($1);
    $fn2 .= $random_ticket_chars[$T>>15].
            $random_ticket_chars[($T>>10)&31].
            $random_ticket_chars[($T>>5)&31].
            $random_ticket_chars[$T&31];
  }
  return $fn2;
}

1;
