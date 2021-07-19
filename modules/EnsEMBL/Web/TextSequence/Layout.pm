=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Layout;

use strict;
use warnings;

sub new {
  my ($proto,$spec,$old) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    spec => $spec||[],
    filters => [],
  };
  bless $self,$class;
  $self->{'value'} = $old?$old->value:$self->value_empty;
  return $self;
}

sub value { return $_[0]->{'value'}; }

# These are for overriding in the subclasses
sub value_prepare { return $_[1]; }
sub value_append { ${$_[1]} = $_[0]->value_cat([${$_[1]},@{$_[2]}]); }
sub value_control { $_[0]->value_append($_[1],$_[2]); }
sub value_emit { return $_[1]; }

sub value_empty { die "must override"; }
sub value_pad { die "must override"; }
sub value_length { die "must override"; }
sub value_fmt { die "must override"; }
sub value_cat { die "must override"; }

#

sub add {
  my ($self,$spec) = @_;

  push @{$self->{'spec'}},@$spec;
}

sub _do_pad {
  my ($self,$value,$pad) = @_;

  return $value unless defined $pad;
  my $right = 0;
  if($pad<0) { $pad = -$pad; $right=1; }
  $pad -= $self->value_length($value);
  return $value if $pad <= 0;
  my @v = ($self->value_pad($pad),$value);
  @v = reverse @v if $right;
  return $self->value_cat(\@v);
}

sub _find_value {
  my ($self,$spec,$data,$key) = @_;

  my $v = $data->{$key}//$self->value_empty;
  if(defined $spec->{'width'}) {
    if(ref($spec->{'width'})) {
      $v = $self->_do_pad($v,$spec->{'width'}{$key});
    } else {
      $v = $self->_do_pad($v,$spec->{'width'});
    }
  }
  return $v;
}

sub _render_one {
  my ($self,$spec,$data) = @_;

  my $value = $self->value_empty;
  if($spec->{'fmt'}) {
    my @values = map { $self->_find_value($spec,$data,$_) } @{$spec->{'key'}};
    $value = $self->value_fmt($spec->{'fmt'},\@values);
  } else {
    $value = $self->_find_value($spec,$data,$spec->{'key'}) if $spec->{'key'};
  }
  $value //= $self->value_empty;
  $value = $self->value_cat([$value,$spec->{'post'}]) if $spec->{'post'};
  if(defined $spec->{'width'}) {
    my $w = $spec->{'width'};
    $w = $w->{''} if ref($w);
    $value = $self->_do_pad($value,$w);
  }
  $self->value_control(\$self->{'value'},$spec->{'control'}) if $spec->{'control'};
  return $value;
}

sub filter { push @{$_[0]->{'filters'}},$_[1]; }

sub apply {
  my ($self,$data,$sub) = @_;

  foreach my $s (@{$self->{'spec'}}) {
    my $fields = [$s];
    if($s->{'if'}) {
      next unless $data->{$s->{'if'}};
      $fields = $s->{'then'};
    }
    foreach my $f (@$fields) {
      $sub->($self,$data,$f);
    }
  }
}

sub prepare {
  my ($self,$data) = @_;

  $data = $_->($self,$data) for(@{$self->{'filters'}});
  # make room
  $self->apply($data,sub {
    my ($self,$data,$f) = @_;
    return unless $f->{'room'};
    my $len = $self->value_length($self->_render_one($f,$data));
    return unless defined($f->{'width'}) and abs $len > abs $f->{'width'};
    $f->{'width'} = ($f->{'width'}>0?1:-1)*$len;
  });
}

sub render {
  my ($self,$data) = @_;

  $data = $_->($self,$data) for(@{$self->{'filters'}});
  # render
  $self->apply($data,sub {
    my ($self,$data,$f) = @_;
    $self->value_append(\$self->{'value'},[$self->_render_one($f,$data)]);
  });
}

sub add { $_[0]->value_append(\$_[0]->{'value'},[$_[1]]); }
sub add_control { $_[0]->value_control(\$_[0]->{'value'},$_[1]); }
sub emit {
  my $self = shift;
  return $self->value_emit($self->{'value'},@_);
}

1;
