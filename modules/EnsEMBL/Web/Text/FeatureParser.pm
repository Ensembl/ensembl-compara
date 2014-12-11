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

package EnsEMBL::Web::Text::FeatureParser;

### This object parses data supplied by the user and identifies 
### sequence locations for use by other Ensembl objects

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Root;
use List::MoreUtils;
use Carp qw(cluck);
use Data::Dumper;

sub new {
  my ($class, $species_defs, $location, $data_species) = @_;
  
  $data_species ||= $ENV{'ENSEMBL_SPECIES'};
  
  my $drawn_chrs   = $species_defs->get_config($data_species, 'ENSEMBL_CHROMOSOMES');
  my $all_chrs     = $species_defs->get_config($data_species, 'ALL_CHROMOSOMES');
  my $colourlist   = $species_defs->TRACK_COLOUR_ARRAY || [qw(black red blue green)];
  
  my $self = {
    current_location => $location,
    drawn_chrs       => $drawn_chrs,
    colourlist       => $colourlist,
    colourmap        => { map { $_ => 0 } @$colourlist },
  };
  
  bless $self, $class;
  
  $self->reset;
  
  return $self;
}

sub defaults {
  return (
    format           => '',
    style            => '',
    feature_count    => 0,
    nearest          => undef,
    browser_switches => {},
    tracks           => {},
    filter           => undef,
    _current_key     => 'default',
    _find_nearest    => {},
  );
}

sub reset {
  my $self     = shift;
  my %defaults = $self->defaults;
  $self->{$_} = $defaults{$_} for keys %defaults;
}

sub get_all_tracks{$_[0]->{'tracks'}}

sub fetch_features_by_tracktype{
  my ( $self, $type ) = @_;
  return $self->{'tracks'}{ $type }{'features'} ;
}

sub current_key {
  my $self = shift;
  $self->{'_current_key'} = shift if @_;
  return $self->{'_current_key'};
}

sub format {
  my $self = shift;
  $self->{format} = shift if @_;
  return $self->{'format'};
}

sub style {
  my $self = shift;
  $self->{style} = shift if @_;
  return $self->{'style'};
}

sub feature_count {
  my $self = shift;
  $self->{feature_count} = shift if @_;
  return $self->{'feature_count'};
}

sub drawn_chrs {
  my $self = shift;
  $self->{drawn_chrs} = shift if @_;
  return $self->{'drawn_chrs'};
}

sub nearest {
  my $self = shift;
  $self->{nearest} = shift if @_;
  return $self->{'nearest'};
}

sub filter {
  my ($self, @args) = @_;
  if (scalar(@args) && $args[0] ne 'ALL') {
    $self->{'filter'} = {
      'chr'   => $args[0],
      'start' => $args[1],
      'end'   => $args[2],
    };
  }
  return $self->{'filter'};
}

sub parse { 
  my ($self, $data, $format) = @_;
  ## Make sure format is given as uppercase
  $format = uc($format);
  $format = 'BED' if $format =~ /BEDGRAPH|BGR/;
  return 'No data supplied' unless $data;

  my $error = $self->check_format($data, $format);
  if ($error) {
    return $error;
  }
  else {
    my $filter = $self->filter;

    ## Some complex formats need extra parsing capabilities
    my $sub_package = __PACKAGE__."::$format";
    if (EnsEMBL::Root::dynamic_use(undef, $sub_package)) {
      bless $self, $sub_package;
    }
    ## Create an empty feature that gives us access to feature info
    my $feature_class = 'EnsEMBL::Web::Text::Feature::'.$format;  
    my $empty = $feature_class->new();
    my $count;
    my $current_max = 0;
    my $current_min = 0;

    ## On upload, keep track of current location so we can find nearest feature
    my ($current_index, $current_region, $current_start, $current_end);    
    if (@{$self->{'drawn_chrs'}} && (my $location = $self->{'current_location'})) {
      ($current_region, $current_start, $current_end) = split(':|-', $location);
      $current_index = List::MoreUtils::first_index {$_ eq $current_region} @{$self->drawn_chrs} if $current_region;
    }

    my ($track_def, $track_def_base);
    foreach my $row ( split /\n|\r/, $data ) { 
      ## Clean up the row
      next if $row =~ /^#/;
      $row =~ s/^[\t\r\s]+//g;
      $row =~ s/[\t\r\s]+$//g;
      $row =~ tr/\x80-\xFF//d;
      next unless $row;

      ## Parse as appropriate
      if ( $row =~ /^browser\s+(\w+)\s+(.*)/i ) {
        $self->{'browser_switches'}{$1} = $2;
      }
      ## Build track definition - could be multiple lines
      elsif ($row =~ /^track/) {
        $track_def_base = $row;
        $track_def      = $track_def_base;
      }
      elsif ($format eq 'WIG' && $row !~ /^\d+/) {
        ## Some WIG files have partial track definitions
        if (!$track_def) {
          $track_def = $track_def_base;
        }
        $track_def .= ' '.$row;
      }
      else { 
        ## Parse track definition, if any
        if ($track_def) {
          my $config = $self->parse_track_def($track_def);
          $self->add_track($config);
          if (ref($self) eq 'EnsEMBL::Web::Text::FeatureParser::WIG') {
            $self->style('wiggle');
            $self->set_wig_config;
          }
          elsif ($config->{'type'} eq 'bedGraph' || $config->{'type'} =~ /^wiggle/ 
                || ($config->{'useScore'} && $config->{'useScore'} > 2)) {
            $self->style('wiggle');
          }

          ## Reset values in case this is a multi-track file
          $track_def = '';
          $current_max = 0;
          $current_min = 0;
        }

        my $columns; 
        if (ref($self) eq 'EnsEMBL::Web::Text::FeatureParser') { 
          ## 'Normal' format consisting of a straightforward feature 
          ($columns) = $self->split_into_columns($row, $format);  
        }
        else { 
          ## Complex format requiring special parsing (e.g. WIG)
          $columns = $self->parse_row($row);
        }
        if ($columns && scalar(@$columns)) {   
          my ($chr, $start, $end) = $empty->coords($columns); 
          
          $chr =~ s/[cC]hr// unless grep {$_ eq $chr} @{$self->drawn_chrs};
          
          ## We currently only do this on initial upload (by passing current location)  
          $self->{'_find_nearest'}{'done'} = $self->_find_nearest(
                      {
                        'region'  => $current_region, 
                        'start'   => $current_start, 
                        'end'     => $current_end, 
                        'index'   => $current_index,
                      }, 
                      {
                        'region'  => $chr, 
                        'start'   => $start, 
                        'end'     => $end,
                        'index'   => List::MoreUtils::first_index {$_ eq $chr} @{$self->drawn_chrs},
                      }
            ) unless $self->{'_find_nearest'}{'done'};
          
          ## Optional - filter content by location
          if ($filter->{'chr'}) {
            next unless ($chr eq $filter->{'chr'} || $chr eq 'chr'.$filter->{'chr'}); 
            if ($filter->{'start'} && $filter->{'end'}) {
              next unless (
                ($start >= $filter->{'start'} && $end <= $filter->{'end'}) ## feature lies within coordinates
                || ($start < $filter->{'start'} && $end >= $filter->{'start'}) ## feature overlaps start
                || ($end > $filter->{'end'} && $start <= $filter->{'end'}) ## feature overlaps end
  
              );
            }
          }

          ## Everything OK, so store
          if ($self->no_of_bins) {
            $self->store_density_feature($empty->coords($columns));
          }
          else {
            my $feature = $feature_class->new($columns); 
            if ($feature->can('score')) {
              $current_max = $self->{'tracks'}{$self->current_key}{'config'}{'max_score'};
              $current_min = $self->{'tracks'}{$self->current_key}{'config'}{'min_score'};
              $current_max = $feature->score if $feature->score > $current_max;
              $current_min = $feature->score if $feature->score < $current_min;
              $current_max = 0 unless $current_max; ## Because bad things can happen...
              $current_min = 0 unless $current_min;
              $self->{'tracks'}{$self->current_key}{'config'}{'max_score'} = $current_max;
              $self->{'tracks'}{$self->current_key}{'config'}{'min_score'} = $current_min;
            }
            $self->store_feature($feature);
          }
          $count++;
        }
      }
    }
    $self->{'feature_count'} = $count;
    ## Extend sample coordinates a bit!
    if ($self->{'_find_nearest'}{'nearest_region'}) {
      my $midpoint = int(abs($self->{'_find_nearest'}{'nearest_start'} 
                              - $self->{'_find_nearest'}{'nearest_end'})/2) 
                              + $self->{'_find_nearest'}{'nearest_start'};
      my $start = $midpoint < 50000 ? 0 : ($midpoint - 50000);
      my $end = $start + 100000;
      $self->{'nearest'} = $self->{'_find_nearest'}{'nearest_region'}.':'.$start.'-'.$end;
    }
  }
}

sub split_into_columns {
  my ($self, $row, $format) = @_;
  my @columns; ;
  my $tabbed = 0;
  if ($format) { ## Parsing a known file
    if ($format =~ /^GF/) {
      @columns = split /\t/, $row;
      $tabbed = 1;
    }
    else { 
      @columns = split /\t|\s+/, $row; ; 
    } 
  }
  else { ## Trying to identify the format
    if ($row =~ /\t/) {
      @columns = split /\t/, $row;
      $tabbed = 1;
    }
    else {
      @columns = split /\s+/, $row;
    }
  }
  ## Clean up any remaining white space and non-printing characters
  foreach (@columns) {
    next unless $_ =~ /\d+/;
    $_ =~ tr/\x80-\xFF//d;
    $_ =~ s/^\s+//;
    $_ =~ s/\s+$//;
  }
  ## Remove any empty columns where these are not allowed by format 
  if ($format && ($format eq 'BED' || $format =~ /SNP/)) {
    @columns = grep /\S/, @columns;
  }
  elsif (!$self->format) {
    my @no_empties = grep /\S/, @columns;
    if ($no_empties[3] =~ /^[ACTG-]\/[ACTG-]$/) {
      $self->format('SNP');
      @columns = @no_empties;
    }
  }

  return (\@columns, $tabbed);
}


sub _find_nearest {
### Find the feature nearest the current location
  my ($self, $current, $feature) = @_;

  ## Set first feature as nearest if no location / chromosomes
  unless (exists($current->{'index'})) {
    $self->{'_find_nearest'}{'nearest_region'}  = $feature->{'region'};
    $self->{'_find_nearest'}{'nearest_start'}   = $feature->{'start'};
    $self->{'_find_nearest'}{'nearest_end'}     = $feature->{'end'};
    return 1;
  }

  my $nearest_index = List::MoreUtils::first_index {$_ eq $self->{'_find_nearest'}{'nearest_region'} } @{$self->drawn_chrs};

  if ($self->{'_find_nearest'}{'nearest_region'}) {
    if ($feature->{'region'} eq $current->{'region'}) { ## We're getting warm!
      $self->{'_find_nearest'}{'nearest_region'} = $feature->{'region'};
      ## Is this feature start nearer?
      if ($current->{'start'} ne '' && $feature->{'start'} ne '' && $self->{'_find_nearest'}{'nearest_start'} ne '' 
        && (abs($current->{'start'} - $feature->{'start'}) < abs($current->{'start'} - $self->{'_find_nearest'}{'nearest_start'}))) {
        $self->{'_find_nearest'}{'nearest_start'} = $feature->{'start'};
        $self->{'_find_nearest'}{'nearest_end'}   = $feature->{'end'};
      }
    }
    else {
      ## Is this chromosome nearer?
      if ($feature->{'index'} ne '' && $current->{'index'} ne '' && $nearest_index ne '' 
          && (abs($current->{'index'} - $feature->{'index'}) < abs($current->{'index'} - $nearest_index))) {
            $self->{'_find_nearest'}{'nearest_region'}  = $feature->{'region'};
            $self->{'_find_nearest'}{'nearest_start'}   = $feature->{'start'};
            $self->{'_find_nearest'}{'nearest_end'}     = $feature->{'end'};
      }
    }
  }
  else {
    ## Establish a baseline
    $self->{'_find_nearest'}{'nearest_region'}  = $feature->{'region'};
    $self->{'_find_nearest'}{'nearest_start'}   = $feature->{'start'};
    $self->{'_find_nearest'}{'nearest_end'}     = $feature->{'end'};
  }
  return 0;
}

sub check_format {
  my ($self, $data, $format) = @_;
  my $feature_class = 'EnsEMBL::Web::Text::Feature::'.$format;  
  unless ($format) {
    foreach my $row ( split /\n|\r/, $data ) { 
      next unless $row;
      next if $row =~ /^#/;
      next if $row =~ /^browser/; 
      last if $format; 
      if ($row =~ /^track\s+/i) {
        if ($row =~ /type=wiggle0/) {
          $format = 'WIG';
          last;
        }
        elsif ($row =~ /type=bedGraph/ || $row =~ /type=wiggle_0/ || $row =~ /useScore=[1|2|3|4]/) { 
          $format = 'BED';
          last;
        }
        next;
      }
      else {
        ## Parse a row of actual data
        $format = $self->analyse_row($row);
      }
    }
  }

  ## Sanity check - can we actually parse this?
  if ($format && !(EnsEMBL::Root::dynamic_use(undef, 'EnsEMBL::Web::Text::Feature::'.uc($format))) ) {
    return 'Unsupported format';
  }
  if (!$format) {
    return 'Unrecognised format';
  }
	if (defined &{$feature_class .'::check_format'}){ # If needed, create this function in EnsEMBL::Web::Text::Feature::[format]
		my $result= $feature_class->check_format($data);
		if($result){return "Incorrect format:$result";}
	}
  $self->format($format);
  return undef;
}

sub analyse_row {
### Parses an individual row of data, i.e. a single feature
  my( $self, $row ) = @_;
  my $format;

  return unless $row =~ /\d+/g ;
  ## Remove trailing white space
  $row =~ s/[\t\r\s]+$//g;
 
  ## Split row into columns by either tabs or whitespaces, then remove empty values 
  my ($columns, $tabbed) = $self->split_into_columns($row, $self->format);

  if (scalar(@$columns) == 1) { 
    ## one element per line assume we have list of stable IDs
    $format = 'ID';
  }
  elsif (scalar(@$columns) == 21 && $columns->[8] =~/^[-+][-+]?$/) {
    $format = 'PSL';   
  }
  elsif (
    $columns->[3] =~ /^[ACTG-]+\/[ACTG-]+$/ ||
    (
      $columns->[0] =~ /(chr)?\w+/ &&
      $columns->[1] =~ /\d+/ &&
      $columns->[2] =~ /^[ACGTN-]+$/ &&
      $columns->[3] =~ /^[ACGTNRYSWKM*+\/-]+$/
    ) ||
    (
      $columns->[0] =~ /(chr)?\w+/ &&
      $columns->[1] =~ /\d+/ &&
      $columns->[3] =~ /^[ACGTN-]+$/ &&
      $columns->[4] =~ /^([\.ACGTN-]+\,?)+$/
    )
  ) {
    $format = 'SNP';
  }
  elsif ($tabbed && _is_strand($columns->[7])) {
    if ($columns->[8] =~ /(; )+/ && $columns->[8] =~ /^[gene_id|transcript_id]/) {
      $format = 'GTF';   
    } 
    else {
      $format = 'GFF';   
    }
  }
  elsif ( _is_strand($columns->[9])) { # DAS format accepted by Ensembl
    $format = 'DAS';   
  } 
  elsif ($columns->[0] =~ /^>/ ) {  ## Simple format (chr/start/end/type
    $format = 'GENERIC';   
  } 
  elsif (scalar(@$columns) > 2 && scalar(@$columns) < 13 && $columns->[1] =~ /\d+/ && $columns->[2] =~ /\d+/) { 
    $format = 'BED';   
  }
  return $format;
}

sub _is_strand {
  my $value = shift;
  if ($value eq '+' || $value eq '-' || $value eq '.') {
    return 1;
  }
  else {
    return 0;
  }
}

sub parse_track_def {
  my ($self, $row) = @_;
  my $config = {'name' => 'default'};

  ## Pull out any parameters with "-delimited strings (without losing internal escaped '"')
  $row =~ s/^track\s+(.*)$/$1/i;
  while ($row =~ s/(\w+)\s*=\s*"(([\\"]|[^"])+?)"//) {
    my $key = $1;
    (my $value = $2) =~ s/\\//g;
    $config->{$key} = $value;
  }
  ## Grab any remaining whitespace-free content
  if ($row) {
    while ($row =~ s/(\w+)\s*=\s*(\S+)//) {
      $config->{$1} = $2;
    }
  }
  ## Now any value-less parameters (e.g. WIG style)
  if ($row) {
    while ($row =~ s/(\w+)//) {
      $config->{$1} = 1;
    }
  }
  ## Clean up chromosome names
  if (defined $config->{'chrom'}) {
    my $chr = $config->{'chrom'};
    $chr =~ s/[cC]hr// unless grep {$_ eq $chr} @{$self->drawn_chrs};
    $config->{'chrom'} = $chr;
  }
  ## Add a description
  unless (defined $config->{'description'}) {
    $config->{'description'} = $config->{'name'};
  }

  return $config;
}

sub add_track {
  my ($self, $config) = @_;

  if (defined $self->{'tracks'}{ $config->{'name'} }) {
    ## Just reset config
    my $old_config = $self->{'tracks'}{ $self->current_key }{'config'};
    while (my($k, $v) = each(%$config)) {
      $old_config->{$k} = $v;
    }
    $self->{'tracks'}{ $self->current_key }{'config'} = $old_config;
  }
  else {
    $self->current_key($config->{'name'});
    $self->{'tracks'}{ $self->current_key } = { 'features' => [], 'config' => $config };
    $self->_set_track_colour($config);
  }
}

sub _set_track_colour {
## Set a (ideally unique) colour if none given
  my ($self, $config) = @_;
  return unless $config;

  my @colours = @{$self->{'colourlist'}};
  if ($config->{'color'}) {
    $self->{'colourmap'}{$config->{'color'}} = 1;
  }
  else {
    foreach my $colour (@colours) {
      if (!$self->{'colourmap'}{$colour}) {
        $config->{'implicit_colour'} = 1;
        $config->{'color'} = $colour;
        $self->{'colourmap'}{$colour} = 1;
        last;
      }
    }
  }
}
 
sub store_feature {
  my ( $self, $feature ) = @_; 
  if (!$self->{'tracks'}{$self->current_key}) {
    $self->add_track();
  }
  elsif (!$self->{'tracks'}{$self->current_key}{'config'}{'color'}) {
    $self->_set_track_colour($self->{'tracks'}{$self->current_key}{'config'});
  }
  push @{$self->{'tracks'}{$self->current_key}{'features'}}, $feature;
}

##-----------------------------------------------------------

## DENSITY FEATURE FUNCTIONALITY

sub no_of_bins {
  my $self = shift;
  $self->{'_no_of_bins'} = shift if @_;
  return $self->{'_no_of_bins'};
}

sub bin_size {
  my $self = shift;
  $self->{'_bin_size'} = shift if @_;
  return $self->{'_bin_size'};
}

sub store_density_feature {
  my ( $self, $chr, $start, $end ) = @_;
  $chr =~ s/[cC]hr// unless grep {$_ eq $chr} @{$self->drawn_chrs};
  if (!$self->{'tracks'}{$self->current_key}) {
    $self->add_track();
  }
  elsif (!$self->{'tracks'}{$self->current_key}{'config'}{'color'}) {
    $self->_set_track_colour($self->{'tracks'}{$self->current_key}{'config'});
  }
  $start = int($start / $self->{'_bin_size'} );
  $end = int( $end / $self->{'_bin_size'} );
  $end = $self->{'_no_of_bins'} - 1 if $end >= $self->{'_no_of_bins'};
  $self->{'tracks'}{$self->current_key}{'bins'}{$chr} ||= [ map { 0 } 1..$self->{'_no_of_bins'} ];
  foreach( $start..$end ) {
    $self->{'tracks'}{$self->current_key}{'bins'}{$chr}[$_]++; 
  }
  $self->{'tracks'}{$self->current_key}{'counts'}++;
}

sub max_values {
  my $self = shift;
  my $max_value;
  while (my ($name, $track) = each (%{$self->{'tracks'}}) ) {
    $max_value->{$name} = 0;
    while (my ($chr, $values) = each (%{$track->{'bins'}}) ) {
      foreach my $v (@$values) {
        $max_value->{$name} = $v if $v > $max_value->{$name};
      }
    }
  }
  return $max_value;
}

1;
