package EnsEMBL::Web::Text::FeatureParser;

### This object parses data supplied by the user and identifies 
### sequence locations for use by other Ensembl objects

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::Root;
use Data::Dumper;

sub new {
  my ($class, $species_defs) = @_;
  my $data = {
  'format'            => '',
  'style'             => '',
  'feature_count'     => 0,
  'valid_coords'      => {},
  'browser_switches'  => {},
  'tracks'            => {},
  'filter'            => undef,
  '_current_key'      => 'default',
  };
  my $drawn_chrs = $species_defs->ENSEMBL_CHROMOSOMES;
  my $all_chrs = $species_defs->ALL_CHROMOSOMES;
  foreach my $chr (@$drawn_chrs) {
    $data->{'valid_coords'}{$chr} = $all_chrs->{$chr};  
  }
  bless $data, $class;
  return $data;
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
  return 'No data supplied' unless $data;

  my $error = $self->check_format($data, $format);
  if ($error) {
    warn "!!! PARSER ERROR $error";
    return $error;
  }
  else {
    $format = uc($self->format);
    my $filter = $self->filter;

    ## Some complex formats need extra parsing capabilities
    my $sub_package = __PACKAGE__."::$format";
    if (EnsEMBL::Web::Root::dynamic_use(undef, $sub_package)) {
      bless $self, $sub_package;
    }

    ## Create an empty feature that gives us access to feature info
    my $feature_class = 'EnsEMBL::Web::Text::Feature::'.uc($format); 
    my $empty = $feature_class->new();
    my $count;
    my $current_max = 0;
    my $current_min = 0;
    my $valid_coords = $self->{'valid_coords'};

    foreach my $row ( split /\n|\r/, $data ) {
      ## Skip crap and clean up what's left
      next unless $row;
      next if $row =~ /^#/;
      $row =~ s/[\t\r\s]+$//g;

      ## Parse as appropriate
      if ( $row =~ /^browser\s+(\w+)\s+(.*)/i ) {
        $self->{'browser_switches'}{$1} = $2;
      }
      elsif ($row =~ /^track/) {
        $row =~ s/^track\s+(.*)$/$1/i;
        $self->add_track($row);
        ## Reset max and min in case this is a multi-track file
        $current_max = 0;
        $current_min = 0;
      }
      else {
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
          $chr =~ s/chr//;

          if (keys %$valid_coords) {
            ## We only validate on chromosomal coordinates, to prevent errors on vertical code
            next unless $valid_coords->{$chr}; ## Chromosome is valid and has length
            next unless $start > 0 && $end <= $valid_coords->{$chr};
          
          }

          ## Optional - filter content by location
          my $filter = $self->filter;
          if ($filter->{'chr'}) {
            next unless ($chr eq $filter->{'chr'} || $chr eq 'chr'.$filter->{'chr'}); 
            if ($filter->{'start'} && $filter->{'end'}) {
              next unless $start >= $filter->{'start'} && $end <= $filter->{'end'};
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
  }
}

sub split_into_columns {
  my ($self, $row, $format) = @_;
  my @columns;
  my $tabbed = 0;
  if ($format) { ## Parsing a known file
    if ($format =~ /^GF/) {
      @columns = split /\t/, $row;
      $tabbed = 1;
    }
    else {
      @columns = split /\t|\s/, $row;
    } 
  }
  else { ## Trying to identify the format
    if ($row =~ /\t/) {
      @columns = split /\t/, $row;
      $tabbed = 1;
    }
    else {
      @columns = split /\s/, $row;
    }
  }
  @columns = grep /\S/, @columns;
  return (\@columns, $tabbed);
}

sub check_format {
  my ($self, $data, $format) = @_;

  unless ($format) {
    foreach my $row ( split /\n|\r/, $data ) {
      next unless $row;
      next if $row =~ /^#/;
      next if $row =~ /^browser/; 
      last if $format;
      if ($row =~ /^reference/i) {
        $format = 'GBROWSE';
        last;
      }
      elsif ($row =~ /^track\s+/i) {
        if ($row =~ /type=wiggle0/) {
          $self->style('wiggle');
          $format = 'WIG';
          last;
        }
        elsif ($row =~ /type=bedGraph/ || $row =~ /type=wiggle_0/) {
          $self->style('wiggle');
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
  if (!$format || !(EnsEMBL::Web::Root::dynamic_use(undef, 'EnsEMBL::Web::Text::Feature::'.uc($format))) ) {
    return 'Unrecognised format';
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
  my ($columns, $tabbed) = $self->split_into_columns($row);

  if (scalar(@$columns) == 1) {
    ## one element per line assume we have list of stable IDs
    $format = 'ID';
  }
  elsif (scalar(@$columns) == 21 && $columns->[8] =~/^[-+][-+]?$/) {
    $format = 'PSL';   
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

sub add_track {
  my ($self, $row) = @_;
  my $config = {'name' => 'default'};

  ## Pull out any parameters with "-delimited strings (without losing internal escaped '"')
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

  $self->current_key($config->{'name'});
  $self->{'tracks'}{ $self->current_key } = { 'features' => [], 'config' => $config };
}
 
sub store_feature {
  my ( $self, $feature ) = @_; 
  unless ($self->{'tracks'}{$self->current_key}) {
    $self->add_track();
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
  $chr =~ s/chr//;
  unless ($self->{'tracks'}{$self->current_key}) {
    $self->add_track();
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
