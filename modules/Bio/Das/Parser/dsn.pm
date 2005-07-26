package Bio::Das::Request::dsn;
# $Id$
# this module issues the dsn command, with no arguments

use strict;
use Bio::Das::DSN;
use Bio::Das::Request;

use vars '@ISA';
@ISA = 'Bio::Das::Request';

sub new {
  my $pack = shift;
  my ($base,$callback) = rearrange([['base','server'],
				    'callback'
				   ],@_);

  return $pack->SUPER::new(-base=>$base,-callback=>$callback);
}

sub command { 'dsn' }

sub create_parser {
  my $self = shift;
  my $parser= HTML::Parser->new(
				api_version   => 3,
				start_h       => [ sub { $self->tag_starts(@_) },'tagname,attr' ],
				end_h         => [ sub { $self->tag_stops(@_)  },'tagname' ],
				text_h        => [ sub { $self->char_data(@_)  },  'dtext' ],
			       );

}
sub tag_starts {
  my $self = shift;
  my ($tag,$attrs) = @_;
  my $method = "t_\L$tag";
  $self->{char_data} = '';  # clear char data
  $self->$method($attrs);   # indirect method call
}

sub tag_stops {
  my $self = shift;
  my $tag = shift;
  $tag = lc $tag;
  $self->$tag();
}

sub char_data {
  my $self = shift;
  my $text = shift;
  $self->{char_data} .= $text;
}

# top-level tag
sub dasdsn {
  my $self  = shift;
  my $attrs = shift;
  if ($attrs) {  # section is starting
    $self->clear_results;
  }
  $self->{current_dsn} = undef;
}

# the beginning of a dsn
sub dsn {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {  # tag starts
    $self->{current_dsn} = Bio::Das::DSN->new;
  } else {
    $self->add_object($self->{current_dsn});
  }
}

sub source {
  my $self  = shift;
  my $attrs = shift;
  my $dsn = $self->{current_dsn} or return;
  if ($attrs) {
    $dsn->id($attrs->{id});
  } else {
    my $name = trim($self->{char_data});
    $dsn->name($name);
  }
}

sub mapmaster {
  my $self  = shift;
  my $attrs = shift;
  my $dsn = $self->{current_dsn} or return;
  if ($attrs) {
    ; # do nothing here
  } else {
    my $name = trim($self->{char_data});
    $dsn->master($name);
  }
}

sub description {
  my $self  = shift;
  my $attrs = shift;
  my $dsn = $self->{current_dsn} or return;
  if ($attrs) {
    ; # do nothing here
  } else {
    my $name = trim($self->{char_data});
    $dsn->description($name);
  }
}

1;

