=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::NewTable;

use strict;

use JSON qw(from_json);

# XXX move all this stuff to somewhere it's more suited

sub server_sort {
  my ($self,$data,$sort,$cols) = @_;

  my %col_idx;
  foreach my $i (0..(@$cols-1)) {
    $col_idx{$cols->[$i]{'key'}} = $i;
  }
  @$data = sort {
    my $c = 0;
    foreach my $col (@$sort) {
      my ($aa,$bb) = ($a,$b);
      ($aa,$bb) = ($b,$a) if $col->{'dir'} < 0;
      my $av = $aa->[$col_idx{$col->{'key'}}];
      my $bv = $bb->[$col_idx{$col->{'key'}}];
      $c = ( $av cmp $bv );
      last if $c;
    }
    $c;
  } @$data;
}

sub ajax_table_content {
  my ($self) = @_;

  my $hub = $self->hub;

  my $phases = [{ name => undef }];
  $phases = $self->incremental_table if $self->can('incremental_table');
  my @out;
  my $more = $hub->param('more');

  my $iconfig = from_json($hub->param('config'));

  my $view = from_json($hub->param('data'));
  use Data::Dumper;
  warn Dumper('view',$view);

  # Check if we need to request all rows due to sorting
  my $all_data = 0;
  if($view->{'sort'} and @{$view->{'sort'}}) {
    $all_data = 1;
  }

  # Start row
  my $irows = $phases->[$more]{'rows'} || [0,-1];
  my $rows = $irows;
  $rows = [0,-1] if $all_data;

  # Calculate columns to send
  my @cols = map { $_->{'key'} } @{$iconfig->{'columns'}};
  my %cols_pos;
  $cols_pos{$cols[$_]} = $_ for(0..$#cols);
  my $used_cols = $phases->[$more]{'cols'} || \@cols;
  my $columns = [ (0) x @cols ];
  $columns->[$cols_pos{$_}] = 1 for @$used_cols;

  # Calculate function name
  my $type = $iconfig->{'type'};
  $type =~ s/\W//g;
  my $func = "table_content";
  $func .= "_$type" if $type;

  # Populate data
  my $data = $self->$func($phases->[$more]{'name'},$rows,$iconfig->{'unique'});
  my @data_out;
  foreach my $d (@$data) {
    push @data_out,[ map { $d->{$_}||'' } @$used_cols ];
  }

  # Move on continuation counter
  $more++;
  $more=0 if $more == @$phases;

  # Sort it, if necessary
  if($view->{'sort'} and @{$view->{'sort'}}) {
    $self->server_sort(\@data_out,$view->{'sort'},$iconfig->{'columns'});
    splice(@data_out,0,$irows->[0]);
    splice(@data_out,$irows->[1]) if $irows->[1] >= 0;
  }

  # Send it
  return {
    data => \@data_out,
    columns => $columns,
    start => $rows->[0],
    more => $more,
  };
}

1;
