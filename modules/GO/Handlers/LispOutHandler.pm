# makes objects from parser events

package GO::Handlers::LispOutHandler;
use base qw(GO::Handlers::TripleHandler);
use strict;

sub emit {
    my $self = shift;
    my @t = @_;
    $self->print("(".join(" ", map {lispquote($_)}@t).")\n");
}

sub lispquote {
    my $s = shift;
    $s =~ s/\'/\\\'/g;
    "'$s'";
}

1;
