package EnsEMBL::Web::TextSequence::ClassToStyle;

use strict;
use warnings;

use Exporter qw(import);

use File::Basename;
use YAML qw(LoadFile);

our @EXPORT_OK = qw(convert_class_to_style create_legend);

my $cache;

my %assigns = (
  'background' => { 'background-color' => 'default' },
  'foreground' => { 'color' => 'default' },
  'both' => { 'background-color' => 'default', color => 'label' }
);

sub load_styles {
  my ($name,$path) = fileparse(__FILE__);
  $path .= "/seq-styles.yaml";
  return LoadFile($path);
}

sub _value {
  my ($val,$config) = @_;

  return undef unless defined $val;
  if(ref $val) {
    foreach my $k (keys %$val) {
      next if $k eq '_else';
      if($config->{$k}) { $val = $val->{$k}; last; }
    }
    $val = $val->{'_else'} if ref $val eq 'HASH';
  }
  return undef unless defined $val;
  $val =~ s/<<(.*?)>>/$config->{$1}||''/eg unless ref $val;
  return $val;
}

sub make_class_to_style_map {
  my ($hub,$config) = @_;

  if(!$cache) {
    $cache = {};

    # Load the config
    my $seq = load_styles;
    my %c2s;
    my $species_defs = $hub->species_defs;
    my $colourmap    = $hub->colourmap;
    my $j = 1;
    my %sources;

    # Iterate through config file entries
    foreach my $e (@$seq) {
      if($e->{'source'}) {
        $sources{$e->{'source'}} ||=
          $species_defs->colour($e->{'source'});
      }

      # Build list of members (kind "all" has more than one)
      my @m;
      if(($e->{'kind'}||'normal') eq 'all') {
        foreach my $k (keys %{$sources{$e->{'source'}}}) {
          push @m,{ %$e, name => $k };
        }
      } else {
        push @m,$e;
      }

      # For each member
      foreach my $m (@m) {
        my %style;
        my $type = $m->{'type'} || 'foreground';
        next unless $m->{'source'};
        my $value = $sources{$m->{'source'}}->{$m->{'key'}||$m->{'name'}};

        # For each css key to be assigned a colour
        foreach my $k (keys %{$assigns{$type}}) {
          my $colour = $value->{$assigns{$type}->{$k}};
          next if !defined $colour and $assigns{$type}->{$k} ne 'default';

          # Convert colour names to hex
          if(($m->{'colour'}||'hex') eq 'name') {
            $colour = $colourmap->hex_by_name($colour);
          } elsif(defined $colour and $colour ne '') {
            $colour = "#$colour";
          }

          $style{$k} = $colour if defined $colour;
        }

        # Add extra css and store
        %style = (%style, %{$m->{'css'}||{}});
        my $key = _value($m->{'class'}||$m->{'name'},$config);
        $cache->{$key} = [$j++,{}] unless $cache->{$key};
        $cache->{$key}[1] = { %{$cache->{$key}[1]}, %style };
      }
    }
  }

  return $cache;
}

sub convert_class_to_style {
  my ($hub,$current_class,$config) = @_;

  return undef unless @$current_class;
  my %class_to_style = %{make_class_to_style_map($hub,$config)};
  my %style_hash;
  foreach (sort { $class_to_style{$a}[0] <=> $class_to_style{$b}[0] } @$current_class) {
    my $st = $class_to_style{$_}[1];
    map $style_hash{$_} = $st->{$_}, keys %$st;
  }
  return join ';', map "$_:$style_hash{$_}", keys %style_hash;
}

sub create_legend {
  my ($hub,$config,$extra) = @_;

  my $class_to_style = make_class_to_style_map($hub,$config);
  my $species_defs = $hub->species_defs;
  my $seq = load_styles;
  my (%legend,%sources);

  # Iterate through config file entries
  foreach my $e (@$seq) {
    if($e->{'source'}) {
      $sources{$e->{'source'}} ||=
        $species_defs->colour($e->{'source'});
    }

    # Build list of members (kind "all" has more than one)
    my @m;
    if(($e->{'kind'}||'one') eq 'all') {
      foreach my $k (keys %{$sources{$e->{'source'}}}) {
        push @m,{ %$e, name => $k };
      }
    } else {
      push @m,$e;
    }

    # For each member
    foreach my $m (@m) {
      my $section = _value($m->{'section'},$config);
      next unless $section;
      my $out = ($legend{$section}||={});
      my $source;
      $source = $sources{$m->{'source'}} if $m->{'source'};
      my $source_key = ($m->{'key'}||$m->{'name'});
      my $text = $m->{'text'};
      if(!defined $text and $source and $source->{$source_key}) {
        $text = $source->{$source_key}{'text'};
      }
      $text = _value($text,$config);
      my $class = _value($m->{'class'}||$m->{'name'},$config);
      my $dest = ($out->{$m->{'name'}} ||= { config => $m->{'name'} });
      $dest->{'text'} = $text if defined $text;
      $dest->{'class'} = $class if defined $class;
      $dest->{'config'} = $m->{'config'} if $m->{'config'};
      if($m->{'message'}) {
        $dest->{'messages'} ||= [];
        my $messages = [_value($m->{'message'},$config)];
        $messages = $messages->[0] if ref($messages->[0]) eq 'ARRAY';
        push @{$dest->{'messages'}},@$messages;
      }
      if($m->{'title'}) {
        $dest->{'title'} = _value($m->{'title'},$config);
      }
      if($m->{'legend-css'}) {
        $dest->{'extra_css'} =
          join(' ', map { "$_: $m->{'legend-css'}{$_};" }
                      keys %{$m->{'legend-css'}});
      }
    }
  }

  # Add in extra explicit legends from call
  %legend = (%legend, %{$extra||{}});

  # Set colours based on style mapping and class
  foreach my $k (keys %legend) {
    foreach my $g (values %{$legend{$k}}) {
      my $style = $class_to_style->{$g->{'class'}}[1];
      $g->{'default'} = $style->{'background-color'};
      $g->{'label'} = $style->{'color'};
    }
  }

  return \%legend;
}

1;
