# makes objects from parser events

package GO::Handlers::N3OutHandler;
use base qw(GO::Handlers::TripleHandler);
use strict;

sub emit {
    my $self = shift;
    my ($p, $s, $o) = @_;
    $self->print(join(" ", map {n3quote($_)}($s, $p, $o))." .\n");
}

sub n3quote {
    my $s = shift;
    $s =~ s/\'/\\\'/g;
    "\"$s\"";
}

1;
