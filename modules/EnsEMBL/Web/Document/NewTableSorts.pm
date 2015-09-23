=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::NewTableSorts;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);
use List::Util qw(min max);

use List::MoreUtils qw(each_array);

use Exporter qw(import);
our @EXPORT_OK = qw(newtable_sort_range_value
                    newtable_sort_range_split
                    newtable_sort_range_finish newtable_sort_range_match);

# range_split -- server side code for breaking up composite values
# range_value -- server side code for adding to enumeration
# range_finish -- server side code for finalising enumeration
# range_match -- server side code for applying filter

my %SORTS = (
  '_default' => {
    range_split => sub { return [$_[0]->{'clean'}->($_[1])]; },
    range_value => sub { $_[0]->{$_[1]} = 1; },
    range_finish => sub { return [sort keys %{$_[0]}]; },
    range_match => sub {
      foreach my $x (keys %{$_[0]}) {
        return 0 if lc $x eq lc $_[1];
      }
      return 1;
    },
  },
  'string' => {
  },
  'numeric' => {
    range_value => sub {
      if(!looks_like_number($_[1])) { return; }
      if(exists $_[0]->{'min'}) {
        $_[0]->{'max'} = max($_[0]->{'max'},$_[1]);
        $_[0]->{'min'} = min($_[0]->{'min'},$_[1]);
      } else {
        $_[0]->{'min'} = $_[0]->{'max'} = $_[1];
      }
    },
    range_finish => sub { return $_[0]||={}; },
    range_match => sub {
      if(looks_like_number($_[1])) {
        if(exists $_[0]->{'min'}) {
          return 0 unless $_[1]>=$_[0]->{'min'};
        }
        if(exists $_[0]->{'max'}) {
          return 0 unless $_[1]<=$_[0]->{'max'};
        }
        return 1;
      } else {
        if(exists $_[0]->{'nulls'}) { return $_[0]->{'nulls'}; }
        return 1;
      }
    },
  },
  'integer' => [qw(numeric)],
  'position' => {
    range_value => sub {
      my ($acc,$value) = @_;

      return unless $value =~ /^(.*?):(\d+)/;
      my ($chr,$pos) = ($1,$2);
      $acc->{$chr} ||= { chr => $chr };
      if(exists $acc->{$chr}{'min'}) {
        $acc->{$chr}{'max'} = max($acc->{$chr}{'max'},$pos);
        $acc->{$chr}{'min'} = min($acc->{$chr}{'min'},$pos);
      } else {
        $acc->{$chr}{'min'} = $acc->{$chr}{'max'} = $pos;
      }
      ($acc->{$chr}{'count'}||=0)++;
    },
    range_finish => sub { return $_[0]; },
    range_match => sub {
      my ($man,$val) = @_;
      if($val =~ s/^$man->{'chr'}://) {
        if(exists $man->{'min'}) {
          return 0 unless $val>=$man->{'min'};
        }
        if(exists $man->{'max'}) {
          return 0 unless $val<=$man->{'max'};
        }
        return 1;
      } else {
        if(exists $man->{'nulls'}) { return $man->{'nulls'}; }
        return 1;
      }
    },
  },
  iconic => {
    range_split => sub { return [ split(/~/,$_[1]) ]; },
  },
);

my %sort_cache;
sub get_sort {
  my ($name) = @_;

  my $out = {};
  return $sort_cache{$name} if exists $sort_cache{$name};
  $sort_cache{$name}||= {};
  add_sort($sort_cache{$name},[$name,'_default']);
  return $sort_cache{$name};
}

sub add_sort {
  my ($out,$names) = @_;

  foreach my $name (@$names) {
    my $ss = $SORTS{$name};
    if(ref($ss) eq 'ARRAY') { add_sort($out,$ss); next; }
    foreach my $k (keys %$ss) {
      $out->{$k} = $ss->{$k} unless exists $out->{$k};
    } 
  }
  return $out;
}

sub newtable_sort_range_split {
  my ($type,$values) = @_;

  my $conf = get_sort($type);
  return $conf->{'range_split'}->($conf,$values);
}

sub newtable_sort_range_value {
  my ($type,$values,$value) = @_;

  my $conf = get_sort($type);
  my $vv = newtable_sort_range_split($type,$value) if defined $value;
  return unless defined $values;
  foreach my $v (@$vv) {
    $conf->{'range_value'}->($values,$v);
  }
}

sub newtable_sort_range_finish {
  my ($type,$values) = @_;

  return get_sort($type)->{'range_finish'}->($values);
}

sub newtable_sort_range_match {
  my ($type,$x,$y) = @_;

  return 0 unless defined $y;
  return get_sort($type)->{'range_match'}->($x,$y);
}

1;
