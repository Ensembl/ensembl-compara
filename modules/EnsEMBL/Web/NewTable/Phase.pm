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

package EnsEMBL::Web::NewTable::Phase;

use strict;
use warnings;

use MIME::Base64;
use Compress::Zlib;
use JSON;

sub compress_block {
  return encode_base64(compress(JSON->new->encode($_[0])));
}

sub uncompress_block {
  return JSON->new->decode(uncompress(decode_base64($_[0])));
}

sub new {
  my ($proto,$component,$callback,$phase,$row_start,$shadow_start,$size_needed,$config,$wire) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    type => $config->type,
    callback => $callback,
    component => $component,
    phase_name => $phase->{'name'},
    size_needed => $size_needed,
    page_rows => $wire->{'pagerows'},
    phase_rows => $phase->{'rows'},
    filter => $wire->{'filter'},
    config => $config,
    enumerate => $wire->{'enumerate'},
    sort => $wire->{'sort'},
    #
    data => [], nulls => [], len => [],
    indata => [], innulls => [], inlen => 0,
    series => $phase->{'cols'},
    order => undef,
    start => $row_start,
    shadow_num => $shadow_start,
    #
    sort_data => [],
    null_cache => [],
    request_num => 0,
    stand_down => 0,
  };
  bless $self,$class;
  return $self;
}

sub stand_down {
  my ($self) = @_;

  return 0 if $self->{'size_needed'};
  return $self->{'stand_down'};
}

sub free_wheel {
  my ($self) = @_;

  if($self->{'stand_down'}) {
    $self->{'shadow_num'}++;
    return 1;
  }
  return 0;
}

sub phase { return $_[0]->{'phase_name'}; }

sub add_enum {
  my ($self,$row) = @_;

  foreach my $colkey (@{$self->{'enumerate'}||[]}) {
    my $column = $self->{'config'}->column($colkey);
    my $values = ($self->{'callback'}{'enum_values'}{$colkey}||={});
    $column->add_value($values,$row->{$colkey});
  }
}

sub server_filter {
  my ($self,$row) = @_;

  foreach my $col (keys %{$self->{'filter'}||{}}) {
    my $column = $self->{'config'}->column($col);
    next unless exists $row->{$col};
    my $ok_col = 0;
    my $values = $column->split($row->{$col});
    foreach my $value (@{$values||[]}) {
      my $fv = $self->{'filter'}{$col};
      if($column->is_match($fv,$value)) {
        $ok_col = 1;
        last;
      }
    }
    return 0 unless $ok_col;
  }
  return 1;
}

sub passes_muster {
  my ($self,$row) = @_;

  my $rows = $self->{'page_rows'};
  my $prows = $self->{'phase_rows'};
  if($rows) {
    return 0 if $self->{'shadow_num'}-1 <  $rows->[0];
    return 0 if $self->{'shadow_num'}-1 >= $rows->[1];
  }
  if($prows) {
    return 0 if $self->{'shadow_num'}-1 <  $prows->[0];
    return 0 if $self->{'shadow_num'}-1 >= $prows->[1];
  }
  return 0 unless $self->server_filter($row);
  return 1;
}

sub server_order {
  my ($self,$row) = @_;

  my $sort = $self->{'sort'};
  foreach my $i (0..$#$sort) {
    push @{$self->{'sort_data'}[$i]||=[]},$row->{$sort->[$i]{'key'}};
  }
  push @{$self->{'sort_data'}[@$sort]||=[]},$self->{'shadow_num'};
}

sub server_nulls {
  my ($self,$row) = @_;

  my $series = $self->{'series'};
  my %nulls;
  foreach my $j (0..$#$series) {
    my $col = $self->{'config'}->column($series->[$j]);
    my $null_cache = ($self->{'null_cache'}[$j]||={});
    my $v = $row->{$series->[$j]};
    my $is_null = (!defined $v);
    $is_null = $null_cache->{$v} unless $is_null;
    unless(defined $is_null) {
      $is_null = $col->is_null($v);
      $null_cache->{$v} = $is_null;
    }
    $nulls{$series->[$j]} = 0+$is_null;
  }
  return \%nulls;
}

sub add_row_data {
  my ($self,$row,$nulls) = @_;

  foreach my $i (0..$#{$self->{'series'}}) {
    my $k = $self->{'series'}[$i];
    $self->{'indata'}[$i]||=[];
    push @{$self->{'innulls'}[$i]||=[]},$nulls->{$k};
    push @{$self->{'indata'}[$i]||=[]},$row->{$k} unless $nulls->{$k};
  }
}

sub consolidate {
  my ($self) = @_;

  push @{$self->{'data'}},compress_block($self->{'indata'});
  push @{$self->{'nulls'}},compress_block($self->{'innulls'});
  push @{$self->{'len'}},$self->{'inlen'};
  $self->{'indata'} = [];
  $self->{'innulls'} = [];
  $self->{'inlen'} = 0;
}

sub add_row {
  my ($self,$row) = @_;

  my $rows = $self->{'page_rows'};
  my $prows = $self->{'phase_rows'};
  if(($rows  and $self->{'shadow_num'}>= $rows->[1]) or
     ($prows and $self->{'shadow_num'}>=$prows->[1])) {
    $self->{'stand_down'} = 1;
  }
  $self->{'shadow_num'}++;
  return 0 unless $self->passes_muster($row);
  $self->{'request_num'}++;
  $self->add_enum($row);
  if($self->{'sort'} and @{$self->{'sort'}}) {
    $self->server_order($row);
  }
  my $nulls = $self->server_nulls($row);
  $self->add_row_data($row);
  $self->{'inlen'}++;
}

sub go {
  my ($self) = @_;

  my $type =~ s/\W//g;
  my $func = "table_content";
  $func .= "_$type" if $type;

  $self->{'component'}->$func($self);
  $self->consolidate();

  return {
    out => {
      data => $self->{'data'},
      nulls => $self->{'nulls'},
      len => $self->{'len'},
      series => $self->{'series'},
      order => $self->{'order'},
      start => $self->{'start'},
      shadow_num => $self->{'shadow_num'},
    },
    request_num => $self->{'request_num'},
    shadow_num => $self->{'shadow_num'},
  };
}

1;
