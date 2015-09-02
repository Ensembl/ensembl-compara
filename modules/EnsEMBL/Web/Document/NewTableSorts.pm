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
  foreach my $c (@v) {
    return 0 if newtable_sort_isnull('numeric',$c);
  } 
  return 1;
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
  },
  'string' => {
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    null => sub { $_[0] !~ /\S/; },
    js => 'string'
  },
  'string_dashnull' => {
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    null => sub { $_[0] !~ /\S/ || $_[0] =~ /^\s*-\s*$/; },
    js => 'string'
  },
  'string_hidden' => {
    clean => \&html_hidden,
    null => sub { $_[0] =~ /\S/; },
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    js => 'string',
    js_clean => 'html_hidden',
  },
  'numeric_hidden' => {
    clean => sub { return number_cleaned(html_hidden($_[0])); },
    perl => sub { return ($_[0] <=> $_[1])*$_[2]; },
    null => sub { return !looks_like_number($_[0]); },
    js => 'numeric',
    js_clean => 'hidden_number',
  },
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
          return $_[1]>=$_[0]->{'min'} && $_[1]<=$_[0]->{'max'};
        }
        return 1;
      } else {
        if(exists $_[0]->{'nulls'}) { return $_[0]->{'nulls'}; }
        return 1;
      }
    },
  },
  'integer' => {
    range_display_params => { steptype => 'integer' },
    _inherit => ['numeric'],
  },
  'html' => {
    clean => \&html_cleaned,
    null => sub { $_[0] =~ /\S/; },
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    js => 'string',
    js_clean => 'html_cleaned',
  },
  'html_split' => {
    clean => \&html_cleaned,
    null => sub { $_[0] =~ /\S/; },
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    js => 'string',
    js_clean => 'html_cleaned',
    range_split => sub {
      return [ map { $_[0]->{'clean'}->($_) } @{split_top_level($_[1])} ];
    },
  },
  'html_numeric' => {
    clean => sub { return number_cleaned(html_cleaned($_[0])); },
    perl => sub { return ($_[0] <=> $_[1])*$_[2]; },
    null => sub { return !looks_like_number($_[0]); },
    js => 'numeric',
    js_clean => 'html_number'
  },
  'position' => {
    null => \&null_position,
    perl => \&sort_position,
    js => 'position',
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
  },
);

my $skips = 1;
while($skips) {
  $skips = 0;
  TYPE: foreach my $k (keys %SORTS) {
    my @inherit = @{$SORTS{$k}->{'_inherit'}||[]};
    push @inherit,'_default';
    delete $SORTS{$k}->{'_inherit'};
    foreach my $t (@inherit) {
      next unless $SORTS{$t}->{'_inherit'};
      $skips = 1;
      next TYPE;
    }
    foreach my $t (@inherit) {
      foreach my $d (keys %{$SORTS{$t}}) {
        $SORTS{$k}->{$d} ||= $SORTS{$t}->{$d};
      }
    }
  }
}

sub newtable_sort_client_config {
  my ($column_map) = @_;

  my $config;
  foreach my $col (keys %$column_map) {
    my $conf = $SORTS{$column_map->{$col}};
    $conf->{'options'} ||= {};
    if($conf->{'js'}) {
      $config->{$col} = {
        fn => $conf->{'js'},
        clean => $conf->{'js_clean'},
        range => $conf->{'range_display'},
        range_params => $conf->{'range_display_params'},
        type => $column_map->{$col},
        incr_ok => !($conf->{'options'}{'no_incr'}||0)
      };
    }
  }
  return $config;
}

sub newtable_sort_range_split {
  my ($type,$values) = @_;

  $SORTS{$type} = $SORTS{'_default'} unless $SORTS{$type};
  return $SORTS{$type}->{'range_split'}->($SORTS{$type},$values);
}

sub newtable_sort_range_value {
  my ($type,$values,$value) = @_;

  $SORTS{$type} = $SORTS{'_default'} unless $SORTS{$type};
  my $vv = newtable_sort_range_split($type,$value) if defined $value;
  return unless defined $values;
  foreach my $v (@$vv) {
    $SORTS{$type}->{'range_value'}->($values,$v);
  }
}

sub newtable_sort_range_finish {
  my ($type,$values) = @_;

  $SORTS{$type} = $SORTS{'_default'} unless $SORTS{$type};
  my $out = $SORTS{$type}->{'range_finish'}->($values);
  my $rtype = $SORTS{$type}->{'range_merge'};
  return { merge => $rtype, values => $out };
}

sub newtable_sort_range_match {
  my ($type,$x,$y) = @_;

  $SORTS{$type} = $SORTS{'_default'} unless $SORTS{$type};
  return 0 unless defined $y;
  return $SORTS{$type}->{'range_match'}->($x,$y);
}

sub newtable_sort_isnull {
  my ($type,$value) = @_;

  $SORTS{$type} = $SORTS{'_default'} unless $SORTS{$type};
  return 1 unless defined $value;
  $value = $SORTS{$type}->{'clean'}->($value);
  return 1 unless defined $value;
  return !!($SORTS{$type}->{'null'}->($value));
}

sub newtable_sort_cmp {
  my ($type,$a,$b,$f) = @_;

  $SORTS{$type} = $SORTS{'_default'} unless $SORTS{$type};
  my $av = $SORTS{$type}->{'clean'}->($a);
  my $bv = $SORTS{$type}->{'clean'}->($b);
  my $an = newtable_sort_isnull($type,$av);
  my $bn = newtable_sort_isnull($type,$bv);
  return $an-$bn if $an-$bn;
  $type = '_default' if $an;
  return $SORTS{$type}->{'perl'}->($av,$bv,$f);
}

1;
