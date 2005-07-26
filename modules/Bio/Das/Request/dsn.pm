package Bio::Das::Request::dsn;
# $Id$
# this module issues the dsn command, with no arguments

use strict;
use Bio::Das::DSN;
use Bio::Das::Request;
use Bio::Das::Util 'rearrange';

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
  my $method = "t_\U$tag";
  $self->{char_data} = '';  # clear char data
  $self->$method($attrs);   # indirect method call
}

sub tag_stops {
  my $self = shift;
  my $tag = shift;
  $tag = uc $tag;
  $self->$tag();
}

sub char_data {
  my $self = shift;
  my $text = shift;
  $self->{char_data} .= $text;
}

# top-level tag
sub DASDSN {
  my $self  = shift;
  my $attrs = shift;
  if ($attrs) {  # section is starting
    $self->clear_results;
  }
  $self->{current_dsn} = undef;
}

# the beginning of a dsn
sub DSN {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {  # tag starts
    $self->{current_dsn} = Bio::Das::DSN->new($self->base);
  } else {
    $self->add_object($self->{current_dsn});
  }
}

sub SOURCE {
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

sub MAPMASTER {
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

sub DESCRIPTION {
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

