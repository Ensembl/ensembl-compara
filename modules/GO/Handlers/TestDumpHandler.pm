# makes objects from parser events

package GO::Handlers::TestDumpHandler;
use GO::Handlers::DefHandler qw(lookup);
use base qw(GO::Handlers::DefHandler);
use strict;


sub e_term {
    my $self = shift;
    my $tree = shift;
    use Data::Dumper;
    print Dumper $tree;
    return;
}

1;
