package EnsEMBL::Web::TextSequence::Sequence;

use strict;
use warnings;

use Scalar::Util qw(weaken);

use EnsEMBL::Web::TextSequence::Line;

# Represents all the lines of a single sequence in sequence view. On many
# views there will be multiple of these entwined, either different views
# on the same data (variants, bases, residues, etc), or different
# sequences.

sub new {
  my ($proto,$view,$id) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    view => $view,
    id => $id,
    exon => "",
    pre => "",
    configured => 0,
    name => undef,
  };
  bless $self,$class;
  weaken($self->{'view'});
  $self->init;
  return $self;
}

sub init {} # For subclasses
sub ready {} # For subclasses

sub configure {
  my ($self) = @_;

  if(!$self->{'configured'}) {
    $self->ready;
    $self->{'configured'} = 1;
  }
}

sub new_line {
  my ($self) = @_;

  $self->configure;
  my $line = EnsEMBL::Web::TextSequence::Line->new($self);
  return $line;
}

sub view { return $_[0]->{'view'}; }
sub line_num { return $_[0]->{'line'}; }

# only for use in Line
sub _exon {
  my ($self,$val) = @_;

  $self->{'exon'} = $val if @_>1;
  return $self->{'exon'};
}

sub _add {
  my ($self,$data) = @_;

  $self->{'view'}->_add_line($self->{'id'},$data);
}

sub name {
  my ($self,$name) = @_;

  if(@_>1) {
    $self->{'name'} = $name;
    (my $plain_name = $name) =~ s/<[^>]+>//g;
    $self->{'view'}->field_size('name',length $plain_name);
  }
  return $self->{'name'};
}

sub padded_name {
  my ($self) = @_;

  my $name = $self->name;
  return undef unless $name;
  $name .= ' ' x ($self->{'view'}->field_size('name') - length $name);
  return $name;
}

sub pre {
  my ($self,$val) = @_;

  ($self->{'pre'}||="") .= $val if @_>1;
  return $self->{'pre'};
}

sub id { return $_[0]->{'id'}; }

1;
