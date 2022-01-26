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

package EnsEMBL::Web::TextSequence::ClassToStyle;

use strict;
use warnings;

use Exporter qw(import);

use File::Basename;
use YAML qw(LoadFile);

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Draw::Utils::ColourMap;

my %assigns = (
  'background' => { 'background-color' => 'default' },
  'foreground' => { 'color' => 'default' },
  'both' => { 'background-color' => 'default', color => 'label' }
);

sub new {
  my ($proto,$view) = @_;

  my $class = ref($proto) || $proto;
  my $self = { view => $view, cache => undef };
  bless $self,$class;
  return $self;
}

sub load_styles {
  my ($self) = @_;

  my @seq;
  foreach my $path (@{$self->{'view'}->style_files}) {
    push @seq,@{LoadFile($path)};
  }
  return \@seq;
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

sub style { return ($_[1],$_[2]); }

sub make_class_to_style_map {
  my ($self,$config) = @_;

  if(!$self->{'cache'}) {
    $self->{'cache'} = {};

    # Load the config
    my $seq = $self->load_styles;
    my %c2s;
    my $species_defs = EnsEMBL::Web::SpeciesDefs->new;
    my $colourmap    = EnsEMBL::Draw::Utils::ColourMap->new($species_defs);
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
        my %out_style;
        foreach my $k_in (keys %style) {
          my ($k,$v) = $self->style($k_in,$style{$k_in});
          $out_style{$k} = $v;
        }
        my $key = _value($m->{'class'}||$m->{'name'},$config);
        $self->{'cache'}{$key} = [$j++,{}] unless $self->{'cache'}{$key};
        $self->{'cache'}{$key}[1] = { %{$self->{'cache'}{$key}[1]}, %out_style };
      }
    }
  }

  return $self->{'cache'};
}

sub create_legend {
  my ($self,$config,$extra) = @_;

  my $class_to_style = $self->make_class_to_style_map($config);
  my $species_defs = EnsEMBL::Web::SpeciesDefs->new;
  my $seq = $self->load_styles;
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
      my $dest = ($out->{$m->{'name'}} ||= { config => $m->{'name'} });

      # Text comes from explicit config key or source
      my $source;
      $source = $sources{$m->{'source'}} if $m->{'source'};
      my $source_key = ($m->{'key'}||$m->{'name'});
      my $text = $m->{'text'};
      if(!defined $text and $source and $source->{$source_key}) {
        $text = $source->{$source_key}{'text'};
      }
      $text = _value($text,$config);
      $dest->{'text'} = $text if defined $text;

      # Class comes from explicit class key or name
      my $class = _value($m->{'class'}||$m->{'name'},$config);
      $dest->{'class'} = $class if defined $class;

      # Title, config and legend-css come from associated keys, if present
      $dest->{'title'} = _value($m->{'title'},$config) if $m->{'title'};
      $dest->{'config'} = $m->{'config'} if $m->{'config'};
      if($m->{'legend-css'}) {
        $dest->{'extra_css'} =
          join(' ', map { "$_: $m->{'legend-css'}{$_};" }
                      keys %{$m->{'legend-css'}});
      }

      # Message comes from messages key, but as an array
      if($m->{'message'}) {
        $dest->{'messages'} ||= [];
        my $messages = [_value($m->{'message'},$config)];
        $messages = $messages->[0] if ref($messages->[0]) eq 'ARRAY';
        push @{$dest->{'messages'}},@$messages;
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
