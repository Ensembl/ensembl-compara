package EnsEMBL::Web::Text::FeatureParser;

### This object parses data supplied by the user and identifies sequence locations for use by other Ensembl objects

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::Root;
use Data::Dumper;

sub new {
  my $class = shift;
  my $data = {
  'format'            => '',
  'has_data'          => 0,
  'valid_coords'      => {},
  'browser_switches'  => {},
  'tracks'            => {},
  'filter'            => undef,
  '_current_key'      => 'default',
  };
  bless $data, $class;
  return $data;
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
    warn ">>> PARSING DATA $format";
    $format = uc($self->format);
    my $filter = $self->filter;

    ## Some complex formats need extra parsing capabilities
    if ($format eq 'WIG' || $format eq 'GBROWSE') {
      my $new_class = '__PACKAGE__'."::$format";
      bless $self, $new_class;
    }

    ## Create an empty feature that gives us access to feature info
    my $feature_class = 'EnsEMBL::Web::Text::Feature::'.uc($format); 
    my $empty = $feature_class->new();

    foreach my $row ( split /\n/, $data ) {

      ## Skip crap and clean up what's left
      next unless $row;
      next if $row =~ /^#/;
      $row =~ s/[\t\r\s]+$//g;

      ## Parse as appropriate
      if ( $row =~ /^browser\s+(\w+)\s+(.*)/i ) {
        $self->{'browser_switches'}{$1} = {$2};
      }
      elsif ($row =~ /^track/) {
        $row =~ s/^track\s+(.*)$/$1/i; 
        $self->add_track($row);
      }
      else {
        my $columns;
        if (ref($self) eq 'EnsEMBL::Web::Text::FeatureParser') {
          ## 'Normal' format consisting of a straightforward feature
          ($columns) = $self->split_into_columns($row);
        }
        else {
          ## Complex format requiring special parsing (e.g. WIG)
          $columns = $self->parse_row($row);
        }
        if ($columns && scalar(@$columns)) {
          ## Optional - filter content by location
          if ($filter) {
            my ($chr, $start, $end) = $empty->coords($columns);
            if ($chr eq $filter->{'chr'} || $chr eq 'chr'.$filter->{'chr'}) {
              if ($filter->{'start'} && $filter->{'end'}) {
                next unless $start >= $filter->{'start'} && $end <= $filter->{'end'};
              }
            }
            else {
              next;
            }
          }
          ## Check the coordinates are valid for this assembly

          ## Everything OK, so store
          my $feature = $feature_class->new($columns);
          $self->store_feature($feature);
        }
      }
    }
  }
}

sub split_into_columns {
  my ($self, $row) = @_;
  my @columns;
  my $tabbed = 0;
  if ($row =~ /\t/) {
    @columns = split /\t/, $row;
    $tabbed = 1;
  }
  else {
    @columns = split /\s/, $row;
  }
  @columns = grep /\S/, @columns;
  return (\@columns, $tabbed);
}

sub check_format {
  my ($self, $data, $format) = @_;

  unless ($format) {
    foreach my $row ( split /\n/, $data ) {
      next unless $row;
      next if $row =~ /^#/;
      next if $row =~ /^browser/; 
      last if $format;
      if ($row =~ /^reference/i) {
        $format = 'GBROWSE';
        last;
      }
      elsif ($row =~ /^track\s+/i) {
        if ($row =~ /type = wiggle/) {
          $format = 'WIG';
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

  ## Pull out any parameters with quote-delimited strings
  while ($row =~ s/(\w+)="(\w+|\s*)"//g) {
    $config->{$1} = $2;
  }
  ## Split on any remaining white space
  if ($row) {
    while ($row =~ /(\w+)=(\S+)/g) {
      $config->{$1} = $2;
    }
  }

  $self->current_key($config->{'name'});
  $self->{'tracks'}{ $self->current_key } = { 'features' => [], 'config' => $config };
}
 
sub store_feature {
  my ( $self, $feature ) = @_; 
  #warn $self->current_key." = FEATURE ".Dumper($feature);
  push @{$self->{'tracks'}{$self->current_key}{'features'}}, $feature;
}

sub get_all_tracks{$_[0]->{'tracks'}}

sub fetch_features_by_tracktype{
  my ( $self, $type ) = @_;
  return $self->{'tracks'}{ $type }{'features'} ;
}

1;
