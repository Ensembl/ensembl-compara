package EnsEMBL::Web::Document::HTML::TwoCol;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

sub new {
  my $class = shift;
  my $self = { 'content' => [] };
  bless $self, $class;
  return $self;
}

sub _row {
  my ($self, $label, $value) = @_;
  
  return sprintf '
  <dl class="summary">
    <dt class="__h">%s</dt>
    <dd>%s</dd>
  </dl>', encode_entities($label), $value;
}

sub add_row {
  my ($self, $label, $value, $raw) = @_;
  
  $value = sprintf '<p>%s</p>', encode_entities($value) unless $raw;
  
  push @{$self->{'content'}}, $self->_row($label, $value);
}

sub render {
  my $self = shift;
  return join '', @{$self->{'content'}};
}

1;
