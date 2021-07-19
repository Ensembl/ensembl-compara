=head1 sLICENSE

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

package EnsEMBL::Web::NewTable::Column::Numeric;

use strict;
use warnings;
use parent qw(EnsEMBL::Web::NewTable::Column);

use List::Util qw(min max);
use Scalar::Util qw(looks_like_number);

sub js_type { return 'numeric'; }
sub js_range { return 'range'; }
sub clean { my $x=$_[1]; $x =~ s/([\d\.e\+-])\s.*$/$1/; return $x; }
sub null { return !looks_like_number($_[1]); }
sub cmp { return (($_[1]||0) <=> ($_[2]||0))*$_[3]; }

sub match {
  my ($self,$range,$value) = @_;

  if(looks_like_number($value)) {
    if(exists $range->{'min'}) {
      return 0 unless $value>=$range->{'min'};
    }
    if(exists $range->{'max'}) {
      return 0 unless $value<=$range->{'max'};
    }
  } else {
    if($range->{'no_nulls'}) { return !$range->{'no_nulls'}; }
  }
  return 1;
}

sub has_value {
  my ($self,$range,$value) = @_;

  if(!looks_like_number($value)) { return; }
  if(exists $range->{'min'}) {
    $range->{'max'} = max($range->{'max'},$value);
    $range->{'min'} = min($range->{'min'},$value);
  } else {
    $range->{'min'} = $range->{'max'} = $value;
  }
}

1;
