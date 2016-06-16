package EnsEMBL::Web::TextSequence::Adorn;

use strict;
use warnings;

# This module is responsible for collecting adornment information for a
# view. There is exactly one per view. It is separate as this
# functionality is complex and independent of the other tasks of a view.
#
# It is not expected that this class will need to be overridden.

sub new {
  my ($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    addata => {},
    adlookup => {},
    adlookid => {},
    flourishes => {}
  };
  bless $self,$class;
  return $self;
}

sub adorn {
  my ($self,$line,$char,$k,$v) = @_;

  $self->{'addata'}{$line}[$char]||={};
  return unless $v;
  $self->{'adlookup'}{$k} ||= {};
  $self->{'adlookid'}{$k} ||= 1;
  my $id = $self->{'adlookup'}{$k}{$v};
  unless(defined $id) {
    $id = $self->{'adlookid'}{$k}++;
    $self->{'adlookup'}{$k}{$v} = $id;
  }
  $self->{'addata'}{$line}[$char]{$k} = $id;
}

sub flourish {
  my ($self,$type,$line,$value) = @_;

  ($self->{'flourishes'}{$type}||={})->{$line} =
    encode_json({ v => $value });
}

sub addata { return $_[0]->{'addata'}; }
sub adlookup { return $_[0]->{'adlookup'}; }
sub flourishes { return $_[0]->{'flourishes'}; }

1;
