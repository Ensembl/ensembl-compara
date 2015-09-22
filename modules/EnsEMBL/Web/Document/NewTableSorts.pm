=head1 LICENSE

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

package EnsEMBL::Web::Document::NewTableSorts;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);
use List::Util qw(min max);

use List::MoreUtils qw(each_array);

use Exporter qw(import);
our @EXPORT_OK = qw(newtable_sort_client_config newtable_sort_isnull
                    newtable_sort_cmp newtable_sort_range_value
                    newtable_sort_range_split
                    newtable_sort_range_finish newtable_sort_range_match);

sub html_cleaned {
  local $_ = $_[0];

  s/<[^>]*? class="[^"]*?hidden.*?<\/.*?>//g;
  s/<.*?>//g;
  s/\&.*?;//g;
  return $_;
}

sub number_cleaned { $_[0] =~ s/([\d\.e\+-])\s.*$/$1/; return $_[0]; }

sub html_hidden {
  my ($x) = @_;

  return $1 if $x =~ m!<span class="hidden">(.*?)</span>!;
  return $x;
}

sub null_position {
  my ($v) = @_;

  $v =~ s/^.*://;
  my @v = split(/:-/,$v);
  shift @v;
  foreach my $c (@v) {
    return 1 if newtable_sort_isnull('numeric',$c);
  } 
  return 0;
}

sub sort_position {
  my ($a,$b,$f) = @_;

  my @a = split(/:-/,$a);
  my @b = split(/:-/,$b);
  my $it = each_array(@a,@b);
  while(my ($aa,$bb) = $it->()) {
    my $c = newtable_sort_cmp('numeric',$aa,$bb,$f);
    return $c if $c; 
  }
  return 0;
}

sub split_top_level {
  my ($all) = @_;

  my @seq = split(m!(</?div.*?>)!,$all);
  my $count = 0;
  my @out;
  foreach my $x (@seq) {
    if($x =~ m!^<div!) {
      $count++;
      if($count==1) {
        push @out,"";
        next;
      }
    }
    if($x =~ m!^</div>!) { $count--; next unless $count; }
    if($count) { $out[$#out] .= $x; }
  }
  return \@out;
}

sub iconic_build_key {
  my ($km,$col,$in) = @_;

  my @vals = split(/;/,$in||'');
  if($km) {
    @vals = map {
      $km->{"decorate/iconic/$col/$_"}{'order'} ||
      $km->{"decorate/iconic/$col/$_"}{'export'} || '~';
    } @vals;
  }
  return join('~',reverse sort @vals);
}

# perl -- sorting routine for server side sort
# null -- is this value fo be considered null (server side)
# clean -- remving crud from a value (server side)
# range_split -- server side code for breaking up composite values
# range_merge -- client side code for merging multiple range results
# range_display -- filter code to use on client
# range_display_params -- params to pass to filter code to use on client
# range_value -- server side code for adding to enumeration
# range_finish -- server side code for finalising enumeration
# range_match -- server side code for applying filter
# enum_js -- suite of functions for client-side filtering
# js_clean -- client side cleaning for sorting
# filter_primary -- dropdown directly on filter, not inside more

my %SORTS = (
  '_default' => {
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    null => sub { return 0; },
    clean => sub { return $_[0]; },
    range_split => sub { return [$_[0]->{'clean'}->($_[1])]; },
    range_merge => "class",
    range_display => "class",
    range_display_params => {},
    range_value => sub { $_[0]->{$_[1]} = 1; },
    range_finish => sub { return [sort keys %{$_[0]}]; },
    range_match => sub {
      foreach my $x (keys %{$_[0]}) {
        return 0 if lc $x eq lc $_[1];
      }
      return 1;
    },
    filter_primary => 0,
  },
  'string' => {
    null => sub { $_[0] !~ /\S/; },
    js => 'string',
    enum_js => 'string',
  },
  'string_nofilter' => [qw(nofilter string)],
  'dashnull' => {
    null => sub { $_[0] !~ /\S/ || $_[0] =~ /^\s*-\s*$/; },
  },
  'nofilter' => {
    range_display => "",
  },
  'string_dashnull' => [qw(dashnull string)],
  'string_dashnull_nofilter' => [qw(nofilter dashnull string)],
  'string_hidden' => {
    clean => \&html_hidden,
    js_clean => 'html_hidden',
  },
  '_hidden_number' => {
    clean => sub { return number_cleaned(html_hidden($_[0])); },
    js_clean => 'hidden_number',
    enum_js => "numeric_hidden",
  },
  'numeric_hidden' => [qw(_hidden_number numeric)],
  'numeric' => {
    clean => \&number_cleaned, 
    perl => sub { return ($_[0] <=> $_[1])*$_[2]; },
    null => sub { return !looks_like_number($_[0]); },
    js => 'numeric',
    js_clean => 'clean_number',
    range_display => 'range',
    range_merge => 'range',
    range_value => sub {
      if(!looks_like_number($_[1])) { return; }
      if(exists $_[0]->{'min'}) {
        $_[0]->{'max'} = max($_[0]->{'max'},$_[1]);
        $_[0]->{'min'} = min($_[0]->{'min'},$_[1]);
      } else {
        $_[0]->{'min'} = $_[0]->{'max'} = $_[1];
      }
    },
    range_finish => sub { return $_[0]||={}; },
    range_match => sub {
      if(looks_like_number($_[1])) {
        if(exists $_[0]->{'min'}) {
          return 0 unless $_[1]>=$_[0]->{'min'};
        }
        if(exists $_[0]->{'max'}) {
          return 0 unless $_[1]<=$_[0]->{'max'};
        }
        return 1;
      } else {
        if(exists $_[0]->{'nulls'}) { return $_[0]->{'nulls'}; }
        return 1;
      }
    },
    enum_js => "numeric",
  },
  '_int' => {
    range_display_params => { steptype => 'integer' },
  },
  'integer' => [qw(_int numeric)],
  'html' => {
    clean => \&html_cleaned,
    null => sub { $_[0] !~ /\S/; },
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    js => 'string',
    js_clean => 'html_cleaned',
    enum_js => 'html',
  },
  'html_nofilter' => [qw(nofilter html)],
  'html_split' => {
    clean => \&html_cleaned,
    null => sub { $_[0] !~ /\S/; },
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    js => 'string',
    js_clean => 'html_cleaned',
    range_split => sub {
      return [ map { $_[0]->{'clean'}->($_) } @{split_top_level($_[1])} ];
    },
    enum_js => "html_split",
  },
  'html_hidden_split_dashnull' => {
    clean => \&html_hidden,
    null => sub { $_[0] !~ /\S/ || $_[0] =~ /^\s*-\s*$/; },
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    js => 'string',
    js_clean => 'html_cleaned',
    range_split => sub {
      return [ map { $_[0]->{'clean'}->($_) } @{split_top_level($_[1])} ];
    },
    enum_js => "html_hidden_split",
  },
  'primary' => {
    filter_primary => 1,
  },
  'html_split_primary' => [qw(primary html_split)],
  'html_numeric' => {
    clean => sub { return number_cleaned(html_cleaned($_[0])); },
    perl => sub { return ($_[0] <=> $_[1])*$_[2]; },
    null => sub { return !looks_like_number($_[0]); },
    js => 'numeric',
    js_clean => 'html_number',
    enum_js => "",
  },
  'position' => {
    null => \&null_position,
    perl => \&sort_position,
    js => 'position',
    range_display_params => { steptype => 'integer' },
    range_display => 'position',
    range_merge => 'position',
    range_value => sub {
      my ($acc,$value) = @_;

      return unless $value =~ /^(.*?):(\d+)/;
      my ($chr,$pos) = ($1,$2);
      $acc->{$chr} ||= { chr => $chr };
      if(exists $acc->{$chr}{'min'}) {
        $acc->{$chr}{'max'} = max($acc->{$chr}{'max'},$pos);
        $acc->{$chr}{'min'} = min($acc->{$chr}{'min'},$pos);
      } else {
        $acc->{$chr}{'min'} = $acc->{$chr}{'max'} = $pos;
      }
      ($acc->{$chr}{'count'}||=0)++;
    },
    range_finish => sub { return $_[0]; },
    range_match => sub {
      my ($man,$val) = @_;
      if($val =~ s/^$man->{'chr'}://) {
        if(exists $man->{'min'}) {
          return 0 unless $val>=$man->{'min'};
        }
        if(exists $man->{'max'}) {
          return 0 unless $val<=$man->{'max'};
        }
        return 1;
      } else {
        if(exists $man->{'nulls'}) { return $man->{'nulls'}; }
        return 1;
      }
    },
    enum_js => "position",
  },
  'position_html' => {
    clean => \&html_cleaned,
    null => \&null_position,
    perl => \&sort_position,
    js => 'position',
    js_clean => 'html_cleaned',
  },
  'hidden_position' => {
    clean => \&html_hidden,
    null => \&null_position,
    perl => \&sort_position,
    js_clean => 'html_hidden',
    js => 'position',
    range_display_params => { steptype => 'integer' },
    range_display => 'position',
    range_merge => 'position',
    range_value => sub {
      my ($acc,$value) = @_;

      return unless $value =~ /^(.*?):(\d+)/;
      my ($chr,$pos) = ($1,$2);
      $acc->{$chr} ||= { chr => $chr };
      if(exists $acc->{$chr}{'min'}) {
        $acc->{$chr}{'max'} = max($acc->{$chr}{'max'},$pos);
        $acc->{$chr}{'min'} = min($acc->{$chr}{'min'},$pos);
      } else {
        $acc->{$chr}{'min'} = $acc->{$chr}{'max'} = $pos;
      }
      ($acc->{$chr}{'count'}||=0)++;
    },
    range_finish => sub { return $_[0]; },
    range_match => sub {
      my ($man,$val) = @_;
      if($val =~ s/^$man->{'chr'}://) {
        if(exists $man->{'min'}) {
          return 0 unless $val>=$man->{'min'};
        }
        if(exists $man->{'max'}) {
          return 0 unless $val<=$man->{'max'};
        }
        return 1;
      } else {
        if(exists $man->{'nulls'}) { return $man->{'nulls'}; }
        return 1;
      }
    },
    enum_js => "hidden_position",
  },
  iconic => {
    js => "iconic",
    null => sub { $_[0] !~ /\S/; },
    perl => sub {
      my ($x,$y,$f,$c,$km,$col) = @_;

      $c->{$x} = iconic_build_key($km,$col,$x) unless exists $c->{$x};
      $c->{$y} = iconic_build_key($km,$col,$y) unless exists $c->{$y};
      return ($c->{$x} cmp $c->{$y})*$f;
    },
    range_split => sub { return [ split(/~/,$_[1]) ]; },
    range_display => 'class',
    enum_js => "iconic",
  },
  iconic_primary => [qw(iconic primary)],
  numeric_nofilter => [qw(nofilter numeric)],
  position_nofilter => [qw(nofilter position)],
);

my %sort_cache;
sub get_sort {
  my ($name) = @_;

  my $out = {};
  return $sort_cache{$name} if exists $sort_cache{$name};
  $sort_cache{$name}||= {};
  add_sort($sort_cache{$name},[$name,'_default']);
  return $sort_cache{$name};
}

sub add_sort {
  my ($out,$names) = @_;

  foreach my $name (@$names) {
    my $ss = $SORTS{$name};
    if(ref($ss) eq 'ARRAY') { add_sort($out,$ss); next; }
    foreach my $k (keys %$ss) {
      $out->{$k} = $ss->{$k} unless exists $out->{$k};
    } 
  }
  return $out;
}

sub newtable_sort_client_config {
  my ($colmap,$cols) = @_;

  my $config;
  foreach my $col (keys %$colmap) {
    my $idx = $colmap->{$col};
    my $conf = get_sort($cols->[$idx]{'sort'});
    $conf->{'options'} ||= {};
    my @conf;
    if($conf->{'js'}) {
      push @conf, {
        fn => $conf->{'js'},
        clean => $conf->{'js_clean'},
        range => $conf->{'range_display'},
        enum_merge => $conf->{'range_merge'},
        primary => $conf->{'filter_primary'},
        enum_js => $conf->{'enum_js'},
        range_params => $conf->{'range_display_params'},
        type => $cols->[$idx]{'sort'},
        incr_ok => !($conf->{'options'}{'no_incr'}||0),
        range_range => $cols->[$idx]{'range'},
        label => $cols->[$idx]{'label'},
        type => $cols->[$idx]{'type'},
        idx => $idx, # TODO this can go when fully transitioned to named columns
      };
    }
    push @conf, {
      range_range => $cols->[$idx]{'range'},
      sort => $cols->[$idx]{'sort'},
      width => $cols->[$idx]{'width'},
      help => $cols->[$idx]{'help'},
    };
    $config->{$col} = {};
    foreach my $x (@conf) {
      $config->{$col}{$_} = $x->{$_} for keys %$x;
    }
  }
  return $config;
}

sub newtable_sort_range_split {
  my ($type,$values) = @_;

  my $conf = get_sort($type);
  return $conf->{'range_split'}->($conf,$values);
}

sub newtable_sort_range_value {
  my ($type,$values,$value) = @_;

  my $conf = get_sort($type);
  my $vv = newtable_sort_range_split($type,$value) if defined $value;
  return unless defined $values;
  foreach my $v (@$vv) {
    $conf->{'range_value'}->($values,$v);
  }
}

sub newtable_sort_range_finish {
  my ($type,$values) = @_;

  return get_sort($type)->{'range_finish'}->($values);
}

sub newtable_sort_range_match {
  my ($type,$x,$y) = @_;

  return 0 unless defined $y;
  return get_sort($type)->{'range_match'}->($x,$y);
}

sub newtable_sort_isnull {
  my ($type,$value) = @_;

  return 1 unless defined $value;
  $value = get_sort($type)->{'clean'}->($value);
  return 1 unless defined $value;
  return !!(get_sort($type)->{'null'}->($value));
}

sub newtable_sort_cmp {
  my ($type,$a,$b,$f,$keymeta,$cache,$col) = @_;

  my $av = get_sort($type)->{'clean'}->($a);
  my $bv = get_sort($type)->{'clean'}->($b);
  my $an = newtable_sort_isnull($type,$av);
  my $bn = newtable_sort_isnull($type,$bv);
  return $an-$bn if $an-$bn;
  $type = '_default' if $an;
  return get_sort($type)->{'perl'}->($av,$bv,$f,$cache,$keymeta,$col);
}

1;
