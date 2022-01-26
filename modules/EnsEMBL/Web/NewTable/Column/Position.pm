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

package EnsEMBL::Web::NewTable::Column::Position;

use strict;
use warnings;
use parent qw(EnsEMBL::Web::NewTable::Column);

use List::Util qw(min max);
use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw(each_array);

sub null {
  my ($v) = @_; 

  $v =~ s/^.*://;
  my @v = split(/:-/,$v);
  shift @v; 
  foreach my $c (@v) {
    return 1 if !looks_like_number($c);
  }   
  return 0;
}

sub js_type { return 'position'; }
sub js_range { return 'position'; }

sub configure {
  my ($self,$mods,$args) = @_;

  $args->{'filter_integer'} = 1 unless exists $args->{'filter_integer'};
  $self->SUPER::configure($mods,$args);
}

sub cmp {
  my ($self,$a,$b,$f) = @_;

  my @a = split(/[:-]/,$a);
  my @b = split(/[:-]/,$b);
  my $it = each_array(@a,@b);
  while(my ($aa,$bb) = $it->()) {
    my $c = ($aa <=> $bb)*$f;
    return $c if $c; 
  }
  return 0;
}

sub match {
  my ($self,$range,$value) = @_;

  if($value =~ s/^$range->{'chr'}://) {
    if(exists $range->{'min'}) {
      return 0 unless $value>=$range->{'min'};
    }
    if(exists $range->{'max'}) {
      return 0 unless $value<=$range->{'max'};
    }
  } else {
    if($range->{'no_nulls'}) { return $range->{'no_nulls'}; }
  }
  return 1;
}

sub has_value {
  my ($self,$range,$value) = @_;

  return unless $value =~ /^(.*?):(\d+)/;
  my ($chr,$pos) = ($1,$2);
  $range->{$chr} ||= { chr => $chr };
  if(exists $range->{$chr}{'min'}) {
    $range->{$chr}{'max'} = max($range->{$chr}{'max'},$pos);
    $range->{$chr}{'min'} = min($range->{$chr}{'min'},$pos);
  } else {
    $range->{$chr}{'min'} = $range->{$chr}{'max'} = $pos;
  }   
  ($range->{$chr}{'count'}||=0)++;
}

1;
