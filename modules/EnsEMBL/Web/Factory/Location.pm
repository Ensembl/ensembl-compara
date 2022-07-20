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

package EnsEMBL::Web::Factory::Location;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);
use POSIX qw(floor ceil);

use Bio::EnsEMBL::Feature;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Factory);

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new(@_);
  
  $self->__set_species;
  
  return $self;
}

sub __species       :lvalue { $_[0]->__data->{'__location'}{'species'};                                }
sub __species_hash  :lvalue { $_[0]->__data->{'__location'}{$_[0]->__data->{'__location'}{'species'}}; }
sub __level         :lvalue { $_[0]->__species_hash->{'level'};                                        }
sub __golden_path   :lvalue { $_[0]->__species_hash->{'golden_path'};                                  }
sub __coord_systems :lvalue { $_[0]->__species_hash->{'coord_systems'};                                }

sub _gene_adaptor                 { return shift->_adaptor('Gene',                 @_);           }
sub _transcript_adaptor           { return shift->_adaptor('Transcript',           @_);           }
sub _predtranscript_adaptor       { return shift->_adaptor('PredictionTranscript', @_);           }
sub _exon_adaptor                 { return shift->_adaptor('Exon',                 @_);           }
sub _variation_adaptor            { return shift->_adaptor("$_[0]Variation",        'variation'); }
sub _variation_feature_adaptor    { return shift->_adaptor("$_[0]VariationFeature", 'variation'); }
sub _slice_adaptor                { return shift->_adaptor('Slice');                              }
sub _coord_system_adaptor         { return shift->_adaptor('CoordSystem');                        }
sub _marker_adaptor               { return shift->_adaptor('Marker');                             }

sub _adaptor {
  my $self = shift;
  my $type = shift;
  my $db   = shift || 'core';
  my $func = "get_${type}Adaptor";
  
  return $self->__species_hash->{'adaptors'}{join '_', lc $type, $db} ||= $self->database($db, $self->__species)->$func; 
}

sub __gene_databases {
  my $self = shift;
  
  $self->__species_hash->{'gene_databases'} ||= [ map lc(substr $_, 9), @{$self->species_defs->core_like_databases || []} ];
  
  return @{$self->__species_hash->{'gene_databases'}};
}

sub DataObjects {
  my $self = shift;
  my $objects = $self->SUPER::DataObjects(@_);
  
  # Set the r parameter if a Location has been successfully created and
  # 1) There is no current r parameter OR
  # 2) The r parameter has a : (in other words, it's not a whole chromosome)

  if($self->hub->script !~ /Component|DataExport/) {
    my $loc = $objects->{'Location'}[0];
    $self->param('r', sprintf '%s:%s-%s', map $loc->$_, qw(seq_region_name seq_region_start seq_region_end)) if $loc && (!$self->param('r') || $self->param('r') =~ /:/);
  } 
  return $objects;
}

sub expand {
  my ($self, $slice) = @_;
  return $slice->expand($self->param('context'), $self->param('context'));
}

sub __set_species {
  my ($self, $species, $golden_path, $level) = @_;
  
  $species     ||= $self->species;
  $golden_path ||= $self->species_defs->get_config($species, 'ENSEMBL_GOLDEN_PATH');
  $golden_path ||= $self->species_defs->get_config($species, 'ASSEMBLY_VERSION');
  
  $self->__species = $species; # to store co-ordinate system information
  $self->__species_hash ||= {};

  unless (exists $self->__species_hash->{'golden_path'} && $self->__golden_path eq $golden_path) {
    $self->__golden_path = $golden_path;
    
    $self->__coord_systems = [
      grep { !$_->version || $_->version eq $self->__golden_path } @{$self->_coord_system_adaptor->fetch_all}
    ];
    
    $self->__level = undef; # clear current level if changing golden path
  }
  
  return if $self->__level;
  
  my %coord_systems = map { $_, 1 } @{$self->__coord_systems||[]};
  
  $level = undef unless $coord_systems{$level};
  $level ||= 'toplevel';
  
  $self->__level ||= $level;
}

sub canLazy { return defined $_[0]->param('r'); }
sub createObjectsInternal {
  my $self = shift;

  return undef if $self->param('a') or $self->param('align');
  my $db_adaptor = $self->database('core');
  return undef unless $db_adaptor;
  my $r = $self->param('r');
  return undef unless $r =~ /^([^:]+):(\d+)-(\d+)$/;
  my ($seq_region,$start,$end) = ($1,$2,$3);
  my $slice = $self->get_slice($seq_region, $start, $end);
  return undef unless $slice;
  return $self->new_location($slice);
}

sub createObjects {
  my $self  = shift;
  my $slice = shift;
  my ($location, $identifier, $ftype);
  
  my $db_adaptor = $self->database('core'); 
  
  return $self->problem('fatal', 'Database Error', 'Could not connect to the core database.') unless $db_adaptor;
    
  if ($slice) {
    $slice = $slice->invert if $slice->strand < 0;
    
    if (!$slice->is_toplevel) {
      my $toplevel_projection = $slice->project('toplevel');
      
      if (my $seg = shift @$toplevel_projection) {
        $slice = $seg->to_Slice;
      }
    }
    
    $location = $self->new_location($slice);
  } else {
    my ($seq_region, $start, $end, $strand);
    
    # Get seq_region, start, end, strand. These are obtained by either
    # 1) Parsing an r or l parameter
    # 2) Parsing a c/w or centrepoint/width parameter combination
    # 3) Reading the paramters listed in the else block below
    if ($identifier = $self->param('r') || $self->param('l')) {
      $identifier =~ s/\s|,//g;

      #using core API module to validate the location values, see core documentation for this method
      ($seq_region, $start, $end, $strand) = $self->_slice_adaptor->parse_location_to_values($identifier); 
      
      $start = $self->evaluate_bp($start);
      $end   = $self->evaluate_bp($end) || $start;
      $slice = $self->get_slice($seq_region || $identifier, $start, $end); 
      
      if ($slice) {
        return if $self->param('a') && $self->_map_assembly($slice->seq_region_name, $slice->start, $slice->end, 1);                             # Mapping from one assembly to another
        return $self->_create_from_sub_align_slice($slice) if $self->param('align_start') && $self->param('align_end') && $self->param('align'); # Mapping from an AlignSlice to a real location
        
        $location = $self->new_location($slice);
      } else {
        $location = $self->_location_from_SeqRegion($seq_region || $identifier, $start, $end); 
      }
    } else {
      $seq_region = $self->param('region')    || $self->param('contig')     ||
                    $self->param('clone')     || $self->param('seqregion')  ||
                    $self->param('chr')       || $self->param('seq_region_name');
                    
      $start      = $self->param('chr_start') || $self->param('vc_start') || $self->param('start');
                    
      $end        = $self->param('chr_end')   || $self->param('vc_end') || $self->param('end');
      
      $strand     = $self->param('strand')    || $self->param('seq_region_strand') || 1;
      
      $start = $self->evaluate_bp($start) if defined $start;
      $end   = $self->evaluate_bp($end)   if defined $end;      
      
      if ($identifier = $self->param('c')) {
        my ($cp, $t_strand);
        my $w = $self->evaluate_bp($self->param('w'));
        
        ($seq_region, $cp, $t_strand) = $identifier =~ /^([-\w\.]+):(-?[.\w,]+)(:-?1)?$/;
        
        $cp = $self->evaluate_bp($cp);
        
        $start  = $cp - ($w - 1) / 2;
        $end    = $cp + ($w - 1) / 2;
        $strand = $t_strand eq ':-1' ? -1 : 1 if $t_strand;
      } elsif ($identifier = $self->param('centrepoint')) {
        my $cp = $self->evaluate_bp($identifier);
        my $w  = $self->evaluate_bp($self->param('width'));
        
        $start = $cp - ($w - 1) / 2;
        $end   = $cp + ($w - 1) / 2;
      }

      my $anchor1 = $self->param('anchor1'); 
      
      if ($seq_region && !$anchor1) {
        if ($self->param('band')) {
          my $slice;
          eval {
            $slice = $self->_slice_adaptor->fetch_by_chr_band($seq_region, $self->param('band'));
          };
          $location = $self->new_location($slice) if $slice;
        }
        else {
          $location = $self->_location_from_SeqRegion($seq_region, $start, $end, $strand); # We have a seq region, and possibly start, end and strand. From this we can directly get a location
        }
      } else {
        # Mapping of supported URL parameters to function calls which should get a Location for those parameters
        # Ordered by most likely parameter to appear in the URL
        #
        # NB: The parameters listed here are all non-standard.
        # Any "core" parameters in the URL will cause Location objects to be generated from their respective factories
        # The exception to this is the Marker parameter m, since markers can map to 0, 1 or many locations, the location is not generated in the Marker factory
        # For a list of core parameters, look in Model.pm
        my @params = (
          [ 'Gene',        [qw(gene                            )] ],
          [ 'Transcript',  [qw(transcript                      )] ],
          [ 'Variation',   [qw(snp                             )] ],
          [ 'Exon',        [qw(exon                            )] ],
          [ 'Peptide',     [qw(p peptide protein               )] ],
          [ 'MiscFeature', [qw(mapfrag miscfeature misc_feature)] ],
          [ 'Marker',      [qw(m marker                        )] ],
          [ 'Band',        [qw(band                            )] ],
        );
      
        my @anchorview;
        
        if ($anchor1) {
          my $anchor2 = $self->param('anchor2');
          my $type1   = $self->param('type1');
          my $type2   = $self->param('type2');
        
          push @anchorview, [ $type1, $anchor1 ] if $anchor1 && $type1;
          push @anchorview, [ $type2, $anchor2 ] if $anchor2 && $type2;
        }
        
        # Anchorview allows a URL to specify two features to find a location between.
        # For example: type1=gene;anchor1=BRCA2;type2=marker;anchor2=SHGC-53626
        # which will return the region from the start of the BRCA2 gene to the end of the SHGC-53626 marker.
        # The ordering of the parameters is unimportant, so type1=marker;anchor1=SHGC-53626;type2=gene;anchor2=BRCA2 would return the same location
        if (@anchorview) {
          foreach (@anchorview) {
            my $anchor_location;
            
            ($ftype, $identifier) = @$_;
            
            # Loop through the params mapping until we find the correct function to call.
            # While this may not be the most efficient approach, it is the easiest, since multiple parameters can use the same function
            foreach my $p (@params) {
              my $func = "_location_from_$p->[0]";
              
              # If the type is given as 'all', call every function until a location is found
              foreach (@{$p->[1]}, 'all') {
                if ($_ eq $ftype) {
                  $anchor_location = $self->$func($identifier, $seq_region);
                  last;
                }
              }
              
              last if $anchor_location;
            }
            
            $anchor_location ||= $self->_location_from_SeqRegion($seq_region, $identifier, $identifier); # Lastly, see if the anchor supplied is actually a region parameter
            
            if ($anchor_location) {
              $self->DataObjects($anchor_location);
              $self->clear_problems; # Each function will create a problem if it fails to return a location, so clear them here, now that we definitely have one
            }
          }
          
          $self->merge if $self->DataObjects; # merge the anchor locations to get the right overall location
        } else {
          # Here we are calculating the location based on a feature, for example if the URL query string is just gene=BRAC2
          
          # Loop through the params mapping until we find the correct function to call.
          # While this may not be the most efficient approach, it is the easiest, since multiple parameters can use the same function
          foreach my $p (@params) {
            my $func = "_location_from_$p->[0]";
            
            foreach (@{$p->[1]}) {
              if ($identifier = $self->param($_)) {
                $location = $self->$func($identifier);
                last;
              }
            }
            
            last if $location;
          }
          
          ## If we still haven't managed to find a location (e.g. an incoming link with a bogus URL), throw a warning rather than an ugly runtime error!
          $self->problem('no_location', 'Malformed URL', $self->_help('The URL used to reach this page may be incomplete or out-of-date.')) if $self->hub->type eq 'Location' && $self->hub->action ne 'Genome' && !$location;
        }
      }
    }
  }
  $self->DataObjects($location) if $location;
  return $location;
}

sub get_slice {
  my ($self, $r, $s, $e) = @_;
  my $slice_adaptor = $self->_slice_adaptor;
  my $slice;
  
  if ($r =~ /^LRG/) {
    eval {
      $slice = $slice_adaptor->fetch_by_region('LRG', $r)->feature_Slice->sub_Slice($s, $e);
    };
    
    return $slice;
  }
  
  eval {
    $slice = $slice_adaptor->fetch_by_region('toplevel', $r, $s, $e);
  };
  
  # Checks to see if top-level as "toplevel" above is correct
  return if $slice && !scalar @{$slice->get_all_Attributes('toplevel')||[]};

  if ($slice && ($s < 1 || $e > $slice->seq_region_length)) {
    $s = 1 if $s < 1;
    $s = $slice->seq_region_length if $s > $slice->seq_region_length;
    
    $e = 1 if $e < 1;
    $e = $slice->seq_region_length if $e > $slice->seq_region_length;
    
    $slice = undef;
    
    eval {
      $slice = $slice_adaptor->fetch_by_region('toplevel', $r, $s, $e);
    };
  }
  
  return $slice;
}

sub _location_from_Gene {
  my ($self, $id) = @_;
  
  my @dbs = $self->__gene_databases;
  my $slice;
  
  foreach my $db (@dbs) {
    eval {
      my $gene = $self->_gene_adaptor($db)->fetch_by_stable_id($id);
      $slice   = $self->_slice_adaptor->fetch_by_Feature($gene) if $gene;
    };
    
    if ($slice) {
      $self->param('db', $db);
      return $self->_create_from_slice('Gene', $id, $self->expand($slice));
    }
  }
  
  foreach my $db (@dbs) {
    my $genes = $self->_gene_adaptor($db)->fetch_all_by_external_name($id);
    
    if (@$genes) {
      $slice = $self->_slice_adaptor->fetch_by_Feature($genes->[0]);
      
      if ($slice) {
        $self->param('db', $db);
        return $self->_create_from_slice('Gene', $genes->[0]->stable_id, $self->expand($slice));
      }
    }
  }
  
  $self->problem('fatal', 'Unknown gene', $self->_help("Could not find gene $id"));
  
  return undef;
}

sub _location_from_Transcript {
  my ($self, $id) = @_;
  
  my @dbs = $self->__gene_databases;
  my $slice;
  
  foreach my $db (@dbs) {
    eval {
      my $transcript = $self->_transcript_adaptor($db)->fetch_by_stable_id($id);
      $slice         = $self->_slice_adaptor->fetch_by_Feature($transcript) if $transcript;
    };
    
    if ($slice) {
      $self->param('db', $db);
      return $self->_create_from_slice('Transcript', $id, $self->expand($slice));
    }
  }
  
  foreach my $db (@dbs) {
    my $features = $self->_transcript_adaptor($db)->fetch_all_by_external_name($id);
    
    if (@$features) {
      $slice = $self->_slice_adaptor->fetch_by_Feature($features->[0]);
      
      if ($slice) {
        $self->param('db', $db);
        return $self->_create_from_slice('Transcript', $features->[0]->stable_id, $self->expand($slice));
      }
    }
  }
  
  foreach my $db (@dbs) {
    eval {
      my $transcript = $self->_predtranscript_adaptor($db)->fetch_by_stable_id($id);
      $slice         = $self->_slice_adaptor->fetch_by_Feature($transcript);
    };
    
    if ($slice) {
      $self->param('db', $db);
      return $self->_create_from_slice('Transcript', $id, $self->expand($slice));
    }
  }

  $self->problem('fatal', 'Unknown transcript', $self->_help("Could not find transcript $id"));
  
  return undef;
}

sub _location_from_Exon {
  my ($self, $id) = @_;
  
  my @dbs = $self->__gene_databases;
  my $slice;
  
  foreach my $db (@dbs) {
    eval {
      my $exon = $self->_exon_adaptor($db)->fetch_by_stable_id($id);
      $slice   = $self->_slice_adaptor->fetch_by_Feature($exon) if $exon;
    };
    
    if ($slice) {
      $self->param('db', $db);
      return $self->_create_from_slice('Exon', $id, $self->expand($slice));
    }
  }
  
  $self->problem('fatal', 'Unknown exon', $self->_help("Could not find exon $id"));
  
  return undef;
}

sub _location_from_Peptide {
  my ($self, $id) = @_;
  
  my @dbs = $self->__gene_databases;
  my $slice;
  
  foreach my $db (@dbs) {
    my $peptide;
    
    eval {
      $peptide = $self->_transcript_adaptor($db)->fetch_by_translation_stable_id($id);
      $slice   = $self->_slice_adaptor->fetch_by_Feature($peptide) if $peptide;
    };
    
    if ($slice) {
      $self->param('db', $db);
      return $self->_create_from_slice('Transcript', $peptide->stable_id, $self->expand($slice));
    }
  }
  
  foreach my $db (@dbs) {
    my @features = grep { $_->translation } @{$self->_transcript_adaptor($db)->fetch_all_by_external_name($id)};
    
    if (@features) {
      $slice = $self->_slice_adaptor->fetch_by_Feature($features[0]);
      
      if ($slice) {
        $self->param('db', $db);
        return $self->_create_from_slice( 'Transcript', $features[0]->stable_id, $self->expand($slice));
      }
    }
  }
  
  $self->problem('fatal', 'Unknown peptide', $self->_help("Could not find peptide $id"));
  
  return undef;
}

sub _location_from_MiscFeature {
  my ($self, $id) = @_;
  my $slice;
  
  foreach my $type (qw(name embl_acc synonym clone_name sanger_project well_name clonename)) {
    eval {
      $slice = $self->_slice_adaptor->fetch_by_misc_feature_attribute($type, $id);
    };
    
    return $self->_create_from_slice('MiscFeature', $id, $self->expand($slice)) if $slice;
  }
  
  $self->problem('fatal', 'Unknown misc feature', $self->_help("Could not find misc feature $id"));
  
  return undef;
}

sub _location_from_Band {
  my ($self, $id, $chr) = @_;
  my $slice;
  
  eval {
    $slice = $self->_slice_adaptor->fetch_by_chr_band($chr, $id);
  };
  
  return $self->_create_from_slice('Band', $id, $self->expand($slice)) if $slice;
  
  $self->problem('fatal', 'Unknown band', $self->_help("Could not find karyotype band $id on chromosome $chr"));
  
  return undef;
}

sub _location_from_Variation {
  my ($self, $id, $structural) = @_;
  
  my $adaptor         = $self->_variation_adaptor($structural);
  my $feature_adaptor = $self->_variation_feature_adaptor($structural);
  my $variation;
  
  eval {
    $variation = $adaptor->fetch_by_name($id);
  };
  
  $structural = lc "$structural " if $structural;
  
  if ($@ || !$variation) {
    $self->problem('fatal', "Invalid ${structural}variation id", $self->_help(ucfirst "${structural}variation $id cannot be located within Ensembl"));
    return;
  }
  
  foreach (@{$feature_adaptor->fetch_all_by_Variation($variation)}) {
    if ($_->seq_region_name) {
      my $slice;
      
      eval {
        $slice = $self->_slice_adaptor->fetch_by_region(undef, $_->seq_region_name, $_->seq_region_start, $_->seq_region_end);
      };
      
      return $self->_create_from_slice('Variation', $id, $self->expand($slice)) if $slice;
    }
  }
  
  $self->problem('fatal', "Non-mapped ${structural}variation", $self->_help(ucfirst "${structural}variation $id is in Ensembl, but not mapped to the current assembly"));
  
  return undef;
}

sub _location_from_StructuralVariation { return shift->_location_from_Variation(@_, 'Structural'); }

sub _location_from_Marker {
  my ($self, $id, $chr) = @_;
  
  my $markers;
  
  eval {
    $markers = $self->_marker_adaptor->fetch_all_by_synonym($id);
  };
  
  if ($@) {
    $self->problem('fatal', 'Invalid Marker ID', $self->_help("Marker $id cannot be located within Ensembl"));
    return;
  }
  
  my $region;
  
  foreach my $marker (@$markers) {
    foreach my $mf (@{$marker->get_all_MarkerFeatures || []}) {
      my $slice      = $self->_slice_adaptor->fetch_by_Feature($mf);
      my $projection = $slice->project($self->__level);
      
      next unless @$projection;
      
      my $projslice = shift @$projection;  # take first element of projection
      $region       = $projslice->to_Slice->seq_region_name;
      
      return $self->_create_from_slice('Marker', $mf->display_id, $self->expand($slice)) if $region eq $chr || !$chr;
    }
  }
  
  if ($region) {
    $self->problem('fatal', 'Marker not found on Chromosome', $self->_help("Marker $id is not mapped to chromosome $chr"));
  } else {
    $self->problem('fatal', 'Marker not found on assembly', $self->_help("Marker $id is not mapped to the current assembly"));
  }
  
  return undef;
}

sub _location_from_SeqRegion {
  my ($self, $chr, $start, $end, $strand) = @_;

  if (defined $start) {
    $start    = floor($start);
    $end      = $start unless defined $end;
    $end      = floor($end);
    $end      = 1 if $end < 1;
    $strand ||= 1;
    $start    = 1 if $start < 1; # Truncate slice to start of seq region
    
    ($start, $end) = ($end, $start) if $start > $end;
    
    foreach my $system (@{$self->__coord_systems}) {
      my $slice;
      
      eval {
        $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand);
      };

      warn $@ and next if $@;

      if ($slice) {
        if ($start > $slice->seq_region_length || $end > $slice->seq_region_length) {
          $start = $slice->seq_region_length if $start > $slice->seq_region_length;
          $end   = $slice->seq_region_length if $end   > $slice->seq_region_length;
          
          $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand);
        }
        
        return $self->_create_from_slice($system->name, "$chr $start-$end ($strand)", $slice);
      }
    }
    
    $self->problem('fatal', 'Locate error', $self->_help("Cannot locate region $chr: $start - $end on the current assembly."));
  } else {
    foreach my $system (@{$self->__coord_systems}) {
      my $slice;
      
      eval {
        $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr);
      };
      
      next if $@;
      
      return $self->_create_from_slice($system->name , $chr, $self->expand($slice), $chr) if $slice;
    }
    
    if ($chr) {
      $self->problem('fatal', 'Locate error', $self->_help("Cannot locate region $chr on the current assembly."));
    } elsif ($self->hub->action eq 'Genome' && $self->species_defs->ENSEMBL_CHROMOSOMES) {
      # Create a slice of the first chromosome to force this page to work
      my @chrs  = @{$self->species_defs->ENSEMBL_CHROMOSOMES};
      my $slice = $self->_slice_adaptor->fetch_by_region('chromosome', $chrs[0]) if scalar @chrs;
      
      return $self->_create_from_slice('chromosome', $chrs[0], $self->expand($slice), $chrs[0]) if $slice;
    } else {
      # Might need factoring out if we use other methods to get a location (e.g. marker)
      $self->problem('fatal', 'Please enter a location', $self->_help('A location is required to build this page'));
    }
  }
  
  return undef;
}

sub _create_from_sub_align_slice {
  my ($self, $slice) = @_;
  my $hub         = $self->hub;
  my $session     = $hub->session;
  my $compara_db  = $self->database('compara');
  my $align_slice = $compara_db->get_adaptor('AlignSlice')->fetch_by_Slice_MethodLinkSpeciesSet(
    $slice, 
    $compara_db->get_adaptor('MethodLinkSpeciesSet')->fetch_by_dbID($self->param('align')), 
    'expanded', 
    'restrict'
  );
  
  my ($align_start, $align_end, $species) = ($self->param('align_start'), $self->param('align_end'), $self->species_defs->get_config($self->__species, 'SPECIES_PRODUCTION_NAME'));
  my ($chr, $start, $end);
  
  my $align_slice_length = $align_end - $align_start;
  my $step               = int($align_slice_length/10);
  my $gap                = 0;
  my $expired            = 0;
  my $time_limit         = 10; # Set arbitrary time limit so we don't end up looping for ages. If the limit is hit, the page will display the previous region with a warning message.
  my $time               = time;
  
  while (!($chr && $start && $end) || ($align_end - $align_start < $align_slice_length)) {
    my $sub_align_slices = $align_slice->sub_AlignSlice($align_start, $align_end)->get_all_Slices($species);
    
    foreach (@$sub_align_slices) {
      foreach (@{$_->get_all_underlying_Slices}) {
        $gap = 1, next if $_->seq_region_name eq 'GAP';
        
        $chr ||= $_->seq_region_name;
        $start = $_->start if !$start || $_->start < $start;
        $end   = $_->end   if $_->end > $end;
      }
    }
    
    if (!$start) {
      $align_start -= $step;
      $align_start = 1 if $align_start < 1;
    }
    
    $align_end += $step unless $end;
    
    if (time - $time > $time_limit) {
      $session->set_record_data({
        type     => 'message',
        function => '_warning',
        code     => 'align_slice_failure',
        message  => 'No alignment was found for your selected region'
      });
      
      $expired = 1;
      
      last;
    }
  }
  
  if (!$expired) {
    $start -= $step, $end += $step if $gap;
    $self->param('r', sprintf '%s:%s-%s', $chr, $start, $end);
  }
  
  $hub->problem('redirect', $hub->url($hub->multi_params));
}

sub _create_from_slice {
  my ($self, $type, $id, $slice, $real_chr) = @_;
  
  my $location;
  
  if ($slice) {
    my $projection = $slice->project($self->__level);
    
    if ($projection) {
      my ($projected_slice) = map $_->[2]->is_reference ? $_->[2] : (), @$projection;
      
      $slice = $projected_slice || $projection->[0][2];
      
      my $start  = $slice->start;
      my $end    = $slice->end;
      my $region = $slice->seq_region_name;
      
      if ($slice->seq_region_name ne $real_chr) {
        my $feat = Bio::EnsEMBL::Feature->new(
          -start  => 1, 
          -end    => $slice->length, 
          -strand => 1, 
          -slice  => $slice 
        );
        
        my $altlocs = $feat->get_all_alt_locations(1) || [];
        
        foreach my $f (@$altlocs) {
          if ($f->seq_region_name eq $real_chr) {
            $slice = $f->{'slice'} if $f->seq_region_name;
            last;
          }
        }
      }
        
      $location = $self->new_location($slice, $type);
      
      my $object_types = { %{$self->hub->object_types}, Exon => 'g' }; # Use gene factory to generate tabs when using exon to find location
      
      $self->param($object_types->{$type}, $id) if $object_types->{$type};
    } else {
      $self->problem('fatal', 'Cannot map slice', 'must all be in gaps'); 
    }
  } else {
    $self->problem('fatal', 'Ensembl Error', "Cannot create slice - $type $id does not exist");
  }
  
  return $location;
}

sub new_location {
  my ($self, $slice, $type) = @_;
  
  if ($slice->start > $slice->end && !$slice->is_circular) {
    $self->problem('fatal', 'Invalid location',
      sprintf 'The start position of the location you have entered <strong>(%s:%s-%s)</strong> is greater than the end position.', $slice->seq_region_name, $self->thousandify($slice->start), $self->thousandify($slice->end)
    );
    
    return undef;
  }

  ## Adjust for small genomes (typical of NV) 
  my $start = $slice->start;
  my $end   = $slice->end;
  if ($self->species_defs->EG_DIVISION) {
    $type ||= '';
    if (lc($type) =~ /contig/) {
      my $threshold   = 1000100 * ($self->species_defs->ENSEMBL_GENOME_SIZE||1);
      my $mid =  $start + int(($end - $start)/2);
      $start =  int($mid - ($threshold/2)) > $start ? int($mid - ($threshold/2)) : $start;
      $end   =  int($mid + ($threshold/2)) < $end   ? int($mid + ($threshold/2)) : $end;
    }
  }

  my $location = $self->new_object('Location', {
    type               => 'Location',
    real_species       => $self->__species,
    name               => $slice->seq_region_name,
    seq_region_name    => $slice->seq_region_name,
    seq_region_start   => $start,
    seq_region_end     => $end,
    seq_region_strand  => 1,
    seq_region_type    => $slice->coord_system->name,
    raw_feature_strand => 1,
    seq_region_length  => $slice->seq_region_length
  }, $self->__data);
  
  $location->attach_slice($slice);
  
  return $location;
}

sub merge {
  my $self = shift;
  
  my ($chr, $start, $end, $species, $type, $strand, $srlen);
  
  foreach my $o (@{$self->DataObjects || []}) {
    next unless $o;
    
    $species ||= $o->real_species;
    $chr     ||= $o->seq_region_name;
    $type    ||= $o->seq_region_type;
    $strand  ||= $o->seq_region_strand;
    $start   ||= $o->seq_region_start;
    $end     ||= $o->seq_region_end;
    $srlen   ||= $o->seq_region_length;
    
    return $self->problem('multi_chromosome', 'Not on same seq region', 'Not all features on same seq region') if $chr ne $o->seq_region_name || $species ne $o->species;
    
    $start = $o->seq_region_start if $o->seq_region_start < $start;
    $end   = $o->seq_region_end   if $o->seq_region_end   > $end;
  }
  
  $start -= $self->param('upstream')   || 0;
  $end   += $self->param('downstream') || 0;
  
  $self->clearDataObjects;
  
  $self->DataObjects($self->new_object('Location', {
    type              => 'merge',
    name              => 'merge',
    real_species      => $species,
    seq_region_name   => $chr,
    seq_region_type   => $type,
    seq_region_start  => floor($start),
    seq_region_end    => ceil($end),
    seq_region_strand => $strand,
    highlights        => join('|', $self->param('h'), $self->param('highlights')),
    seq_region_length => $srlen
  }, $self->__data));
}

sub _map_assembly {
  my ($self, $seq_region, $start, $end, $strand) = @_;
  
  my $assembly_name = $self->species_defs->ASSEMBLY_VERSION;
  my $assembly      = $self->param('a');
  
  $self->delete_param('a');
  
  return 0 if uc $assembly_name eq uc $assembly;
  
  ## Check if we have this assembly in the list
  ## Get chromosome:XXXX->chromosome:CURRENT_ASSEMBLY  mappings
  my %mappings = map { reverse(/^chromosome:(.+)#chromosome:(.+)$/) } @{$self->species_defs->ASSEMBLY_MAPPINGS};
  my @mappings = keys %mappings;
  my %params   = map { $_ => $self->param($_) } $self->param;
  my $hub      = $self->hub;
  my $session  = $hub->session;
  
  ## Check if requested assembly is in %mappings
  if (grep uc $_ eq uc $assembly, @mappings) {
    my $old_slice = $self->_slice_adaptor->fetch_by_region(
      'chromosome',
      $seq_region,
      $start, $end, $strand,
      $assembly
    );

    my $segments = $old_slice->project('chromosome', $assembly_name);

    if (scalar @$segments == 1) {
      my $new_slice = $segments->[0]->to_Slice;
      my $r = sprintf '%s:%s-%s', $seq_region, $new_slice->start, $new_slice->end;
      
      $session->set_record_data({
        type     => 'message',
        function => '_info',
        code     => 'new_coordinates',
        message  => "Your request for $seq_region:$start-$end in <b>$assembly</b> has been mapped to the new <b>$assembly_name</b> coordinates $r"
      });
      
      %params = ( %params, r => $r );
    } elsif (@$segments) {
      my $new_slice = $segments->[0]->to_Slice;
      my $new_start = $new_slice->start;
      my $new_end   = $new_slice->end;
      my $prev_end  = 0;
      my $count     = @$segments;
      my $message;
      
      foreach my $segment (@$segments) {
        my $new_slice = $segment->to_Slice;
        $new_start    = $new_slice->start if $new_slice->start < $new_start;
        $new_end      = $new_slice->end   if $new_slice->end   > $new_end;
        
        my %new_params = ( %params, r => "$seq_region:$new_start-$new_end" );
        
        $message .= ($prev_end + 1) . '-'. ($old_slice->start + $segment->from_start - 2) . ' - GAP <br />' if $prev_end && ($old_slice->start + $segment->from_start - $prev_end > 2); 
        $prev_end = $old_slice->start + $segment->from_end - 1;
        
        $message .= sprintf(
          '%s-%s projects to <a href="%s">%s-%s</a><br />',
          $old_slice->start + $segment->from_start - 1,
          $old_slice->start + $segment->from_end - 1,
          $hub->url(\%new_params),
          $new_slice->start,
          $new_slice->end
        );
      }
      if(length($message) > 60000 or @$segments > 400) {
        # Very long messages can't fit in the session db. What use are they
        # to a user anyway.
        $message = "over ".(int(@$segments/100)*100)." segments!";
      }

      $session->set_record_data({
        type     => 'message',
        function => '_info',
        code     => 'several_new_coordinates',
        message  => "Your request for $seq_region:$start-$end in <b>$assembly</b>" .
                    "has been mapped to $count locations within new <b>$assembly_name</b>" .
                    "coordinates $seq_region:$new_start-$new_end <br />" .
                    "<strong>Mapped segments:</strong><br />$message"
      });

      %params = ( %params, r => "$seq_region:$new_start-$new_end" );      
    } else {
        $session->set_record_data({
          type     => 'message',
          function => '_info',
          code     => 'no_mappings_for_assembly',
          message  => "No changes in coordinates of this slice since <b>$assembly</b>",
        });
    }
  } elsif (@mappings) {
    ## Assembly is not recognised among list of possible ones
    ## Put warning message and redirect
    $session->set_record_data({
      type     => 'message',
      function => '_warning',
      code     => 'assembly_not_recognised',
      message  => "Sorry, assembly <b><i>$assembly</i></b> was not recognised, we currently map " . 
                  (scalar @mappings > 1 ?
                    join(' and ', reverse(pop @mappings,  join ', ', @mappings)) . ' assemblies only' :
                    "@mappings assembly only"
                  )
    });
  } else {
    ## We do not have any assemblies to map
    $session->set_record_data({
      type     => 'message',
      function => '_warning',
      code     => 'no_assemblies',
      message  => q{Sorry we currently don't have any other assemblies to map},
    });
  }
  
  return $hub->problem('redirect', $hub->url(\%params));
}

sub _help {
  my ($self, $string) = @_;
  my $hub             = $self->hub;
  my %sample          = %{$self->species_defs->SAMPLE_DATA || {}};
  my $assembly_level  = scalar(@{$self->species_defs->ENSEMBL_CHROMOSOMES || []}) ? 'chromosomal' : 'scaffold';
  my $help_text       = $string ? sprintf '<p>%s</p>', encode_entities($string) : '';
  my $url             = $hub->url({ __clear => 1, action => 'View', r => $sample{'LOCATION_PARAM'} });
  
  $help_text .= sprintf('
    <p>
      A location is required to build this page. For example, %s coordinates:
    </p>
    <div class="left-margin bottom-margin word-wrap">
      <a href="%s">%s</a>
    </div>',
    $assembly_level,
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL . $url)
  );
  
  if (scalar @{$self->species_defs->ENSEMBL_CHROMOSOMES}) {
    my $url = $hub->url({ __clear => 1, action => 'Genome' });
    
    $help_text .= sprintf('
      <p class="space-below">
        You can also browse this genome via its <a href="%s">karyotype</a>
      </p>', 
      encode_entities($url)
    );
  }
  
  return $help_text;
}

1;
