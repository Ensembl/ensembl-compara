# $Id$

package EnsEMBL::Web::Factory;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Proxiable);

# Additional Factory functionality

sub new {
  my ($class, $data) = @_;
  my $self = $class->SUPER::new($data);
  return $self;
}

sub param {
  my @params = shift->hub->param(@_);
  return wantarray ? @params : $params[0];
}

sub generate_object {
  ### Used to create an object of a different type to the current factory
  ### For example, a Gene object will generate a Location object when the top tabs are created
  
  my $self = shift;
  my $type = shift;
  
  return 0 if $self->DataObjectTypes->{$type};
  
  my $new_factory = $self->new_factory($type, $self->__data);
  $new_factory->createObjects(@_);
  $self->DataObjects(@{$new_factory->DataObjects});
  
  return 1;
}

sub DataObjects {
  my $self = shift;
  
  if (@_) {
    push @{$self->__data->{'_dataObjects'}}, @_;
    $self->DataObjectTypes(@_);
  }
  
  return $self->__data->{'_dataObjects'};
}

sub DataObjectTypes {
  my $self = shift;
  map $self->__data->{'_dataObjectTypes'}{$_->__objecttype} = 1, @_ if @_;
  return $self->__data->{'_dataObjectTypes'} || {};
}

sub object {
  my $self = shift;
  return $self->__data->{'_dataObjects'} ? $self->__data->{'_dataObjects'}[0] : undef;
}

sub clearDataObjects {
  my $self = shift;
  $self->__data->{'_dataObjects'} = [];
}

sub featureIds {
  my $self = shift;
  $self->__data->{'_feature_IDs'} = shift if @_;
  return $self->__data->{'_feature_IDs'};
}

sub _archive {
  ### Returns an ArchiveStableId if the parameter supplied can generate one
  ### Called by Factory::Gene and Factory::Transcript
  
  my ($self, $parameter) = @_;
  
  my $var = lc substr $parameter, 0, 1;
  my $archive_stable_id;
  
  if ($var =~ /^[gtp]$/) {
    my $db = $self->param('db') || 'core';
    my $id = $self->param($parameter);
    
    $id =~ s/(\S+)\.(\d+)/$1/; # remove version
    
    eval {
      $archive_stable_id = $self->database($db)->get_ArchiveStableIdAdaptor->fetch_by_stable_id($id);
    };
  }
  
  return $archive_stable_id;
}


sub _help {
  my ($self, $string) = @_;
  return sprintf '<p>%s</p>', encode_entities($string);
}

sub _known_feature {
  ### Returns a feature if one can be generated from the feature type and parameter supplied
  ### Can generate mapped features from display_label or external_name, or unmapped features by identifier
  ### Sets URL param for $var if a mapped feature is generated - makes sure the URL generated for redirect is correct
  ### Called by Factory::Gene and Factory::Transcript
  
  my ($self, $type, $parameter, $var) = @_;
  
  my $db           = $self->param('db') || 'core';
  my $name         = $self->param($parameter);
  my $species_defs = $self->species_defs;
  my $sitetype     = $species_defs->ENSEMBL_SITETYPE || 'Ensembl';
  my $adaptor_name = "get_${type}Adaptor";
  my ($adaptor, @features, $feature);
  
  eval {
    $adaptor = $self->database($db)->$adaptor_name; 
  };
  
  die "Factory: Unknown DBAdapter in get_known_feature: $@" if $@;
  
  eval {
    my $f = $adaptor->fetch_by_display_label($name);
    push @features, $f if $f;
  };
  
  if (!@features) {
    eval {
      @features = @{$adaptor->fetch_all_by_external_name($name)};
    };
  }
  
  if ($@) {
    $self->problem('fatal', "Error retrieving $type from database", $self->_help("An error occured while trying to retrieve the $type $name."));
  } elsif (@features) { # Mapped features
    $feature = $features[0];
    $self->param($var, $feature->stable_id);
  } else {
    $adaptor = $self->database(lc $db)->get_UnmappedObjectAdaptor;
    
    eval { 
      @features = @{$adaptor->fetch_by_identifier($name)}; 
    };
    
    if (@features && !$@) { # Unmapped features
      my $id   = $self->param('peptide') || $self->param('transcript') || $self->param('gene');
      my $type = $self->param('gene') ? 'Gene' : $self->param('peptide') ? 'ProteinAlignFeature' : 'DnaAlignFeature';
      my $url  = sprintf '%s/Location/Genome?type=%s;id=%s', $species_defs->species_path, $type, $id;
      
      $self->problem('redirect', $url);
    } else {
      $self->problem('fatal', "$type '$name' not found", $self->_help("The identifier '$name' is not present in the current release of the $sitetype database."));
    }
  }
  
  return $feature;
}

sub problem            { return shift->hub->problem(@_);            }
sub has_a_problem      { return shift->hub->has_a_problem(@_);      }
sub clear_problems     { return shift->hub->clear_problems(@_);     }
sub clear_problem_type { return shift->hub->clear_problem_type(@_); }

1;

