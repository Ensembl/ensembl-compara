#########
# helper class for compatibilising Bioperl
# Bio::Search:::Result::ResultI objects with DrawableContainers

package EnsEMBL::Web::Container::HSPContainer;
use strict;

sub new {
  my $class = shift;
  my $result = shift;
  my $aligns = shift || undef;

  ( $result && $result->isa("Bio::Search::Result::ResultI" ) ) or
    die( "Need a Bio::Search:::Result::ResultI object" );
  my $self = {'result' => $result };

  my @hsps;
  if( $aligns ){ @hsps = map{$_->[1]} @$aligns }
  else{ @hsps = map{$_->hsps} $result->hits }
  $self->{hsps} = [@hsps];

  return bless($self, $class);
}

sub start {
  my ($self) = @_;
  return 0;
}

sub end {
  my ($self) = @_;
  return $self->length;
}

sub length {
  my ($self) = @_;
  return $self->{result}->query_length();
}

sub name {
  my ($self) = shift;
  return $self->{result}->query_name();
}

sub database{
  my ($self) = @_;
  return $self->{result}->database_name();
}

sub hits {
  my ($self) = @_;
  return $self->{result}->hits();
}

sub hsps{
  my ($self) = @_;
  return @{$self->{hsps}};
}

1;
