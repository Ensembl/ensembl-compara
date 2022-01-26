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

package EnsEMBL::Web::Utils::RandomString;

use strict;
use Time::HiRes qw(gettimeofday);
use Exporter qw(import);

our @EXPORT               = qw(random_string random_ticket);
our @random_chars         = ('a'..'z','A'..'Z','0'..'9');
our @random_ticket_chars  = ('A'..'Z','a'..'f');

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
sub random_ticket {
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
