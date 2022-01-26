=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::TextSequence::Layout::RTF;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Layout);

use List::MoreUtils qw(none all);

use EnsEMBL::Web::TextSequence::Layout::Structured::List;

my $TOT = 0;
my $X = 0;

sub value_empty { return ''; }
sub value_pad { return ' ' x $_[1]; }
sub value_fmt { return sprintf($_[1],map { $_->[1] } @{$_[2]}); }

sub _value_canon {
  my ($self,$v) = @_;

  $v = [['',$v]] unless ref $v;
  if(ref($v) eq 'ARRAY') {
    $v = EnsEMBL::Web::TextSequence::Layout::Structured::List->new($v);
  }
  return $v;
}

sub value_cat {
  my ($self,$values) = @_;

  my $out = $self->_value_canon('');
  foreach my $v (@$values) {
    $v = $self->_value_canon($v);
    $out->add($v);
  }
  return $out;
}

sub value_append {
  my ($self,$target,$values) = @_;

  $$target = $self->_value_canon($$target);
  foreach my $v (@$values) {
    $v = $self->_value_canon($v);
    $$target->add($v);
  }
}

sub value_control {
  my ($self,$target,$control) = @_;

  $$target = $self->_value_canon($$target);
  $$target->control($control);
}

sub value_length {
  my ($self,$value) = @_;

  return $self->_value_canon($value)->size;
}

sub value_emit {
  my ($self,$value,$writer) = @_;

  foreach my $el (@{$value->members}) {
    if(ref($el->string)) { $writer->print($el->string); }
    else { my $fmt = $el->format; $writer->print([\$fmt,$el->string]); }
  }
}


1;
