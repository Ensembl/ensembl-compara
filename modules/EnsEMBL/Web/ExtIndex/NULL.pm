package EnsEMBL::Web::ExtIndex::NULL;
use strict;

sub new { my $class = shift; my $self = {}; bless $self, $class; return $self; }
sub get_seq_by_id  { return; }
sub get_seq_by_acc { return; }

1;
