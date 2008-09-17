package EnsEMBL::Web::Object::BlastRequest;

use strict;
use warnings;
no warnings "uninitialized";

use vars qw($TICKET_LABEL);

BEGIN {
  $TICKET_LABEL = "Ticket";
}

sub new {
  my ($class, $properties) = @_;
  my $self = {
              'id' => undef,
              'ticket' => undef,
              'sequence' => undef,
              'species' => undef,
              'status' => undef,
             };
  bless $self, $class;
  $self->id($properties->{'id'});
  $self->ticket($properties->{'ticket'});
  $self->sequence($properties->{'sequence'});
  $self->species($properties->{'species'});
  $self->status($properties->{'status'});
  return $self;
}

sub new_from_database {
  my ($class, $record) = @_;
  return new ($class, { 
              'id'       => $record->[0],
              'ticket'   => $record->[1],
              'sequence' => $record->[2],
              'species'  => $record->[3],
              'status'   => $record->[4]
             });
}

sub update {
  my ($self, $object) = @_;
  $self->sequence($object->param('sequence'));
  $self->species($object->param('species'));
}

sub sequence {
  my ($self, $sequence) = @_;
  if ($sequence) {
    $self->{'sequence'} = $sequence;
  }
  return $self->{'sequence'};
}

sub id {
  my ($self, $value) = @_;
  my $key = 'id';
  if ($value) {
    $self->{$key} = $value;
  }
  return $self->{$key};
}

sub ticket {
  my ($self, $value) = @_;
  my $key = 'ticket';
  if ($value) {
    $self->{$key} = $value;
  }
  return $self->{$key};
}

sub species {
  my ($self, $value) = @_;
  my $key = 'species';
  if ($value) {
    $self->{$key} = $value;
  }
  if (!$self->{$key}) {
    return 0;
  } 
  return $self->{$key};
}

sub type {
  my $self = shift;
  if ($self->sequence =~ /^>/) {
    my $type = "FASTA: ";
    if ($self->contains_only_bases) {
      $type .= "Nucleotides";
    } else {
      $type .= "Amino acids";
    }
    return $type;
  } elsif ($self->sequence =~ /^BLA_/) {
    return $TICKET_LABEL;
  } else {
    if ($self->contains_only_bases) {
      return "Nucleotides";
    } else {
      return "Amino acids";
    }
    return "Sequence";
  }
}

sub status {
  my ($self, $value) = @_;
  my $key = 'status';
  if ($value) {
    $self->{$key} = $value;
  }
  return $self->{$key};
}

sub contains_only_bases {
  my $self = shift;
  my $bases = "ACGTNX";
  my $query = $self->query_sequence;
  my $unique = $self->chop_2y($query);
  if ($unique <= length($bases)) {
    return 1;
  }
  return 0;
}

sub query_sequence {
  my $self = shift;
  my @lines = split(/\n/, $self->sequence);
  my $query = "";
  foreach my $line (@lines) {
    if ($line =~ /^>/) {
      next;
    } else {  
      $query .= $line;
    }
  }
  return $query;
}

sub sequence_length {
  my $self = shift;
  return length($self->query_sequence);
}

sub units {
  my $self = shift;
  if ($self->contains_only_bases) {
    return "bases";
  } else {
    return "residues";
  }
}


## Super fast way of counting unique characters in a 
## string
##
## Processes ~7500 to 8000 strings per second for amino
## acid and nuceotide sequences

sub chop_2y {
  my ($self, $s) = @_;
  my %c;
  $c{chop $s}++ while (length($s));
  scalar keys %c;
}

sub is_ticket {
  my $self = shift;
  if ($self->type eq $TICKET_LABEL) {
    return 1;
  }
  return 0;
}

1;
