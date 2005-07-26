package Bio::Das::Parser;

use strict;
use XML::Parser;
use Carp 'croak';

# abstract class that provides the parsesub(), parse() and parsedone() methods

# return a closure that calls our parse method
sub parsesub {
  my $self = shift;
  return sub { $self->parse(@_) };
}

# start a parse
sub parse {
  my $self = shift;
  my ($data,$response,$protocol) = @_;
  my $parser = $self->{_parser};
  unless ($parser) {
    my $p = $self->create_parser or croak "Can't create XML::Parser";
    $parser = $self->{_parser} = $p->parse_start or croak "Can't create XML::Parser::ExpatNB";
  }

  $parser->parse_more($data) if defined $data;
}

# end a parse
sub parsedone {
  my $self = shift;
  eval {$self->{_parser}->parse_done} if $self->{_parser};  # clean up after the parse
  delete $self->{_parser};
}

sub parser { shift->{_parser} }

sub create_parser {
  croak "the create_parser() must be overridden in subclasses";
}


1;
