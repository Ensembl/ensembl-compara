=head1 sLICENSE

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

package EnsEMBL::Web::NewTable::Column::Iconic;

use strict;
use warnings;
use parent qw(EnsEMBL::Web::NewTable::Column);

sub js_type { return 'iconic'; }
sub js_range { return 'class'; }
sub null { return $_[1] !~ /\S/; }

sub iconic_build_key {
  my ($km,$col,$in) = @_;

  my @vals = split(/~/,$in||'');
  if($km) {
    @vals = map {
      my $m = $km->{"decorate/iconic"}{$col->key()}{$_};
      my $value;
      if(defined $m->{'order'}) {
        $value = sprintf("^%16d",$m->{'order'});
      }
      if(defined $m->{'export'} and not defined $value) {
        $value = '_'.substr($m->{'export'},0,16);
      }
      $value = '~' unless defined $value;
      $value;
    } @vals;
  }
  return join('~',reverse sort @vals);
}

sub cmp {
  my ($self,$x,$y,$f,$c,$km,$col) = @_;

  if($km->{"decorate/iconic"}{$col}{"*"}{'icon_source'}) {
    return (lc $x cmp lc $y)*$f;
  }
  $c->{$x} = iconic_build_key($km,$col,$x) unless exists $c->{$x};
  $c->{$y} = iconic_build_key($km,$col,$y) unless exists $c->{$y};
  return ($c->{$x} cmp $c->{$y})*$f;
}

sub split { return $_[1]?[split(/~/,$_[1])]:[]; }
sub has_value {
  return ($_[1]->{$_[2]}||=0)++;
}

sub range {
  my ($self,$values,$km,$col,$pre) = @_;

  my %c;
  my %all = %{$values||{}};
  if($pre and $pre->{'counts'}) {
    ($all{$_}||=0)+=$pre->{'counts'}{$_} for keys %{$pre->{'counts'}};
  }
  $all{$_}||=0 for keys %{($km->{'decorate/iconic'}||{})->{$col->key}};
  my @keys = sort { $self->cmp($a,$b,1,\%c,$km,$col)  } keys %all;
  return {
    keys => \@keys,
    counts => \%all,
  };
}

1;
