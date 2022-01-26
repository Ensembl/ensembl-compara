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

package EnsEMBL::Web::TextSequence::ClassToStyle::RTF;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::ClassToStyle);

my %CODES = (
  'color' => '\cf@',
  'background-color' => '\chshdng0\chcbpat@\cb@',
);

sub style {
  my ($self,$key,$value) = @_;

  $self->{'colours'} ||= [undef];
  if($key eq 'color' or $key eq 'background-color') {
    my $idx = ($self->{'index'}||=1)++;
    my $k = $CODES{$key};
    $k =~ s/\@/$idx/g;
    $value =~ s/#//;
    push @{$self->{'colours'}},[map { hex $_ } unpack('A2A2A2',$value)];
    return ($key,[$k,$value]);
  } elsif($key eq 'font-weight' and $value eq 'bold') {
    return ('weight',['\b',1]);
  } elsif($key eq 'text-decoration' and $value eq 'underline') {
    return ('decoration',['\ul',1]);
  } elsif($key eq 'text-transform' and $value eq 'lowercase') {
    return('transform',["\0",1]); # Signal to force transform
  }
}

sub convert_class_to_style {
  my ($self,$current_class,$config) = @_;

  return undef unless @$current_class;
  my %class_to_style = %{$self->make_class_to_style_map($config)};
  my %style_hash;
  my @class_order;
  foreach my $key (@$current_class) {
    $key = lc $key unless $class_to_style{$key};
    push @class_order,[$key,$class_to_style{$key}[1]];
  }
  foreach my $values (sort { $a->[0] cmp $b->[0] } @class_order) {
    my $st = $values->[1];
    map $style_hash{$_} = $st->{$_}, keys %$st;
  }
  return join('',map { $_->[0] } values %style_hash);
}

sub colours { return $_[0]->{'colours'}; }

1;
