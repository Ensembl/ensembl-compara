=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Factory;

### Base class for Factories that create data objects, i.e.
### EnsEMBL::Web::Object::[type] objects

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $data) = @_;
  my $self = { data => $data };
  bless $self, $class;
  return $self; 
}

sub __data             { return $_[0]{'data'};                      }
sub hub                { return $_[0]{'data'}{'_hub'};              }
sub species            { return $_[0]->hub->species;                }
sub species_defs       { return shift->hub->species_defs(@_);       }
sub species_path       { return shift->hub->species_path(@_);       }
sub database           { return shift->hub->database(@_);           }
sub problem            { return shift->hub->problem(@_);            }
sub has_a_problem      { return shift->hub->has_a_problem(@_);      }
sub clear_problems     { return shift->hub->clear_problems(@_);     }
sub clear_problem_type { return shift->hub->clear_problem_type(@_); }
sub delete_param       { shift->hub->delete_param(@_);              }

sub param {
  my @params = shift->hub->param(@_);
  return wantarray ? @params : $params[0];
}

# When we expect params etc to be correct, eg in component calls, we need
# not spend the considerable time spent in factories to extract params
# and add missing ones. In this case we can call createObjectsInternal
# rather than createObjects. For factories without a different
# implementation, they fallback to createObjects.
sub canLazy { return 0; }

sub generate_object {
  ### Used to create an object of a different type to the current factory
  ### For example, a Gene object will generate a Location object when the top tabs are created
  
  my $self = shift;
  my $type = shift;
 
  return 0 if @{$self->__data->{'_dataObjects'}{$type}||[]};
  
  my $new_factory = $self->new_factory($type, $self->__data);
  $new_factory->createObjects(@_);
  foreach my $type (keys %{$new_factory->DataObjects}) {
    push @{$self->__data->{'_dataObjects'}{$type}||=[]},@{$new_factory->DataObjects->{$type}};
  }
  return 1;
}


sub SetTypedDataObject {
  my ($self,$type,$obj) = @_;

  push @{$self->__data->{'_dataObjects'}{$type}||=[]},$obj;
}

sub DataObjects {
  my $self = shift;
  
  if (@_) {
    foreach (@_) {
      next unless $_;
      push @{$self->__data->{'_dataObjects'}{$_->__objecttype}||=[]},$_;
    }
    $self->__data->{'_dataObjectFirst'} ||= $_[0];
  }
  return $self->__data->{'_dataObjects'};
}

sub object {
  my $self = shift;
  return $self->__data->{'_dataObjectFirst'};
}

sub clearDataObjects {
  my $self = shift;
  $self->__data->{'_dataObjects'} = {};
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
  
  my $hub          = $self->hub;
  my $db           = $hub->param('db') || 'core';
  my $name         = $hub->param($parameter);
  my $species_defs = $hub->species_defs;
  my $sitetype     = $species_defs->ENSEMBL_SITETYPE || 'Ensembl';
  my $adaptor_name = "get_${type}Adaptor";
  my ($adaptor, @features, $feature);
  
  eval {
    $adaptor = $hub->database($db)->$adaptor_name; 
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
    $hub->problem('fatal', "Error retrieving $type from database", $self->_help("An error occured while trying to retrieve the $type $name."));
  } elsif (@features) { # Mapped features
    $feature = $features[0];
    $hub->param($var, $feature->stable_id);
  } else {
    $adaptor = $hub->database(lc $db)->get_UnmappedObjectAdaptor;
    
    eval { 
      @features = @{$adaptor->fetch_by_identifier($name)}; 
    };
    
    if (@features && !$@) { # Unmapped features
      my $id   = $hub->param('peptide') || $hub->param('transcript') || $hub->param('gene');
      my $type = $hub->param('gene') ? 'Gene' : $hub->param('peptide') ? 'ProteinAlignFeature' : 'DnaAlignFeature';
      my $url  = sprintf '%s/Location/Genome?type=%s;id=%s', $species_defs->species_path, $type, $id;
      
      $hub->problem('redirect', $url);
    } else {
      $name = encode_entities($name);
      $hub->problem('fatal', "$type '$name' not found", $self->_help("The identifier '$name' is not present in the current release of the $sitetype database.")) if $type eq $hub->type;
      $hub->delete_param($var)
        ## hack for ENSWEB-1706 - do not delete 'g' param since it might contain comma separated multiple gene ids
        unless $hub->script eq 'ZMenu' && $hub->type eq 'Gene' && $var eq 'g';
        ## hack end - remove once Gene factory is capable of dealing with multiple Gene objects
    }
  }
  
  return $feature;
}



1;

