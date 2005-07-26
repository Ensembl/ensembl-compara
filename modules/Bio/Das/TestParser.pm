package Bio::Das::TestParser;

use strict;
use vars '@ISA';
use Bio::Das::Parser;
use HTML::Parser;

@ISA = 'Bio::Das::Parser';

sub create_parser {
  my $self = shift;
  $self->{tag_starts} = {};
  $self->{tag_stops} = {};
  $self->{chars} = 0;
  my $parser= HTML::Parser->new(
			       api_version   => 3,
			       start_h       => [ sub { $self->count_starts(@_) },'tagname' ],
			       end_h         => [ sub { $self->count_stops(@_)  },'tagname' ],
			       text_h        => [ sub { $self->count_chars(@_)  },'dtext' ],
			       );
  $parser;
}

sub count_starts {
  my $self = shift;
  my $tag = shift;
  $self->{tag_starts}{$tag}++;
}

sub count_stops {
  my $self = shift;
  my $tag = shift;
  $self->{tag_stops}{$tag}++;
}

sub count_chars {
  my $self = shift;
  my $text = shift;
  $self->{chars} += length $text;
}

sub report {
  my $self = shift;
  for my $k (qw(tag_starts tag_stops)) {
    print "I saw the following $k: \n";
    foreach (keys %{$self->{$k}}) {
      print "\t$_ => $self->{tag_starts}{$_}\n";
    }
  }
  print "Plus, I saw $self->{chars} chars\n";
}

1;
