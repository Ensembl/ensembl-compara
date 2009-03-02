package EnsEMBL::Web::Factory::DAS;

use strict;
use warnings;

use EnsEMBL::Web::Factory::Location;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory::Location );
use POSIX qw(floor ceil);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  return $self; 
}

#----------------- Create objects ----------------------------------------------
## Create objects looks for a series of parameters passed to the script:
## (1) Primary slice: c = sr:start:ori; w = width
##                     srr = ?; cr = ?; cl = ?; srs = ?; srn = ?; srl = ?; srw = ?; c.x = ?
## (2) Alternate slices:
##                     s{n} = species; [c{n} = sr:start:ori; w{n};] 
##               -or-  s{n} = species; [sr{n} = sr;]
## OR
##
## (1) Primary slice: gene = gene;
## (2) Alternate slices:
##                     s{n} = species; g{n} = gene; 

sub featureTypes {
  my $self = shift;
  push @{$self->{'data'}{'_feature_types'}}, @_ if @_;
  return $self->{'data'}{'_feature_types'};
}

sub featureIDs {
  my $self = shift;
  push @{$self->{'data'}{'_feature_ids'}}, @_ if @_;
  return $self->{'data'}{'_feature_ids'};
}

sub groupIDs {
  my $self = shift;
  push @{$self->{'data'}{'_group_ids'}}, @_ if @_;
  return $self->{'data'}{'_group_ids'};
}

sub createObjects { 
  my $self      = shift;    
  $self->get_databases('core');
  my $database  = $self->database('core');
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $database;

  my @locations;

  if( my @segments = $self->param('segment')) {
    foreach my $segment (grep { $_ } @segments) {
      if( $segment =~ /^([-\w\.]+):(-?[\.\w]+),([\.\w]+)$/ ) {
        my($sr,$start,$end) = ($1,$2,$3);
        $start = $self->evaluate_bp($start);
        $end   = $self->evaluate_bp($end);
        if( my $loc = $self->_location_from_SeqRegion( $sr,$start,$end,1,undef) ) {
          push @locations, $loc;
        } else {
          my $type = $self->_location_from_SeqRegion( $sr,undef,undef,1,undef) ? 'ERROR' : 'UNKNOWN';
          push @locations, { 'REGION' => $sr, 'START' => $start, 'STOP' => $end, 'TYPE' => $type };
        }
      } else {
        if (my $loc = $self->_location_from_SeqRegion( $segment,undef,undef,1,undef)) {
          push @locations, $loc;
        } else {
          push @locations, { 'REGION' => $segment, 'START' => '', 'STOP' => '', 'TYPE' => 'UNKNOWN' };
        }
      }
    }
  }

  $self->clear_problems();

  my @feature_types = $self->param('type');
  $self->featureTypes(@feature_types);

  my @feature_ids = $self->param('feature_id');
  $self->featureIDs(@feature_ids);

  my @group_ids = $self->param('group_id');
  $self->groupIDs(@group_ids);

  my $source = $ENV{ENSEMBL_DAS_TYPE};
  
  my $T = EnsEMBL::Web::Proxy::Object->new( "DAS::$source", \@locations, $self->__data );
  $T->FeatureIDs(   @feature_ids   );
  $T->FeatureTypes( @feature_types );
  $T->GroupIDs(     @group_ids     );
  if( $self->has_a_problem ) {
    $self->clear_problems();
    return $self->problem( 'Fatal', 'Unknown Source', "Could not locate source <b>$source</b>." );
  }
  $self->DataObjects( $T );
}

sub _location_from_SeqRegion {
  my( $self, $chr, $start, $end, $strand, $keep_slice ) = @_;
  if( defined $start ) {
    $start = floor( $start );
    $end   = $start unless defined $end;
    $end   = floor( $end );
    $end   = 1 if $end < 1;
    $strand ||= 1;
    $start = 1 if $start < 1;     ## Truncate slice to start of seq region
    ($start,$end) = ($end, $start) if $start > $end;
    foreach my $system ( @{$self->__coord_systems} ) {
      my $slice = undef;
      eval { $slice = $self->_slice_adaptor->fetch_by_region( $system->name, $chr, $start, $end, $strand ); };
      next if $@;
      if( $slice ) {
        next if( $start >  $slice->seq_region_length || $end >  $slice->seq_region_length );
        return $self->_create_from_slice( $system->name, "$chr\:$start,$end", $slice, undef, undef, $keep_slice );
      }
    }
    $self->problem( "fatal", "Locate error","Cannot locate region $chr: $start - $end on the current assembly." );
    return undef;
  } else {
    foreach my $system ( @{$self->__coord_systems} ) {
      my $TS;
      eval { $TS = $self->_slice_adaptor->fetch_by_region( $system->name, $chr ); };
 #     warn "DAS... ",$system->name," $chr\nDAS... $@";
      next if $@;
      return $self->_create_from_slice( $system->name , $chr, $self->expand($TS), '', $chr, $keep_slice ) if $TS;
    }
    if( $chr ) {
      $self->problem( "fatal", "Locate error","Cannot locate region $chr on the current assembly." );
    } else {
      $self->problem( "fatal", "Please enter a location","A location is required to build this page." );
    }
    return undef;
  }
}

sub _create_from_slice {
  my( $self, $type, $ID, $slice, $synonym, $real_chr, $keep_slice ) = @_;
  return
  EnsEMBL::Web::Proxy::Object->new(
    'Location',
    { 
      'slice'              => $slice,
      'type'               => $type,
      'real_species'       => $self->__species,
      'name'               => $ID,
      'seq_region_name'    => $slice->seq_region_name,
      'seq_region_type'    => $slice->coord_system->name(),
      'seq_region_start'   => $slice->start,
      'seq_region_end'     => $slice->end,
      'seq_region_strand'  => $slice->strand,
      'raw_feature_strand' => $slice->{'_raw_feature_strand'},
      'seq_region_length'  => $slice->seq_region_length,
      'synonym'            => $synonym,
    },
    $self->__data
  );

}
1;
