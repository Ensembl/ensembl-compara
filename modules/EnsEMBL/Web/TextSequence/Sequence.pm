=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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
    # the sequence itself
    seq => [],
    idx => 0,
  };
  bless $self,$class;
  weaken($self->{'view'});
  $self->init;
  return $self;
}

sub init {} # For subclasses
sub ready {} # For subclasses
sub fixup_markup {} # For subclasses

sub principal { $_[0]->{'principal'} = $_[1] if @_>1; return $_[0]->{'principal'}; }

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

sub move { $_[0]->{'idx'}[$_[1]] = $_[2]; }

sub _here { return ($_[0]->{'seq'}[$_[0]->{'idx'}]||={}); }

sub set { $_[0]->_here->{$_[1]} = $_[2]; }
sub add { push @{$_[0]->_here->{$_[1]}},$_[2]; }
sub append { $_[0]->_here->{$_[1]} .= $_[2]; }

# only for use in Line
sub _exon {
  my ($self,$val) = @_;

  $self->{'exon'} = $val if @_>1;
  return $self->{'exon'};
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

  my $name = $self->name || '';
  $name .= ' ' x ($self->{'view'}->field_size('name') - length $name);
  return $name;
}

sub pre {
  my ($self,$val) = @_;

  ($self->{'pre'}||="") .= $val if @_>1;
  return $self->{'pre'};
}

sub id { return $_[0]->{'id'}; }

sub add_data {
  my ($self,$lines,$config) = @_;

  my $line;
  foreach my $seq (@$lines) {
    $line = $self->new_line if !$line;
    $line->add_post($seq->{'post'});
    $line->markup('letter',$seq->{'letter'});
    $line->markup('class',$seq->{'class'});
    $line->markup('title',$seq->{'title'});
    $line->markup('href',$seq->{'href'});
    $line->markup('tag',$seq->{'tag'});
    $line->markup('new_letter',$seq->{'new_letter'});
    $line->advance;
    if($line->full) { $line->add($config); $line = undef; }
  }
  $line->add($config) if $line;
}

1;
