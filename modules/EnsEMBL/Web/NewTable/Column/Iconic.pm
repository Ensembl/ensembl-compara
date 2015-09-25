=head1 sLICENSE

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
      $km->{"decorate/iconic/$col/$_"}{'order'} ||
      $km->{"decorate/iconic/$col/$_"}{'export'} || '~';
    } @vals;
  }
  return join('~',reverse sort @vals);
}

sub cmp {
  my ($x,$y,$f,$c,$km,$col) = @_;

  $c->{$x} = iconic_build_key($km,$col,$x) unless exists $c->{$x};
  $c->{$y} = iconic_build_key($km,$col,$y) unless exists $c->{$y};
  return ($c->{$x} cmp $c->{$y})*$f;
}

sub split { return [ split(/~/,$_[1]) ]; }
sub has_value { return $_[1]->{$_[2]} = 1; }
sub range { return [sort keys %{$_[1]}]; }

1;
