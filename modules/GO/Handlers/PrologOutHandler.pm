# makes objects from parser events

package GO::Handlers::PrologOutHandler;
use base qw(GO::Handlers::TripleHandler);
use strict;

sub emit {
    my $self = shift;
    my @t = @_;
    $self->print("t(".join(", ", map {prologquote($_)}@t).").\n");
}

sub prologquote {
    my $s = shift;
    $s =~ s/\'/\\\'/g;
    "'$s'";
}

1;
