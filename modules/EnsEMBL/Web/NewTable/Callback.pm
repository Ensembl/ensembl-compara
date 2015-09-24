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

package EnsEMBL::Web::NewTable::Callback;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::NewTable::Endpoint);

use JSON qw(from_json);

use Compress::Zlib;
use Digest::MD5 qw(md5_hex);
use SiteDefs;
use Text::CSV;

# XXX move all this stuff to somewhere it's more suited

sub new {
  my ($proto,$hub,$component) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    hub => $hub,
    component => $component,
    rows => [],
    enum_values => {},
    num => 0,
  };
  bless $self,$class;
  return $self;
}
  

sub add_enum {
  my ($self,$row) = @_;

  foreach my $colkey (@{$self->{'wire'}{'enumerate'}||[]}) {
    my $column = $self->{'columns'}{$colkey};
    my $values = ($self->{'enum_values'}{$colkey}||={});
    my $value = $row->{$colkey};
    $column->add_value($values,$value);
  }
}

sub finish_enum {
  my ($self,$row) = @_;

  my %enums;
  foreach my $colkey (@{$self->{'wire'}{'enumerate'}||[]}) {
    my $column = $self->{'columns'}{$colkey};
    $enums{$colkey} = $column->range($self->{'enum_values'}{$colkey}||{});
  }
  return \%enums;
}

sub add_row {
  my ($self,$row) = @_;

  $self->{'num'}++;
  return 0 unless $self->passes_muster($row,$self->{'num'}); 
  $self->add_enum($row); 
  push @{$self->{'data'}},[ map { $row->{$_} } @{$self->{'used_cols'}} ];
  return 1;
}

sub go {
  my ($self) = @_;

  my $hub = $self->{'hub'};
  $self->{'iconfig'} = from_json($hub->param('config'));
  my $orient = from_json($hub->param('orient'));
  $self->{'wire'} = from_json($hub->param('wire'));
  my $more = $hub->param('more');
  my $incr_ok = ($hub->param('incr_ok')||'' eq 'true');
  my $keymeta = from_json($hub->param('keymeta'));
  # Add plugins
  my $ssplugins = from_json($hub->param('ssplugins'));
  foreach my $name (keys %$ssplugins) {
    $name =~ s/\W//g;
    $self->add_plugin($name,$ssplugins->{$name});
  } 
  # Add columns
  $self->{'columns'} = {};
  foreach my $key (keys %{$self->{'iconfig'}{'colconf'}}) {
    my $cc = $self->{'iconfig'}{'colconf'}{$key};
    $self->{'columns'}{$key} =
      EnsEMBL::Web::NewTable::Column->new($self,$cc->{'sstype'},$key);
  }

  my $out = $self->newtable_data_request($orient,$more,$incr_ok,$keymeta);
  if($self->{'wire'}{'format'} eq 'export') {
    $out = convert_to_csv($self->{'iconfig'},$out);
    my $r = $hub->apache_handle;
    $r->content_type('application/octet-string');
    $r->headers_out->add('Content-Disposition' => sprintf 'attachment; filename=%s.csv', $hub->param('filename')||'ensembl-export.csv');
  }
  return $out;
}

sub preload {
  my ($self,$table,$config,$orient) = @_;

  $self->{'iconfig'} = $config;
  $self->{'wire'} = $orient;
  $self->{'columns'} = $table->columns;
  return $self->newtable_data_request($orient,undef,1);
}

sub server_sort {
  my ($self,$data,$sort,$iconfig,$series,$keymeta) = @_;

  my $cols = $iconfig->{'columns'};
  my $colconf = $iconfig->{'colconf'};
  foreach my $i (0..$#$data) { push @{$data->[$i]},$i; }
  my %cache;
  my %rseries;
  $rseries{$series->[$_]} = $_ for (0..$#$series);
  $rseries{'__tie'} = -1;
  @$data = sort {
    my $c = 0;
    foreach my $col ((@$sort,{'dir'=>1,'key'=>'__tie'})) {
      my $key = $col->{'key'};
      my $column;
      if($key eq '__tie') {
        $column = EnsEMBL::Web::NewTable::Column->new($self,'numeric','__tie');
      } else {
        $column = $self->{'columns'}{$key};
      }
      $cache{$key}||={};
      my $idx = $rseries{$key};
      $c = $column->compare($a->[$idx],$b->[$idx],$col->{'dir'},$keymeta,$cache{$key},$key);
      last if $c;
    }
    $c;
  } @$data;
  pop @$_ for(@$data);
}

sub server_nulls {
  my ($self,$data,$iconfig,$series) = @_;

  my $cols = $iconfig->{'columns'};
  my $colconf = $iconfig->{'colconf'};
  foreach my $j (0..$#$series) {
    my $cc = $colconf->{$series->[$j]};
    my $col = $self->{'columns'}{$series->[$j]};
    my %null_cache;
    foreach my $i (0..$#$data) {
      my $is_null = (!defined $data->[$i][$j]);
      $is_null = $null_cache{$data->[$i][$j]} unless $is_null;
      unless(defined $is_null) {
        $is_null = $col->is_null($data->[$i][$j]);
        $null_cache{$data->[$i][$j]} = $is_null;
      }
      $data->[$i][$j] = [$data->[$i][$j],0+$is_null];
    }
  }
}

sub rows { return $_[0]->{'rows'}; }

sub stand_down {
  my ($self,$row,$num) = @_;

  return 1 if $self->{'rows'}[1]!=-1 && $num >= $self->{'rows'}[1];
  return 0;
}

sub passes_muster {
  my ($self,$row,$num) = @_;

  return 0 if $num <= $self->{'rows'}[0];
  my $ok = 1;
  foreach my $col (keys %{$self->{'wire'}{'filter'}||{}}) {
    my $colconf = $self->{'iconfig'}{'colconf'}{$col};
    my $column = $self->{'columns'}->{$col};
    next unless exists $row->{$col};
    my $val = $row->{$col};
    my $ok_col = 0;
    my $values = $column->split($val);
    foreach my $value (@{$values||[]}) {
      my $fv = $self->{'wire'}{'filter'}{$col};
      if($column->is_match($fv,$value)) {
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

sub convert_to_csv {
  my ($config,$data) = @_;

  my $csv = Text::CSV->new({ binary => 1 });
  my $out;
  my $series = $data->{'response'}{'series'};
  my %rseries;
  $rseries{$series->[$_]} = $_ for(0..$#$series);
  my @index;
  foreach my $key (@{$config->{'columns'}}) {
    push @index,$rseries{$key};
  }
  $csv->combine(@{$config->{'columns'}});
  $out .= $csv->string()."\n";
  foreach my $row (@{$data->{'response'}{'data'}}) {
    my @row;
    foreach my $col (@index) {
      push @row,$row->[$col][0];
    }
    $csv->combine(@row);
    $out .= $csv->string()."\n";
  }
  return $out;
}

use Time::HiRes qw(time);

sub get_cache {
  my ($self,$key) = @_;

  my $cache = $self->{'hub'}->cache;
  return undef unless $cache;
  my $main_key = "newtable_".md5_hex($key);
  my $main_val = $cache->get($main_key);
  return undef unless $main_val;
  $main_val = JSON->new->decode($main_val);
  my $out = "";
  foreach my $k (@$main_val) {
    my $frag = $cache->get($k);
    return undef unless defined $frag;
    $out .= $frag;
  }
  return $out;
}

sub set_cache {
  my ($self,$key,$value) = @_;

  my $cache = $self->{'hub'}->cache;
  return undef unless $cache;
  my $main_key = "newtable_".md5_hex($key);
  my $i = 0;
  my @ids;
  while($value) {
    push @ids,$main_key.'_'.($i++);
    my $more = substr($value,0,256*1024,'');
    next unless length $more;
    $cache->set($ids[-1],$more);
  }
  $cache->set($main_key,JSON->new->encode(\@ids));
}

sub unique { return $_[0]->{'iconfig'}{'unique'}; }
sub phase { return $_[0]->{'phase_name'}; }

sub newtable_data_request {
  my ($self,$orient,$more,$incr_ok,$keymeta) = @_;

  my $cache_key = {
    iconfig => $self->{'iconfig'},
    orient => $orient,
    wire => $self->{'wire'},
    more => $more,
    incr_ok => $incr_ok,
    keymeta => $keymeta,
    url => $self->{'hub'}->url,
    base => $SiteDefs::ENSEMBL_BASE_URL,
    version => $SiteDefs::ENSEMBL_VERSION,
  };
  delete $cache_key->{'iconfig'}{'unique'};
  $cache_key = JSON->new->canonical->encode($cache_key);
  my $out = $self->get_cache($cache_key);
  return JSON->new->decode($out) if $out;

  my @cols = @{$self->{'iconfig'}{'columns'}};
  my %cols_pos;
  $cols_pos{$cols[$_]} = $_ for(0..$#cols);
  $self->{'cols_pos'} = \%cols_pos;

  my $phases = $self->{'iconfig'}{'phases'};
  $phases = [{ name => undef }] unless $phases and @$phases;
  my @out;

  my $A = time();

  # What phase should we be?
  my @required;
  push @required,map { $_->{'key'} } @{$self->{'wire'}{'sort'}||[]};
  if($incr_ok) {
    while($more < $#$phases) {
      my %gets_cols = map { $_ => 1 } (@{$phases->[$more]{'cols'}||\@cols});
      last unless scalar(grep { !$gets_cols{$_} } @required);
      $more++;
    }
  } else {
    $more = $#$phases;
  }
  $self->{'phase_name'} = $phases->[$more]{'name'};

  # Check if we need to request all rows due to sorting
  my $all_data = 0;
  if($self->{'wire'}{'sort'} and @{$self->{'wire'}{'sort'}}) {
    $all_data = 1;
  }
  my $A2 = time();

  # Start row
  my $irows = $phases->[$more]{'rows'} || [0,-1];
  $self->{'rows'} = $irows;
  $self->{'rows'} = [0,-1] if $all_data;

  # Calculate columns to send
  $self->{'used_cols'} = $phases->[$more]{'cols'} || \@cols;

  # Calculate function name
  my $type = $self->{'iconfig'}{'type'};
  $type =~ s/\W//g;
  my $func = "table_content";
  $func .= "_$type" if $type;

  my $B = time();
  # Populate data
  $self->{'component'}->$func($self);
  my $data = $self->{'data'};
  my $C = time();

  my %shadow = %$orient;
  delete $shadow{'filter'};
  $shadow{'series'} = $self->{'used_cols'};

  my $D = time();

  # Move on continuation counter
  $more++;
  $more=0 if $more == @$phases;

  # Sort it, if necessary
  if($self->{'wire'}{'sort'} and @{$self->{'wire'}{'sort'}}) {
    $self->server_sort($data,$self->{'wire'}{'sort'},$self->{'iconfig'},$self->{'used_cols'},$keymeta);
    splice($data,0,$irows->[0]);
    splice($data,$irows->[1]) if $irows->[1] >= 0;
  }
  my $E = time();
  $self->server_nulls($data,$self->{'iconfig'},$self->{'used_cols'});

  my $F = time();

  warn sprintf("%f/%f/%f/%f/%f\n",$F-$E,$E-$D,$D-$C,$C-$B,$B-$A);

  # Send it
  $out = {
    response => {
      data => $data,
      series => $self->{'used_cols'},
      start => $self->{'rows'}[0],
      more => $more,
      enums => $self->finish_enum(),
      shadow => \%shadow,
      keymeta => $self->{'key_meta'},
    },
    orient => $orient,
  };
  $self->set_cache($cache_key,JSON->new->encode($out));
  return $out;
}

1;
