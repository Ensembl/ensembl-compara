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
use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw(each_array);

# XXX move all this stuff to somewhere it's more suited

# XXX sort to end

sub html_cleaned {
  my ($x) = @_;

  $x =~ s/<.*?>//g;
  return $x; 
}

sub html_hidden {
  my ($x) = @_;

  return $1 if $x =~ m!<span class="hidden">(.*?)</span>!;
  return $x;
}

sub server_null_numeric {
  my ($self,$v) = @_;

  return !looks_like_number($v);
}

sub server_sort_numeric {
  my ($self,$a,$b,$f) = @_;

  $a =~ s/([\d\.e\+-])\s.*$/$1/;
  $b =~ s/([\d\.e\+-])\s.*$/$1/;
  if(looks_like_number($a)) {
    if(looks_like_number($b)) {
      return ($a <=> $b)*$f;
    } else {
      return -1;
    }
  } elsif(looks_like_number($b)) {
    return 1;
  } else {
    return ($a cmp $b)*$f;
  }
}

sub server_sort_position {
  my ($self,$a,$b,$f) = @_;

  my @a = split(/:-/,$a);
  my @b = split(/:-/,$b);
  my $it = each_array(@a,@b);
  while(my ($aa,$bb) = $it->()) {
    my $c = $self->server_sort_numeric($aa,$bb,$f);
    return $c if $c; 
  }
  return 0;
}

sub server_sort_position_html {
  my ($self,$a,$b,$f) = @_;

  return $self->server_sort_position(html_cleaned($a),html_cleaned($b),$f);
}

sub server_sort_html_numeric {
  my ($self,$a,$b,$f) = @_;

  return $self->server_sort_numeric(html_cleaned($a),html_cleaned($b),$f);
}

sub server_sort_html {
  my ($self,$a,$b,$f) = @_;

  return $self->server_sort_string(html_cleaned($a),html_cleaned($b),$f);
}

sub server_sort_hidden_position {
  my ($self,$a,$b,$f) = @_;

  return $self->server_sort_position(html_hidden($a),html_hidden($b),$f);
}

sub server_sort_string {
  my ($self,$a,$b,$f) = @_;

  return (lc $a cmp lc $b)*$f;
}

sub server_sort_string_hidden {
  my ($self,$a,$b,$f) = @_;

  return $self->server_sort_string(html_hidden($a),html_hidden($b),$f);
}

sub server_sort_numeric_hidden {
  my ($self,$a,$b,$f) = @_;

  return $self->server_sort_numeric(html_hidden($a),html_hidden($b),$f);
}

sub server_sort {
  my ($self,$data,$sort,$iconfig,$col_idx) = @_;

  my %sort_fn;
  my $cols = $iconfig->{'columns'};
  foreach my $i (0..(@$cols-1)) {
    ( my $fn = $cols->[$i]{'sort'} ) =~ s/[^A-Za-z_-]//g;
    my $sort_fn = $self->can("server_sort_$fn");
    $sort_fn = $self->can("server_sort_string") unless defined $sort_fn;
    $sort_fn{$cols->[$i]{'key'}} = $sort_fn;
  }
  foreach my $i (0..$#$data) { push @{$data->[$i]},$i; }
  $col_idx->{'__tie'} = -1;
  $sort_fn{'__tie'} = $self->can("server_sort_numeric");
  @$data = sort {
    my $c = 0;
    foreach my $col ((@$sort,{'dir'=>1,'key'=>'__tie'})) {
      my $av = $a->[$col_idx->{$col->{'key'}}];
      my $bv = $b->[$col_idx->{$col->{'key'}}];
      $c = $sort_fn{$col->{'key'}}->($self,$av,$bv,$col->{'dir'});
      last if $c;
    }
    $c;
  } @$data;
  pop @$_ for(@$data);
}

sub server_nulls {
  my ($self,$data,$iconfig) = @_;

  my $cols = $iconfig->{'columns'};
  my %null_fn;
  foreach my $col (@$cols) {
    ( my $fn = $col->{'sort'} ) =~ s/[^A-Za-z_-]//g;
    my $null_fn = $self->can("server_null_$fn");
    $null_fn = $self->can("server_null_string") unless defined $null_fn;
    $null_fn{$col->{'key'}} = $null_fn;
  }
  foreach my $j (0..$#$cols) {
    my $col = $cols->[$j];
    my $key = $col->{'key'};
    my $fn = $null_fn{$key} || sub { return 0; };
    foreach my $i (0..$#$data) {
      $data->[$i][$j] = [$data->[$i][$j],0+$fn->($self,$data->[$i][$j])];
    }
  }
}

sub ajax_table_content {
  my ($self) = @_;

  my $hub = $self->hub;
  my $iconfig = from_json($hub->param('config'));
  my $orient = from_json($hub->param('orient'));
  my $more = $hub->param('more');
  my $incr_ok = ($hub->param('incr_ok') eq 'true');

  return $self->newtable_data_request($iconfig,$orient,$more,$incr_ok);
}

sub newtable_data_request {
  my ($self,$iconfig,$orient,$more,$incr_ok) = @_;

  my @cols = map { $_->{'key'} } @{$iconfig->{'columns'}};

  my $phases = [{ name => undef }];
  $phases = $self->incremental_table if $self->can('incremental_table');
  my @out;

  # What phase should we be?
  my @required;
  push @required,map { $_->{'key'} } @{$orient->{'sort'}||[]};
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
  if($orient->{'sort'} and @{$orient->{'sort'}}) {
    $all_data = 1;
  }

  # Start row
  my $irows = $phases->[$more]{'rows'} || [0,-1];
  my $rows = $irows;
  $rows = [0,-1] if $all_data;

  # Calculate columns to send
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
  if($orient->{'sort'} and @{$orient->{'sort'}}) {
    my %sort_pos;
    $sort_pos{$used_cols->[$_]} = $_ for (0..@$used_cols);
    $self->server_sort(\@data_out,$orient->{'sort'},$iconfig,\%sort_pos);
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
    },
    orient => $orient,
  };
}

1;
