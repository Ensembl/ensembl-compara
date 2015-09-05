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

use EnsEMBL::Web::Document::NewTableSorts qw(newtable_sort_isnull newtable_sort_cmp newtable_sort_range_value newtable_sort_range_finish newtable_sort_range_match newtable_sort_range_split);

# XXX move all this stuff to somewhere it's more suited

sub server_sort {
  my ($self,$data,$sort,$iconfig,$col_idx,$keymeta) = @_;

  my $cols = $iconfig->{'columns'};
  foreach my $i (0..$#$data) { push @{$data->[$i]},$i; }
  $col_idx->{'__tie'} = -1;
  my %cache;
  @$data = sort {
    my $c = 0;
    foreach my $col ((@$sort,{'dir'=>1,'key'=>'__tie'})) {
      $cache{$col->{'key'}}||={};
      my $idx = $col_idx->{$col->{'key'}};
      my $type = $cols->[$idx]{'sort'}||'string';
      $type = 'numeric' if $col->{'key'} eq '__tie';
      $c = newtable_sort_cmp($type,$a->[$idx],$b->[$idx],$col->{'dir'},$keymeta,$cache{$col->{'key'}},$col->{'key'});
      last if $c;
    }
    $c;
  } @$data;
  pop @$_ for(@$data);
}

sub server_nulls {
  my ($self,$data,$iconfig) = @_;

  my $cols = $iconfig->{'columns'};
  foreach my $j (0..$#$cols) {
    my $col = $cols->[$j];
    foreach my $i (0..$#$data) {
      my $is_null = newtable_sort_isnull($col->{'sort'},$data->[$i][$j]);
      $data->[$i][$j] = [$data->[$i][$j],0+$is_null];
    }
  }
}

sub passes_muster {
  my ($self,$row,$rq) = @_;

  my $ok = 1;
  foreach my $col (keys %{$rq->{'wire'}{'filter'}}) {
    my $colconf = $rq->{'config'}{'columns'}[$rq->{'cols_pos'}{$col}];
    next unless exists $row->{$col};
    my $val = $row->{$col};
    my $ok_col = 0;
    my $values = newtable_sort_range_split($colconf->{'sort'},$val);
    foreach my $value (@{$values||[]}) {
      my $fv = $rq->{'wire'}{'filter'}{$col};
      if(newtable_sort_range_match($colconf->{'sort'},$fv,$value)) {
        $ok_col = 1;
        last;
      }
    }
    unless($ok_col) { $ok = 0; last; }
  }
  return $ok;
}

sub register_key {
  my ($self,$key,$meta) = @_;

  $self->{'key_meta'}||={};
  $self->{'key_meta'}{$key}||={};
  foreach my $k (keys %{$meta||{}}) {
    $self->{'key_meta'}{$key}{$k} = $meta->{$k} unless exists $self->{'key_meta'}{$key}{$k};
  } 
}

sub ajax_table_content {
  my ($self) = @_;

  my $hub = $self->hub;
  my $iconfig = from_json($hub->param('config'));
  my $orient = from_json($hub->param('orient'));
  my $wire = from_json($hub->param('wire'));
  my $more = $hub->param('more');
  my $incr_ok = ($hub->param('incr_ok') eq 'true');
  my $keymeta = from_json($hub->param('keymeta'));

  return $self->newtable_data_request($iconfig,$orient,$wire,$more,$incr_ok,$keymeta);
}

sub newtable_data_request {
  my ($self,$iconfig,$orient,$wire,$more,$incr_ok,$keymeta) = @_;

  my @cols = map { $_->{'key'} } @{$iconfig->{'columns'}};
  my %cols_pos;
  $cols_pos{$cols[$_]} = $_ for(0..$#cols);

  my $phases = [{ name => undef }];
  $phases = $self->incremental_table if $self->can('incremental_table');
  my @out;

  # What phase should we be?
  my @required;
  push @required,map { $_->{'key'} } @{$wire->{'sort'}||[]};
  if($incr_ok) {
    while($more < $#$phases) {
      my %gets_cols = map { $_ => 1 } (@{$phases->[$more]{'cols'}||\@cols});
      last unless scalar(grep { !$gets_cols{$_} } @required);
      $more++;
    }
  } else {
    $more = $#$phases;
  }

  # Check if we need to request all rows due to sorting
  my $all_data = 0;
  if($wire->{'sort'} and @{$wire->{'sort'}}) {
    $all_data = 1;
  }

  # Start row
  my $irows = $phases->[$more]{'rows'} || [0,-1];
  my $rows = $irows;
  $rows = [0,-1] if $all_data;

  # Calculate columns to send
  my $used_cols = $phases->[$more]{'cols'} || \@cols;
  my $columns = [ (0) x @cols ];
  $columns->[$cols_pos{$_}] = 1 for @$used_cols;
  my %sort_pos;
  $sort_pos{$used_cols->[$_]} = $_ for (0..@$used_cols);

  # Calculate function name
  my $type = $iconfig->{'type'};
  $type =~ s/\W//g;
  my $func = "table_content";
  $func .= "_$type" if $type;

  # Populate data
  my $rq = {
    config => $iconfig,
    cols_pos => \%cols_pos,
    wire => $wire,
  };
  my $data = $self->$func($phases->[$more]{'name'},$rows,$iconfig->{'unique'},$rq);

  # Enumerate, if necessary
  my %enums;
  foreach my $colkey (@{$wire->{'enumerate'}||[]}) {
    my $colconf = $iconfig->{'columns'}[$cols_pos{$colkey}];
    my $row_pos = $sort_pos{$colkey};
    next unless defined $row_pos;
    my %values;
    foreach my $r (@$data) {
      my $value = $r->{$colkey};
      newtable_sort_range_value($colconf->{'sort'},\%values,$value);
    }
    $enums{$colkey} =
      newtable_sort_range_finish($colconf->{'sort'},\%values);
  }
  my %shadow = %$orient;
  delete $shadow{'filter'};

  # Filter, if necessary
  if($wire->{'filter'}) {
    my @new;
    foreach my $row (@$data) {
      push @new,$row if $self->passes_muster($row,$rq);
    }
    $data = \@new;
  }

  # Map to column format
  my @data_out;
  foreach my $d (@$data) {
    push @data_out,[ map { $d->{$_}||'' } @$used_cols ];
  }

  # Move on continuation counter
  $more++;
  $more=0 if $more == @$phases;

  # Sort it, if necessary
  if($wire->{'sort'} and @{$wire->{'sort'}}) {
    $self->server_sort(\@data_out,$wire->{'sort'},$iconfig,\%sort_pos,$keymeta);
    splice(@data_out,0,$irows->[0]);
    splice(@data_out,$irows->[1]) if $irows->[1] >= 0;
  }
  $self->server_nulls(\@data_out,$iconfig);

  # Send it
  return {
    response => {
      data => \@data_out,
      columns => $columns,
      start => $rows->[0],
      more => $more,
      enums => \%enums,
      shadow => \%shadow,
      keymeta => $self->{'key_meta'},
    },
    orient => $orient,
  };
}

1;
