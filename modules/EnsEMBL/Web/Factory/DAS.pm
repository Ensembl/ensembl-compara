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

package EnsEMBL::Web::Factory::DAS;

use strict;

use POSIX qw(floor);

use base qw(EnsEMBL::Web::Factory::Location);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  return $self; 
}

sub DataObjects { return shift->EnsEMBL::Web::Factory::DataObjects(@_); }

# sub featureTypes {
  # my $self = shift;
  # push @{$self->__data->{'_feature_types'}}, @_ if @_;
  # return $self->__data->{'_feature_types'};
# }

# sub featureIDs {
  # my $self = shift;
  # push @{$self->__data->{'_feature_ids'}}, @_ if @_;
  # return $self->__data->{'_feature_ids'};
# }

# sub groupIDs {
  # my $self = shift;
  # push @{$self->__data->{'_group_ids'}}, @_ if @_;
  # return $self->__data->{'_group_ids'};
# }

sub createObjects { 
  my $self = shift; 
     
  my $database = $self->database('core'); 
  
  return $self->problem('fatal', 'Database Error', 'Could not connect to the core database.') unless $database;

  my @locations;

  if (my @segments = $self->param('segment')) {
    foreach my $segment (grep $_, @segments) {
      if ($segment =~ /^([-\w\.]+):(-?[\.\w]+),([\.\w]+)$/) {
        my ($sr, $start, $end) = ($1, $2, $3);
        
        $start = $self->evaluate_bp($start);
        $end   = $self->evaluate_bp($end);
        
        if (my $loc = $self->_location_from_SeqRegion($sr, $start, $end, 1)) {
          push @locations, $loc;
        } else {
          my $type = $self->_location_from_SeqRegion($sr, undef, undef, 1) ? 'ERROR' : 'UNKNOWN';
          
          push @locations, { REGION => $sr, START => $start, STOP => $end, TYPE => $type };
        }
      } else {
        if (my $loc = $self->_location_from_SeqRegion($segment, undef, undef, 1)) {
          push @locations, $loc;
        } else {
          push @locations, { REGION => $segment, START => '', STOP => '', TYPE => 'UNKNOWN' };
        }
      }
    }
  }

  $self->clear_problems;

  my @feature_types = $self->param('type');
  my @feature_ids   = $self->param('feature_id');
  my @group_ids     = $self->param('group_id');
  my $source        = $ENV{'ENSEMBL_DAS_TYPE'};
  my $das           = $self->new_object("DAS::$source", \@locations, $self->__data);
  
  # $self->featureTypes(@feature_types);
  # $self->featureIDs(@feature_ids);
  # $self->groupIDs(@group_ids);
  
  $das->FeatureIDs(@feature_ids);
  $das->FeatureTypes(@feature_types);
  $das->GroupIDs(@group_ids);
  
  if ($self->has_a_problem) {
    $self->clear_problems;
    return $self->problem('fatal', 'Unknown Source', "Could not locate source <b>$source</b>.");
  }
  
  $self->DataObjects($das);
}

sub _location_from_SeqRegion {
  my ($self, $chr, $start, $end, $strand) = @_;
  
  my $adaptor = $self->_slice_adaptor;
  
  if (defined $start) {
    $start = floor($start);
    $end   = $start unless defined $end;
    $end   = floor($end);
    $end   = 1 if $end   < 1;
    $start = 1 if $start < 1; ## Truncate slice to start of seq region
    ($start, $end) = ($end, $start) if $start > $end;
    $strand ||= 1;
    
    foreach my $system (@{$self->__coord_systems}) {
      my $slice;
      
      eval { $slice = $adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand); };
      
      return $self->new_location($system->name, "$chr\:$start,$end", $slice) if !$@ && $slice && !($start > $slice->seq_region_length || $end > $slice->seq_region_length);
    }
    
    $self->problem('fatal', 'Locate error', "Cannot locate region $chr: $start - $end on the current assembly.");
  } else {
    foreach my $system (@{$self->__coord_systems}) {
      my $slice;
      
      eval { $slice = $adaptor->fetch_by_region($system->name, $chr); };
      
      return $self->new_location($system->name, $chr, $self->expand($slice)) if !$@ && $slice;
    }
    
    if ($chr) {
      $self->problem('fatal', 'Locate error', "Cannot locate region $chr on the current assembly.");
    } else {
      $self->problem('fatal', 'Please enter a location', 'A location is required to build this page.');
    }
  }
  
  return undef;
}

sub new_location {
  my ($self, $type, $name, $slice) = @_;
  
  return $self->new_object('Location', { 
    slice              => $slice,
    type               => $type,
    real_species       => $self->__species,
    name               => $name,
    seq_region_name    => $slice->seq_region_name,
    seq_region_type    => $slice->coord_system->name,
    seq_region_start   => $slice->start,
    seq_region_end     => $slice->end,
    seq_region_strand  => $slice->strand,
    raw_feature_strand => $slice->{'_raw_feature_strand'},
    seq_region_length  => $slice->seq_region_length,
  }, $self->__data);
}

1;
