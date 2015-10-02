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

use CGI::Cookie;
use MIME::Base64;
use Compress::Zlib;
use Digest::MD5 qw(md5_hex);
use SiteDefs;
use Text::CSV;

use EnsEMBL::Web::Procedure;

# XXX move all this stuff to somewhere it's more suited

sub compress_block {
  return encode_base64(compress(JSON->new->encode($_[0])));
}

sub uncompress_block {
  return JSON->new->decode(uncompress(decode_base64($_[0])));
}

sub new {
  my ($proto,$hub,$component) = @_;

  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new($hub,$component);
  $self = { %$self, (
    # NOT RESET EACH PHASE
    hub => $hub,
    component => $component,
    enum_values => {},
    out => [],
    # RESET EACH PHASE
    request_num => 0,
    null_cache => [],
    sort_data => [],
    stand_down => 0,
  )};
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

sub consolidate {
  my ($self) = @_;

  my $out = $self->{'out'}[-1];
  push @{$out->{'data'}},compress_block($out->{'indata'});
  push @{$out->{'nulls'}},compress_block($out->{'innulls'});
  push @{$out->{'len'}},$out->{'inlen'};
  $out->{'indata'} = [];
  $out->{'innulls'} = [];
  $out->{'inlen'} = 0;
}

sub add_row {
  my ($self,$row) = @_;

  my $out = $self->{'out'}[-1];
  my $rows = $self->{'orient'}{'pagerows'};
  $self->{'stand_down'} = 1 if $rows && $out->{'shadow_num'} >= $rows->[1];
  $out->{'shadow_num'}++;
  return 0 unless $self->passes_muster($row); 
  $self->{'request_num'}++;
  $self->add_enum($row); 
  if($self->{'wire'}{'sort'} and @{$self->{'wire'}{'sort'}}) {
    $self->server_sortdata($out,$row);
  }
  my $nulls = $self->server_nulls($out,$row);
  foreach my $i (0..$#{$out->{'series'}}) {
    my $k = $out->{'series'}[$i];
    $out->{'indata'}[$i]||=[];
    push @{$out->{'innulls'}[$i]||=[]},$nulls->{$k};
    push @{$out->{'indata'}[$i]||=[]},$row->{$k} unless $nulls->{$k};
  }
  $out->{'inlen'}++;
  $self->consolidate() unless $out->{'inlen'}%10000;
  return 1;
}

sub go {
  my ($self) = @_;

  my $hub = $self->{'hub'};
  $self->{'iconfig'} = from_json($hub->param('config'));
  $self->{'orient'} = from_json($hub->param('orient'));
  $self->{'wire'} = from_json($hub->param('wire'));
  my $more = JSON->new->allow_nonref->decode($hub->param('more'));
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
      EnsEMBL::Web::NewTable::Column->new($self,$cc->{'sstype'},$key,$cc->{'ssconf'},$cc->{'ssarg'});
  }

  my $proc = EnsEMBL::Web::Procedure->new($self->{'hub'},'callback');

  $proc->set_variables({
    orient => $self->{'orient'}, more => $more, incr_ok => $incr_ok,
    keymeta => $keymeta
  });
  my $out = $proc->go(sub {
    return $self->newtable_data_request($more,$incr_ok,$keymeta);
  });
  if($self->{'wire'}{'format'} eq 'export') {
    $out = convert_to_csv($self->{'iconfig'},$out);
    my $r = $hub->apache_handle;
    # TODO find bits of ensembl which can do this as we do
    $r->content_type('application/octet-string');
    my $cookie = CGI::Cookie->new(-name  => 'spawntoken',
                                  -value => $hub->param('spawntoken'));
    $r->headers_out->add('Set-Cookie' => $cookie);
    $r->headers_out->add('Content-Disposition' => sprintf 'attachment; filename=%s.csv', $hub->param('filename')||'ensembl-export');
  }
  return $out;
}

sub preload {
  my ($self,$table,$config,$orient) = @_;

  $self->{'iconfig'} = $config;
  $self->{'wire'} = $orient;
  $self->{'orient'} = $orient;
  $self->{'columns'} = $table->columns;
  my $proc = EnsEMBL::Web::Procedure->new($self->{'hub'},'preload');
  $proc->set_variables({ orient => $self->{'orient'}, config => $config });
  return $proc->go(sub {
    return $self->newtable_data_request(undef,1);
  }); 
}

sub server_sortdata {
  my ($self,$out,$row) = @_;
    
  my $sort = $self->{'wire'}{'sort'};
  my $series = $out->{'series'};
  my $colconf = $self->{'iconfig'}{'colconf'};
  foreach my $i (0..$#$sort) {
    push @{$self->{'sort_data'}[$i]||=[]},$row->{$sort->[$i]{'key'}};
  }
  push @{$self->{'sort_data'}[@$sort]||=[]},$out->{'shadow_num'};
}

sub server_order {
  my ($self,$keymeta) = @_;

  my $out = $self->{'out'}[-1];
  my @sort = @{$self->{'wire'}{'sort'}};
  my $series = $out->{'series'};
  my @cache;
  my %rseries;
  $rseries{$series->[$_]} = $_ for (0..$#$series);
  $rseries{'__tie'} = -1;
  my @columns = map { $self->{'columns'}{$_->{'key'}} } @sort;
  push @columns,EnsEMBL::Web::NewTable::Column->new($self,'numeric','__tie');
  my $sd = $self->{'sort_data'};
  my @order = sort {
    my $c = 0;
    foreach my $i (0..@sort) {
      $cache[$i]||={};
      $c = $columns[$i]->compare($sd->[$i][$a],$sd->[$i][$b],
                                 $sort[$i]->{'dir'}||1,$keymeta,$cache[$i],
                                 $sort[$i]->{'key'}||'__tie');
      last if $c;
    }
    $c;
  } (0..$#{$sd->[0]});
  $out->{'order'} = \@order;
}

sub server_nulls {
  my ($self,$out,$row) = @_;

  my $series = $out->{'series'};
  my %nulls;
  foreach my $j (0..$#$series) {
    my $col = $self->{'columns'}{$series->[$j]};
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

sub stand_down {
  my ($self) = @_;

  return 0 if $self->size_needed;
  return $self->{'stand_down'};
}

sub free_wheel {
  my ($self,$acct) = @_;

  if($self->{'stand_down'}) {
    $self->{'out'}[-1]{'shadow_num'}++;
    return 1;
  }
  return 0; 
}

sub passes_muster {
  my ($self,$row) = @_;

  my $rows = $self->{'orient'}{'pagerows'};
  if($rows) {
    my $global_num = $self->{'out'}[-1]{'shadow_num'}-1;
    return 0 if $global_num < $rows->[0] or $global_num >= $rows->[1];
  }
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
  foreach my $i (0..$#{$data->{'response'}{'nulls'}}) {
    # XXX THIS WILL BE BROKEN DO NOT MERGE
    my $rows = uncompress_block($data->{'response'}{'data'}[$i]);
    my $nulls = uncompress_block($data->{'response'}{'nulls'}[$i]);
    my $len = $data->{'response'}{'len'}[$i];
    my @idx;
    foreach my $row (0..$len-1) {
      my @row;
      foreach my $col (@index) {
        if($nulls->[$col][$row]) { push @row,''; }
        else { push @row,$rows->[$col][($idx[$col]||=0)++]; }
      }
      $csv->combine(@row);
      $out .= $csv->string()."\n";
    }
  }
  return $out;
}

sub phase { return $_[0]->{'phase_name'}; }
  
sub run_phase {
  my ($self,$phases,$phase,$keymeta) = @_;

  $self->{'phase_name'} = $phases->[$phase]{'name'};
  warn "CHOSEN PHASE $self->{'phase_name'}\n";
  my $era = $phases->[$phase]{'era'};
  my @cols = @{$self->{'iconfig'}{'columns'}};
  push @{$self->{'out'}},{
    data => [], nulls => [], len => [],
    indata => [], innulls => [], inlen => 0,
    series => ($phases->[$phase]{'cols'} || \@cols),
    order => undef,
    start => ($self->{'req_lengths'}{$era}||=0),
    shadow_num => ($self->{'shadow_lengths'}{$era}||=0)
  };
  $self->{'sort_data'} = [];
  $self->{'null_cache'} = [];
  $self->{'request_num'} = 0;
  $self->{'stand_down'} = 0;

  # Calculate function name
  my $type = $self->{'iconfig'}{'type'}||'';
  $type =~ s/\W//g;
  my $func = "table_content";
  $func .= "_$type" if $type;

  # Populate data
  $self->{'component'}->$func($self);

  # Sort it, if necessary
  if($self->{'wire'}{'sort'} and @{$self->{'wire'}{'sort'}}) {
    $self->server_order($keymeta);
  }

  # Send it
  $self->consolidate();
  # Move on continuation counters
  $self->{'req_lengths'}{$era} = $self->{'request_num'};
  $self->{'shadow_lengths'}{$era} = $self->{'out'}[-1]{'shadow_num'};
}

sub newtable_data_request {
  my ($self,$more,$incr_ok,$keymeta) = @_;

  my @cols = @{$self->{'iconfig'}{'columns'}};
  my %cols_pos;
  $cols_pos{$cols[$_]} = $_ for(0..$#cols);
  $self->{'cols_pos'} = \%cols_pos;

  my $phases = $self->{'iconfig'}{'phases'};
  $phases = [{ name => undef }] unless $phases and @$phases;
  my @out;

  # Check if we need to request all rows due to sorting
  my $all_data = 0;
  if($self->{'wire'}{'sort'} and @{$self->{'wire'}{'sort'}}) {
    $all_data = 1;
  }
  
  my %shadow = %{$self->{'orient'}};
  delete $shadow{'filter'};
  delete $shadow{'pagerows'};
  delete $shadow{'series'};

  my $phase;
  if(defined $more) {
    $phase = $more->{'phase'};
    $self->{'req_lengths'} = $more->{'req_lengths'};
    $self->{'shadow_lengths'} = $more->{'shadow_lengths'};
  }
  # What phase should we be?
  my @required;
  push @required,map { $_->{'key'} } @{$self->{'wire'}{'sort'}||[]};
  if($incr_ok && !$all_data) {
    $self->run_phase($phases,$phase,$keymeta);
    $phase++;
  } else {
    $self->run_phase($phases,$_,$keymeta) for (0..$#$phases);
    $phase = @$phases;
  }

  $more = {
    phase => $phase,
    req_lengths => $self->{'req_lengths'},
    shadow_lengths => $self->{'shadow_lengths'}
  };
  $more = undef if $phase == @$phases;
  my $out = {
    responses => $self->{'out'},
    keymeta => $self->{'key_meta'},
    shadow => \%shadow,
    enums => $self->finish_enum(),
    orient => $self->{'orient'},
    more => $more,
  };
  return $out;
}

1;
