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

package EnsEMBL::Web::TextSequence::Layout::Structured::List;

use strict;
use warnings;

use EnsEMBL::Web::TextSequence::Layout::Structured::Element;

sub new {
  my ($proto,$initial) = @_; 

  my $class = ref($proto) || $proto;
  my $self = { 
    members => [],
  };  
  bless $self,$class;
  if(defined $initial) {
    foreach my $v (@$initial) {
      my $el = $self->_new_el($v->[1],$v->[0]);
      $self->_add_one($el);
    }
  }
  return $self;
}

sub members { return $_[0]->{'members'}; }

sub _new_el { # just for brevity
  shift;
  return EnsEMBL::Web::TextSequence::Layout::Structured::Element->new(@_);
}

sub _add_one {
  my ($self,$element) = @_;

  if(@{$self->{'members'}} and
     !ref($self->{'members'}[-1]->string) and
     !ref($element->string) and
     $self->{'members'}[-1]->format eq $element->format) {
    $self->{'members'}[-1]->append($element->string);
  } else {
    push @{$self->{'members'}},$element;
  }
}

sub add {
  my ($self,$list) = @_;

  foreach my $el (@{$list->{'members'}}) {
    $self->_add_one($el);
  }
}

sub control {
  my ($self,$value) = @_;

  my $valuer = $value;
  $self->_add_one($self->_new_el(\$valuer,undef));
}

sub size {
  my ($self) = @_;

  my $len = 0;
  $len += $_->size for(@{$self->{'members'}});
  return $len;
}

1;
