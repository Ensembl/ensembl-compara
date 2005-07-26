package EnsEMBL::Web::ExtIndex::EFETCH;
use strict;

sub new { my $class = shift; my $self = {}; bless $self, $class; return $self; }
sub get_seq_by_id { print "EFETCH: @_ \n"; return 1; }
sub get_seq_by_acc{ print "EFETCH: @_ \n"; return 1; }

1;
