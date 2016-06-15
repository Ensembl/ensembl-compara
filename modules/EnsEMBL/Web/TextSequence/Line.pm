package EnsEMBL::Web::TextSequence::Line;

use strict;
use warnings;

use EnsEMBL::Web::TextSequence::ClassToStyle qw(convert_class_to_style);

# Represents a single line of text sequence

sub new {
  my ($proto,$seq) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    letters => "",
    pre => "",
    post => "",
    count => 0,
    line_num => $seq->view->_new_line_num,
    hub => $seq->view->_hub,
    seq => $seq,
  };
  bless $self,$class;
  return $self;
}

sub add_letter { $_[0]->{'letters'} .= ($_[1]||' '); $_[0]->{'count'}++; }
sub add_pre { $_[0]->{'pre'} .= ($_[1]||''); }
sub add_post { $_[0]->{'post'} .= ($_[1]||''); }

sub post { return $_[0]->{'post'}; }
sub count { return $_[0]->{'count'}; }
sub output { return $_[0]->{'output'}; }

sub full { $_[0]->{'count'} >= $_[0]->{'seq'}->view->width }

sub adorn {
  my ($self,$k,$v) = @_;

  $self->{'seq'}->view->_adorn($self->{'line_num'},$self->{'count'}-1,$k,$v);
}

sub adorn_classes {
  my ($self,$classes,$maintain,$config) = @_;

  my @classes = split(' ',$classes||'');

  # Find any exon classes, as exon classes must often be maintained across
  # entries ...
  my ($new_exon) = grep { /^e\w$/ } @classes;
  if($new_exon) {
    $self->{'seq'}->_exon($new_exon);    # ... set
  } elsif($maintain and $self->{'seq'}->view->_maintain_colour) {
    push @classes,$self->{'seq'}->_exon; # ... get
  }

  # Convert from class to style
  my $style = convert_class_to_style($self->{'hub'},\@classes,$config);
  $self->adorn('style',$style);
}

sub add {
  my ($self) = @_;

  $self->{'seq'}->_add({
    line => $self->{'letters'},
    length => $self->{'count'},
    pre => $self->{'seq'}->pre.$self->{'pre'},
    post => $self->{'post'},
    adid => $self->{'line_num'}
  });
  # "post" can be updated by later adornment
  if($self->{'post'}) {
    $self->{'seq'}->view->
      _flourish('post',$self->{'line_num'},$self->{'post'});
  }
}

1;
