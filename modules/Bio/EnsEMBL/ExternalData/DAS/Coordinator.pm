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

=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::Coordinator

############################################################################
#
# DEPRECATED MODULE - DAS SUPPORT WILL BE REMOVED FROM ENSEMBL IN RELEASE 83
#
#############################################################################

=head1 SYNOPSIS

  # Instantiate with a list of Bio::EnsEMBL::ExternalData::DAS::Source objects:
  my $c = Bio::EnsEMBL::ExternalData::DAS::Coordinator->new(-sources => $list);
  
  # Fetch by slice
  my $struct = $c->fetch_Features( $slice );
  
  for my $logic_name ( keys %{ $struct } ) {
    
    # Bio::EnsEMBL::ExternalData::DAS::Source object:
    my $source = $struct->{$logic_name}{'source'}{'object'};
    my $error  = $struct->{$logic_name}{'source'}{'error'};
    
    # Bio::EnsEMBL::ExternalData::DAS::Stylesheet object:
    my $stylesheet = $struct->{$logic_name}{'stylesheet'}{'object'};
    my $s_error    = $struct->{$logic_name}{'stylesheet'}{'error'};
    
    for my $segment ( keys %{ $struct->{$logic_name}{'features'} } ) {
      
      my $f_url    = $struct->{$logic_name}{'features'}{$segment}{'url'};
      my $f_error  = $struct->{$logic_name}{'features'}{$segment}{'error'};
      # arrayref of Bio::EnsEMBL::ExternalData::DAS::Feature objects:
      my $features = $struct->{$logic_name}{'features'}{$segment}{'objects'};
      
    }
    
  }
  
  # Fetch by gene
  my $struct = $c->fetch_Features( $gene );
  
  # Fetch by protein
  my $struct = $c->fetch_Features( $translation );
  
  # Feature ID filtering
  my $struct = $c->fetch_Features( $slice, feature => 'xyz1234' );
  
  # Type ID and Group ID filtering
  my $struct = $c->fetch_Features( $slice, group => 'xyz', type => 'foo' );

=head1 DESCRIPTION

Given a set of DAS::Source objects and a target object such as a Slice or
Translation, will simultaneously perform all DAS requests and map the features
onto the target object.

=cut
package Bio::EnsEMBL::ExternalData::DAS::Coordinator;

use strict;
use warnings;
no warnings 'uninitialized';

use POSIX qw(ceil);
use Bio::EnsEMBL::Mapper;
use Bio::Das::Lite;

use Bio::EnsEMBL::ExternalData::DAS::CoordSystem;
use Bio::EnsEMBL::ExternalData::DAS::GenomicMapper;
use Bio::EnsEMBL::ExternalData::DAS::XrefPeptideMapper;
use Bio::EnsEMBL::ExternalData::DAS::GenomicPeptideMapper;
use Bio::EnsEMBL::ExternalData::DAS::Feature;
use Bio::EnsEMBL::ExternalData::DAS::Stylesheet;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser qw(%SNP_COORDS %GENE_COORDS %PROT_COORDS is_genomic);
use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw info warning);
use Bio::EnsEMBL::Registry;

our %ORI_NUMERIC = (
   1    =>  1,
  '+'   =>  1,
  -1    => -1,
  '-'   => -1,
   0    =>  0,
  '.'   =>  0,
);

# This variable determines the supported xref mapping paths.
# The first level key is the xref coordinate system.
# The first level value is a hashref, containing:
#   'predicate':   a code block to filter xref's of the relevant type
#   'transformer': a code block to obtain the DAS segment ID
#
our %XREF_PEPTIDE_FILTERS = (
  'uniprot_peptide' => {
    'predicate'   => sub { $_[0]->dbname eq 'Uniprot/SPTREMBL' || $_[0]->dbname eq 'Uniprot/SWISSPROT' },
    'transformer' => sub { $_[0]->primary_id },
  },
  'ipi_acc' => {
    'predicate'   => sub { $_[0]->dbname eq 'IPI' },
    'transformer' => sub { $_[0]->primary_id },
  },
  'ipi' => {
    'predicate'   => sub { $_[0]->dbname eq 'IPI' },
    'transformer' => sub { $_[0]->display_id },
  },
  'entrezgene_acc' => {
    'predicate'   => sub { $_[0]->dbname eq 'EntrezGene' },
    'transformer' => sub { $_[0]->primary_id },
  },
);

our %XREF_GENE_FILTERS = (
  'hgnc' => {
    'predicate'   => sub { $_[0]->dbname eq 'HGNC' },
    'transformer' => sub { $_[0]->primary_id },
  },
  'mgi_acc' => {
    'predicate'   => sub { $_[0]->dbname eq 'MGI' },
    'transformer' => sub { my $id = $_[0]->primary_id; $id =~ s/\://; $id; },
  },
  'mgi' => {
    'predicate'   => sub { $_[0]->dbname eq 'MGI' },
    'transformer' => sub { $_[0]->display_id },
  },
  'flybase_gene' => {
    'predicate'   => sub { $_[0]->dbname eq 'FlyBaseName_gene' },
    'transformer' => sub { $_[0]->display_id },
  },
  'wormbase_gene' => {
    'predicate'   => sub { $_[0]->dbname eq 'wormbase_gene' },
    'transformer' => sub { $_[0]->primary_id },
  },
  'vectorbase_gene' => {
    'predicate'   => sub { $_[0]->dbname eq 'VB_Community_Annotation' },
    'transformer' => sub { $_[0]->display_id },
  },
  'gramene_gene' => {
    'predicate'   => sub { $_[0]->dbname eq 'Gramene_GenesDB' },
    'transformer' => sub { $_[0]->display_id },
  }, 
  'ena_gene' => {
    'predicate'   => sub { $_[0]->dbname eq 'ENA_GENE' },
    'transformer' => sub { $_[0]->display_id },
  }, 
  'dictybase_gene' => {
    'predicate'   => sub { $_[0]->dbname eq 'DictyBase' },
    'transformer' => sub { $_[0]->display_id },
  }, 
  'pubmed_id' => {
    'predicate'   => sub { $_[0]->dbname eq 'PUBMED' },
    'transformer' => sub { $_[0]->primary_id },
  }, 
);

=head2 new

  Arg [..]   : List of named arguments:
               -SOURCES     - Arrayref of Bio::EnsEMBL::DAS::Source objects.
               -PROXY       - A URL to use as an HTTP proxy server
               -NOPROXY     - A list of domains/hosts to not use the proxy for
               -TIMEOUT     - The request timeout, in seconds
               -GENE_COORDS - Override the coordinate system representing genes
               -PROT_COORDS - Override the coordinate system representing proteins
               -SNP_COORDS  - Override the coordinate system representing variations
  Description: Constructor
  Returntype : Bio::EnsEMBL::DAS::Coordinator
  Exceptions : If unable to assign the gene and protein coordinate systems
  Caller     : 
  Status     : 

=cut
sub new {
  my $class = shift;
  
  my ($sources, $proxy, $no_proxy, $timeout, $gene_cs, $prot_cs, $snp_cs)
    = rearrange(['SOURCES','PROXY', 'NOPROXY', 'TIMEOUT',
                 'GENE_COORDS', 'PROT_COORDS', 'SNP_COORDS'], @_);
  
  $sources = [$sources] if ($sources && !ref $sources);
  
  my $das = Bio::Das::Lite->new();
  $das->user_agent('Ensembl/' . Bio::EnsEMBL::Registry->software_version);
  $das->timeout($timeout);
  $das->caching(0);
  $das->http_proxy($proxy);
  
  # Bio::Das::Lite support for no_proxy added around September 2008
  if ($no_proxy) {
    if ($das->can('no_proxy')) {
      $das->no_proxy($no_proxy);
    } else {
      warning("Installed version of Bio::Das::Lite does not support use of 'no_proxy'");
    }
  }
  
  $gene_cs ||= $GENE_COORDS{'ensembl_gene'}
    || throw('Unable to determine Gene coordinate system');
  $prot_cs ||= $PROT_COORDS{'ensembl_peptide'}
    || throw('Unable to determine Peptide coordinate system');
  $snp_cs ||= $SNP_COORDS{'dbsnp_rsid'}
    || throw('Unable to determine Variation coordinate system');
  
  my $self = {
    'sources' => $sources,
    'daslite' => $das,
    'gene_cs' => $gene_cs,
    'prot_cs' => $prot_cs,
    'snp_cs' => $snp_cs,
    'objects' => {},
  };
  bless $self, $class;
  return $self;
}

=head2 fetch_Features

  Arg [1]    : Bio::EnsEMBL::Object $root_obj - the query object (e.g. Slice, Gene)
  Arg [2]    : (optional) hash of filters:
                  maxbins - the maximum available "rendering space" for features
                            NOTE this is only passed to the server, it is not
                                 guaranteed to be honoured
                  feature - the feature ID
                  type    - the type ID
                  group   - the group ID
  Description: Fetches DAS features  for a given Slice, Gene, Translation or Variation
  Example    : $hashref = $c->fetch_Features( $slice, type => 'mytype' );
  Returntype : A hash reference containing Bio::...::DAS::Feature and
               Bio::...::DAS::Stylesheet objects:
               {
                $logic_name => {
                  'source'     => {
                                   'object' => $source_object,
                                   'error'  => 'No data for region',
                                  },
                  'features'   => {
                                   'X:1000,2000' => {
                                     'error'   => 'Error fetching...',
                                     'url'     => 'http://...',
                                     'objects' => [  $feat1, $feat2 ],
                                     },
                                  },
                  'stylesheet' => {
                                   'object' => $style1,
                                   'error'  => 'Error fetching...',
                                  },
                               }
               }
  Exceptions : Throws if the object is not supported
  Caller     : 
  Status     : 

=cut
sub fetch_Features {
  my ( $self, $target_obj ) = splice @_, 0, 2;
  my %filters = @_; # maxbins, feature, type, group
  
  # TODO: review this structure that is returned, would we prefer to split by
  # segment ID? We don't always know it before we parse the feature though (e.g.
  # when querying by feat ID). Also stylesheet errors aren't segment-specific
  
  my ( $target_cs, $target_segment, $slice, $gene, $prot, $snp );
  if ( $target_obj->isa('Bio::EnsEMBL::Gene') ) {
    $slice = $target_obj->slice;
    $gene = $target_obj;
    $target_cs = $slice->coord_system; # actually want features relative to the slice
    $target_segment = $target_obj->stable_id;
  } elsif ( $target_obj->isa('Bio::EnsEMBL::Slice') ) {
    $slice = $target_obj;
    $target_cs = $target_obj->coord_system;
    $target_segment = sprintf '%s:%s,%s', $target_obj->seq_region_name, $target_obj->start, $target_obj->end;
  } elsif ( $target_obj->isa('Bio::EnsEMBL::Translation') ) {
    $prot = $target_obj;
    $target_cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'ensembl_peptide' );
    $target_segment = $target_obj->stable_id;
  } elsif ( $target_obj->isa('Bio::EnsEMBL::Variation::Variation') ) {
    $snp = $target_obj;
    $target_cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -name => 'dbsnp_rsid' );
    $target_segment = $target_obj->name;

  } else {
    throw('Unsupported object type: '.$target_obj);
  }
  my $target_species = $target_obj->adaptor->db->species;
  
  my %coords = ();
  my $final  = {};
  my %sources_with_data = ();
  
  #==========================================================#
  #      First sort the sources into coordinate systems      #
  #==========================================================#
  
  for my $source (@{ $self->{'sources'} }) {
    
    # Set up the data structure...
    $final->{$source->logic_name} = {
                                     'source'     => {
                                                      'object' => $source,
                                                     },
                                     'features'   => {},
                                     'stylesheet' => {},
                                    };
    
    my @coord_systems = @{ $self->_choose_coord_systems($target_cs, $target_obj, $source->coord_systems) };
    
    if (! scalar @coord_systems ) {
      warning($source->logic_name.' has no coord systems');
      $final->{$source->logic_name}{'source'}{'error'}
        = 'Bad source configuration';
      next;
    }
    
    # Check the coordinate system is the correct species (if it has one)
    @coord_systems = grep {
      $_->matches_species( $target_species )
    } @coord_systems;
    
    if (! scalar @coord_systems ) {
      $final->{$source->logic_name}{'source'}{'error'}
        = "Source not compatible with $target_species";
    }
    
    # Query in all compatible coordinate systems
    for my $source_cs ( @coord_systems ) {
      
      # The coordinate system name doesn't need species in it because we have
      # just checked it is species-compatible - we treat them the same from now
      # on. That is, Ensembl,Gene_ID == Ensembl,Gene_ID,Homo sapiens.
      my $cs_key = $source_cs->name . ' ' . $source_cs->version;
      
      # Sort sources by coordinate system
      if ( !$coords{$cs_key} ) {
        # Do a lot of funky stuff to get the query segments, and build up
        # mappers at the same time
        my ($segments, $error) = $self->_get_Segments( $source_cs, $target_cs,
                                                       $slice, $gene, $prot, $snp );
        
        $coords{ $cs_key } = { 'sources'      => {},
                               'coord_system' => $source_cs,
                               'error'        => $error,
                               'segments'     => $segments   };
      }
      
      $coords{ $cs_key }{'sources'}{$source->full_url} ||= [];
      push @{ $coords{ $cs_key }{'sources'}{$source->full_url} }, $source;
    }
  }
  
  #==========================================================#
  #   Parallelise the requests for each coordinate system    #
  #==========================================================#
  
  my $daslite = $self->{'daslite'};
  
  # Split the requests by coordinate system, i.e. parallelise
  # requests for segments that are from the same coordinate system
  while (my ($coord_key, $coord_data) = each %coords) {
    my @segments   = map { scalar @{$_} > 1 ? sprintf '%s:%d,%d', @{$_} : $_->[0]; } @{ $coord_data->{'segments'} };
    my @urls       = keys %{ $coord_data->{'sources'} };
    my $source_cs  = $coord_data->{'coord_system'};
    my $error      = $coord_data->{'error'};
    my $coord_name = $source_cs->name . ' ' . $source_cs->version;
    
    # Either the mapping isn't supported, or nothing maps to the region we're
    # interested in.
    if ( $error || ! scalar @segments ) {
      info("No segments found for $coord_name");
      for ( values %{ $coord_data->{'sources'} } ) {
        for my $source (@{ $_ }) {
          $final->{$source->logic_name}{'source'}{'error'} = $error || 'No data for region';
        }
      }
      next;
    }
    
    info("Querying with @segments for $coord_name");
    $daslite->dsn( \@urls );
    
    my $response;
    my $statuses;
    
    my $maxbins = $source_cs->equals( $target_cs ) ? $filters{maxbins} : undef;
    
    #==========================================================#
    #             Get features for all DAS sources             #
    #==========================================================#
    
=head
    ########
    # If we are looking for a specific feature, try quering the server(s) for
    # it specifically first
    #
    if ( $filters{feature} ) {
      $response = $daslite->features( { 'feature_id' => $filters{feature} } ); # returns a hashref
      $statuses = $daslite->statuscodes();
      
      # Find out if it worked (has to work for EVERY source)
      while (my ($url, $features) = each %{ $response }) {
        my $status = $statuses->{$url};
        if ($status !~ m/^200/) {
          undef $response;
          last;
        } elsif (!defined $features || ref $features ne 'ARRAY' || !scalar @{ $features }) {
          undef $response;
          last;
        }
      }
    }
=cut
    
    ########
    # If this didn't work, or we are running a normal query, use the segments
    #
    if ( !$response ) {
      # Build a query array for each segment, with the optional filter
      # parameters. Note that not all DAS servers implement these filters. If
      # they do, great, but we still have to filter on the client side later.
      my @features_query = map {
        {
         'segment'    => $_,
         'type'       => $filters{type},
         'feature_id' => $filters{feature},
         'group_id'   => $filters{group},
         'maxbins'    => $maxbins,
        }
      } @segments;
      
      $response = $daslite->features( \@features_query ); # returns a hashref
      $statuses = $daslite->statuscodes();
    }
    
    #========================================================#
    #               Check and map the features               #
    #========================================================#
    my $feature_ids = {};
    while (my ($raw_url, $features) = each %{ $response }) {
      # Now iterating over coordsys + url
      my $status = $statuses->{$raw_url};
      # Parse the segment from the URL
      # Should be one URL for each source/query combination
      my ($url, $segment) = $raw_url =~ m|(.+)/features\?.*segment=([^;&]+)|;
      info("*** $url $segment ***");
      my @sources = @{ $coord_data->{'sources'}{$url} };
      
      for my $source ( @sources ) {
        $final->{$source->logic_name}{'features'}{$segment} = {
          'url'          => $raw_url,
          'coord_system' => $source_cs,
          'objects'      => [],
        }
      }
      
      # DAS source generated an error
      if ($status !~ m/^200/) {
        for my $source ( @sources ) {
          $final->{$source->logic_name}{'features'}{$segment}{'error'}
            = "Error fetching features - $status";
        }
      }
      
      # We got some features in the region of interest
      elsif ($features && ref $features eq 'ARRAY' && scalar @{ $features }) {
        ########
        # Convert into the query coordinate system if applicable
        #
        $features = $self->map_Features($features,
                                        $source_cs,
                                        $target_cs,
                                        $slice,
                                        $feature_ids->{$url},
                                        %filters);
        
        # We got something useful
        if (scalar @{ $features }) {
          for my $source ( @sources ) {
            # Store features:
            $final->{$source->logic_name}{'features'}{$segment}{'objects'}
              = $features;
            # For retrieving stylesheets:
            $sources_with_data{$url}{$source->logic_name} = $source;
          }
        }
        # Either we couldn't map the features, or nothing matched the filters
        else {
          for my $source ( @sources ) {
            $final->{$source->logic_name}{'features'}{$segment}{'error'}
              = 'No relevant features';
          }
        }
        
      }
      
    }
    
  }
  
  #==========================================================#
  #         Get stylesheets for the sources with data        #
  #==========================================================#
  
  $daslite->dsn( [ keys %sources_with_data ] );
  my $response = $daslite->stylesheet();
  my $statuses = $daslite->statuscodes();
  
  while (my ($url, $styledata) = each %{ $response }) {
    
    my $status = $statuses->{$url};
    $url =~ s|/stylesheet\??$||;
    my @sources = values %{ $sources_with_data{$url} };
    
    # DAS source generated an error
    if ( $status !~ m/^200/ ) {
      for my $source ( @sources ) {
        $final->{$source->logic_name}{'stylesheet'}{'error'}
          = "Error fetching stylesheet - $status";
      }
    }
    # DAS source has stylesheet data
    elsif ($styledata && ref $styledata eq 'ARRAY' && scalar @{ $styledata }) {
      # Build stylesheet object:
      my $stylesheet = Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new(
        $styledata->[0]
      );
      for my $source ( @sources ) {
        $final->{$source->logic_name}{'stylesheet'}{'object'} = $stylesheet;
      }
    }
  }
  
  return $final;
}

# Returns: new arrayref with features
sub map_Features {
  my ( $self, $features, $source_cs, $to_cs, $slice, $feature_ids ) = splice @_, 0, 6;
  my %filters = @_; # feature, type, group
  
  # TODO: implement maxbins filter??
  my $filter_f = $filters{feature};
  my $filter_t = $filters{type};
  my $filter_g = $filters{group};
  # If filtering we're more likely to have a small region, so it's better to
  # make 4 tests when filtering and 1 when not than always make 3 tests.
  # The big question is, is it better to test each filter is enabled than to
  # just preprocess in an extra iteration? I suspect the former.
  my $nofilter = !$filter_f && !$filter_t && !$filter_g;
  
  # Code block to build a feature object from raw hash
  my $build_Feature = sub {
    my $f = shift;
    $f = Bio::EnsEMBL::ExternalData::DAS::Feature->new( $f );
    # Where target coordsys is genomic, make a slice-relative feature
    if ($slice) {
      $f->slice($slice->seq_region_Slice);
      $f = $f->transfer($slice);
    } else {
      $f->seqname( $f->{'segment_id'} );
    }
    return $f;
  };
  
  # Code block to apply optional filters
  my $filter_Feature = sub {
    my $f = shift;
    # Test type first, because this is the more likely filter for large regions
    # where efficiency matters most
    if ( $filter_t ) {
      $f->{'type_id'} eq $filter_t || return 0;
    }
    if ( $filter_f ) {
      $f->{'feature_id'} eq $filter_f || return 0;
    }
    if ( $filter_g ) {
      return 0 unless grep { $_->{'group_id'} eq $filter_g } @{ $f->{'group'}||[] };
    }
    return 1;
  };
  
  my @new_features = ();
  
  # As part of the feature parsing we need to do some converting and filtering.
  # We could do this in a separate loop before doing any mapping, but this adds
  # an extra iteration step which is inefficient (especially for large numbers
  # of features). So we duplicate a bit of code.
  
  if ( $source_cs->equals( $to_cs ) || ( $slice && $source_cs->name eq 'toplevel' && $slice->is_toplevel ) ) {
    
    for my $f ( @{ $features } ) {
      if (exists $feature_ids->{ $f->{'feature_id'} }) {
        next;
      }
      $feature_ids->{ $f->{'feature_id'} } = 1;
      if ( $nofilter || &$filter_Feature( $f ) ) {
        $f->{'strand'} = $ORI_NUMERIC{$f->{'orientation'} || '.'} || 0; # Convert to Ensembl-style (numeric) strand
        push @new_features, &$build_Feature( $f ); # Build object
      }
    }
    
    return \@new_features;
  }
  
  my $first_iteration = 1;
  
  # May need multiple mapping steps to reach the target coordinate system
  # This loop works by setting $source_cs to the coordinate system we have
  # mapped to in each iteration, and continuing to iterate until it matches
  # the target coordinate system. On the last iteration we create a solid
  # object for each feature.
  while ( $source_cs && !$source_cs->equals($to_cs) ) {
    
    my @this_features = @{ $features };
    
    info('Beginning mapping '.scalar @this_features.' features from '.$source_cs->name);
    
    my $mappers = $self->{'mappers'}{$source_cs->name}{$source_cs->version||''};
    my $passthrough = $self->{'passthrough'}{$source_cs->name}{$source_cs->version||''};
    $features  = [];
    my $this_cs = undef;
    
    my $positional_mapping_errors = 0;
    
    # Map the current set of features to the next coordinate system
    for my $f ( @this_features ) {
      
      my $strand = $f->{'strand'};
      
      # It doesn't matter what coordinate system non-positional features come
      # from, they are always included and don't need mapping
      if (!$f->{'start'} && !$f->{'end'}) {
        push @new_features, &$build_Feature( $f );
        next;
      }
      # For the first iteration we have features that are fresh from the DAS
      # server. We need to do some filtering, and to only do it once.
      if ($first_iteration) {
        if (exists $feature_ids->{ $f->{'feature_id'} }) {
          next;
        }
        $feature_ids->{ $f->{'feature_id'} } = 1;
        $nofilter || &$filter_Feature( $f ) || next;
        
        # Convert DAS-style strand to Ensembl-style
        $strand = $f->{'strand'} = $ORI_NUMERIC{$f->{'orientation'} || '.'} || 0;
      }
      
      my $segid  = $f->{'segment_id'};
      
      # Check for passthrough mappings (i.e. no mapping is needed but the coord system needs to change)
      # This is used when mapping from toplevel
      if (my $pass_cs = $passthrough->{$segid}) {
        $this_cs = $pass_cs;
        # If this is the final step, convert to Ensembl Feature
        if ( $this_cs->equals( $to_cs ) ) {
          push @new_features, &$build_Feature( $f );
        }
        else {
          push @{ $features }, $f;
        }
        next;
      }
      
      # Otherwise check there are mappings available for this segment
      my $mapper = $mappers->{$segid};
      if (!$mapper) {
        $positional_mapping_errors++;
        next;
      }
      $this_cs = $mapper->{'to_cs'} || throw('Mapper maps to unknown coordinate system');
      
      # Get new coordinates for this feature
      my @coords = $mapper->map_coordinates($segid,
                                            $f->{'start'},
                                            $f->{'end'},
                                            $strand,
                                            'from');
      
      # Create new features from the mapped coordinates
      for my $c ( @coords ) {
        $c->isa('Bio::EnsEMBL::Mapper::Coordinate') || next;
        my %new = %{ $f };
        $new{'segment_id'} = $c->id;
        $new{'start'     } = $c->start;
        $new{'end'       } = $c->end;
        $new{'strand'    } = $c->strand;
        
        # If this is the final step, convert to Ensembl Feature
        if ( $this_cs->equals( $to_cs ) ) {
          push @new_features, &$build_Feature( \%new );
        }
        else {
          push @{ $features }, \%new;
        }
      }
      
    }
    
    if ($positional_mapping_errors) {
      warning(sprintf '%d positional features could not be mapped (%s -> %s)',
        $positional_mapping_errors,
        $source_cs ? $source_cs->name.' '.$source_cs->version : 'UNKNOWN',
        $this_cs   ? $this_cs->name  .' '.$this_cs->version   : 'UNKNOWN'
      );
    }
    
    $source_cs = $this_cs;
    $first_iteration = 0;
  }
  
  return \@new_features;
}

# Supports mappings:
#   location-based to location-based
#   location-based to protein-based
#   protein-based to location-based
#   protein-based to protein-based
#   gene-based to location-based
#   gene-based to protein-based
#   xref-based to location-based
#   xref-based to protein-based
#   xref-based to gene-based
#   variation-based to variation-based
#
# Coordinate system definitions:
#   location-based  == chromosome|clone|contig|scaffold|supercontig etc
#   protein-based   == $self->{prot_cs} (ensembl_peptide)
#   gene-based      == $self->{gene_cs} (ensembl_gene)
#   variation-based      == $self->{snp_cs} (dbsnp_rsid)
#   xref-based      == uniprot_peptide|entrez_gene... (see %XREF_PEPTIDE_FILTERS)
sub _get_Segments {
  my $self = shift;
  my $from_cs = shift; # the "foreign" source coordinate system 
  my $to_cs = shift;   # the target coordsys that mapped objects will be converted to
  my ($slice, $gene, $prot, $snp) = @_;
  #warn sprintf "Getting mapper for %s -> %s", $from_cs->name, $to_cs->name;
  
  info (sprintf 'Building mappings for %s %s -> %s %s',
               $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);
  my @segments = ();
  my $problem;
  
  # There are several different Mapper implementations in the API to convert
  # between various coordinate systems: AssemblyMapper, TranscriptMapper,
  # IdentityXref. For DAS, we often need to convert across the different realms
  # these mappers serve, such as chromosome:NCBI35 -> peptide which requires an
  # intermediary NCBI35 -> NCBI36 step. Unfortunately, the different mappers all
  # work in different ways and have different interfaces and limitations.
  #
  # For example, AssemblyMapper and TranscriptMapper use custom methods rather
  # than the standard API 'map_coordinates', IdentityXref uses custom
  # 'external_id' and 'ensembl_id' identifiers for the regions it is mapping
  # between, and all name the coordinate systems differently. These differences
  # mean the different mappers cannot be strung together, so this module uses
  # wrappers in order to achieve this.
  
  # Mapping to slice-relative coordinates
  if ( is_genomic($to_cs) ) {
    
    # Sanity checks
    $slice || throw('Trying to convert to slice coordinates, but no Slice provided');
    $slice->coord_system->equals($to_cs) || throw('Provided slice is not in target coordinate system');
    
    # Mapping from a slice-based coordinate system
    if ( is_genomic($from_cs) || $from_cs->name eq 'toplevel' ) {
      
      # No mapping needed - the coords are identical
      if ( $from_cs->equals( $to_cs ) ) {
        info(sprintf 'No mappings needed for %s %s -> %s %s',
          $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);
        push @segments, [ $slice->seq_region_name, $slice->start, $slice->end ];
      }
      # No mapping needed, but we need to indicate what the real coordsys is
      elsif ( $from_cs->name eq 'toplevel' && $slice->is_toplevel ) {
        info(sprintf 'No mappings needed for %s %s -> %s %s',
          $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);
        $self->{'passthrough'}{$from_cs->name}{$from_cs->version}{$slice->seq_region_name} = $to_cs;
        push @segments, [ $slice->seq_region_name, $slice->start, $slice->end ];
      }
      
      # We can't map from toplevel, only detect when no mapping is required...
      elsif ( $from_cs->name eq 'toplevel' ) {
        warning($problem = sprintf 'Mapping from toplevel to %s is not supported for this region', $to_cs->name);
      }
      
      # Standard genomic->genomic mapping
      else {
        # AssemblyMapperAdaptor doesn't like DAS::CoordSystem, so we need the Ensembl versions
        # And sometimes DAS coordinate systems have versions when Ensembl coordinates don't, so we need to look for these
        my $csa = $slice->adaptor->db->get_CoordSystemAdaptor;
        my $ama = $slice->adaptor->db->get_AssemblyMapperAdaptor;
        my $tmpfrom = $csa->fetch_by_name( $from_cs->name, $from_cs->version ) || $csa->fetch_by_name( $from_cs->name );
        my $tmpto   = $csa->fetch_by_name( $to_cs->name,   $to_cs->version   ) || $csa->fetch_by_name( $to_cs->name   );
        
        # NOTE we need to be careful that we don't pull back an entirely different version.
        # This check is necessary because CoordSystemAdaptor assumes a blank version means "default version".
        if ( !$tmpfrom || ($tmpfrom->version && $tmpfrom->version ne $from_cs->version) ) {
          warning($problem = sprintf 'Mapping from %s %s is not supported', $from_cs->name, $from_cs->version);
        }
        elsif ( !$tmpto || ($tmpto->version && $tmpto->version ne $to_cs->version) ) {
          warning($problem = sprintf 'Mapping to %s %s is not supported', $to_cs->name, $to_cs->version);
        }
        # Ensembl might not support a specific genomic -> genomic mapping
        elsif ( my $tmpmap = $ama->fetch_by_CoordSystems($tmpfrom, $tmpto) ) {
          
          # Wrapper for AssemblyMapper:
          my $mapper = Bio::EnsEMBL::ExternalData::DAS::GenomicMapper->new(
            'from', 'to', $tmpfrom, $tmpto, $tmpmap
          );
          
          # Map backwards to get the query segments
          my @coords = $mapper->map_coordinates($slice->seq_region_name,
                                                $slice->start,
                                                $slice->end,
                                                $slice->strand,
                                                'to');
          
          info(sprintf 'Adding mappings for %s %s -> %s %s',
            $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);
          for my $c ( @coords ) {
            $c->isa('Bio::EnsEMBL::Mapper::Coordinate') || next;
            $self->{'mappers'}{$from_cs->name}{$from_cs->version}{$c->id} ||= $mapper;
            push @segments, [ $c->id, $c->start, $c->end ];
          }
          
        } else {
          warning($problem = sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
        }
      }
    }
    
    # Mapping from ensembl_gene to slice
    elsif ( $from_cs->equals( $self->{'gene_cs'} ) ) {
      
      my @genes = $gene ? ($gene)
                        : @{ $slice->get_all_Genes };
      
      info(sprintf 'Adding mappings for %s %s -> %s %s',
        $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);
      for my $g ( @genes ) {
        # Genes are already definitely relative to the target slice, so don't need to do any assembly mapping
        my $mapper = Bio::EnsEMBL::Mapper->new('from', 'to', $from_cs, $to_cs);
        $mapper->add_map_coordinates(
          $g->stable_id,           1,                    $g->length, $g->seq_region_strand,
          $slice->seq_region_name, $g->seq_region_start, $g->seq_region_end
        );
        $self->{'mappers'}{$from_cs->name}{$from_cs->version}{$g->stable_id} = $mapper;
        push @segments, [ $g->stable_id ];
      }
    }    
    # Mapping from ensembl_peptide to slice
    elsif ( $from_cs->equals( $self->{'prot_cs'} ) ) {
      
      my @transcripts = $gene ? @{ $gene->get_all_Transcripts }
                              : @{ $slice->get_all_Transcripts };
      
      info(sprintf 'Adding mappings for %s %s -> %s %s',
        $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);
      for my $tran ( @transcripts ) {
        my $p = $tran->translation || next;
        $self->{'mappers'}{$from_cs->name}{$from_cs->version}{$p->stable_id} ||= Bio::EnsEMBL::ExternalData::DAS::GenomicPeptideMapper->new('from', 'to', $from_cs, $to_cs, $tran);
        push @segments, [ $p->stable_id ];
      }
    }
    
    # Mapping from translation-mapped xref to slice
    elsif ( my $callback = $XREF_PEPTIDE_FILTERS{$from_cs->name} ) {
      # Mapping path is xref -> ensembl_peptide -> slice
      my $mid_cs = $self->{'prot_cs'};
      
      my @transcripts = $gene ? @{ $gene->get_all_Transcripts }
                              : @{ $slice->get_all_Transcripts };
      
      for my $tran ( @transcripts ) {
        my $p = $tran->translation || next;
        # first stage mapper: xref to translation
        my ($segs, $err) = $self->_get_Segments($from_cs, $mid_cs, $slice, $gene, $p);
        push @segments, @{ $segs };
        $problem ||= $err;
      }
      # If the first stage actually produced mappings, we'll need to map from
      # peptide to slice
      if ($self->{'mappers'}{$from_cs->name}{$from_cs->version}) {
        # second stage mapper: gene or translation to transcript's slice
        my (undef, $problem2) = $self->_get_Segments($mid_cs, $to_cs, $slice, $gene, $prot);
        $problem ||= $problem2;
      }
      
      # Apply an error message that refers to the start and end coordinates
      if ($problem) {
        warning($problem = sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
      }
    }
    
    # Mapping from gene-mapped xref to slice
    elsif ( $callback = $XREF_GENE_FILTERS{$from_cs->name} ) {
      
      my @genes = $gene ? ($gene)
                        : @{ $slice->get_all_Genes };
      
      info(sprintf 'Adding (nonpositional) mappings for %s %s -> %s %s',
        $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);
      for my $g ( @genes ) {
        for my $xref (grep { $callback->{'predicate'}($_) } @{ $g->get_all_DBEntries() }) {
          my $segid = $callback->{'transformer'}( $xref );
          push @segments, [ $segid ];
        }
        # Gene-based xrefs don't have alignments and so don't generate mappings.
        # It is enough to simply collate the segment ID's; only non-positional
        # features will mapped.
      }
    }
    
    else {
      warning($problem = sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
    }
  } # end mapping to slice/gene
  
  # Mapping to peptide-relative coordinates
  elsif ( $to_cs->equals( $self->{'prot_cs'} ) ) {
    
    $prot || throw('Trying to convert to peptide coordinates, but no Translation provided');
    
    # Mapping from protein to protein (the same)
    if ( $from_cs->equals( $to_cs ) ) {
      # no mapper needed
      info(sprintf 'No mappings needed for %s %s -> %s %s',
        $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);
      $self->{'passthrough'}{$from_cs->name}{$from_cs->version}{$prot->stable_id} = $to_cs;
      push @segments, [ $prot->stable_id ];
    }
    
    # Mapping from slice. Note that from_cs isnt necessarily the same as the transcript's coord_system
    elsif ( is_genomic($from_cs) || $from_cs->name eq 'toplevel' ) {
      my $ta    = $prot->adaptor->db->get_TranscriptAdaptor();
      my $sa    = $prot->adaptor->db->get_SliceAdaptor();
      my $tran  = $ta->fetch_by_translation_stable_id($prot->stable_id);
      $slice = $sa->fetch_by_transcript_stable_id($tran->stable_id);
      $tran = $tran->transfer($slice);
      my $tran_cs = $slice->coord_system;
      # second stage mapper: transcript's slice to protein
      my $mapper = Bio::EnsEMBL::ExternalData::DAS::GenomicPeptideMapper->new('from', 'to', $tran_cs, $to_cs, $tran);
      
      info(sprintf 'Adding mappings for %s %s -> %s %s',
        $tran_cs->name, $tran_cs->version, $to_cs->name, $to_cs->version);
      $self->{'mappers'}{$slice->coord_system->name}{$slice->coord_system->version||''}{$slice->seq_region_name} = $mapper;
      # first stage mapper: from_cs to transcript's slice
      (my $segs, $problem) = $self->_get_Segments($from_cs, $tran->slice->coord_system, $slice);
      push @segments, @{ $segs };
    }
    
    # Mapping from gene on a slice with the same coordinate system
    elsif ( $from_cs->equals( $self->{'gene_cs'} ) ) {
      my $ga  = $prot->adaptor->db->get_GeneAdaptor();
      my $sa  = $prot->adaptor->db->get_SliceAdaptor();
      $gene   = $ga->fetch_by_translation_stable_id($prot->stable_id);
      $slice  = $sa->fetch_by_gene_stable_id($gene->stable_id);
      # Second stage mapper: slice to peptide
      (undef, $problem) = $self->_get_Segments($slice->coord_system, $to_cs, $slice, $gene, $prot);
      # First stage mapper: gene to slice
      my ($segs, $problem2) = $self->_get_Segments($from_cs, $slice->coord_system, $slice, $gene, $prot);
      push @segments, @{ $segs };
      
      # Apply an error message that refers to the start and end coordinates
      if ($problem || $problem2) {
        warning($problem = sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
      }
    }
    
    # Mapping from xref to peptide
    elsif ( my $callback = $XREF_PEPTIDE_FILTERS{$from_cs->name} ) {
      info(sprintf 'Adding mappings for %s %s -> %s %s',
        $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);

      for my $xref (grep { $callback->{'predicate'}($_) } @{ $prot->get_all_DBEntries() }) {
        my $segid = $callback->{'transformer'}( $xref );
        push @segments, [ $segid ];
        # If xref has a cigar alignment, use it to build mappings to the
        # Ensembl translation (assume they all align to the translation).
        # If not, we still query with the segment because non-positional
        # features don't need a mapper.
        if ($xref->can('get_mapper')) {
          my $mapper = Bio::EnsEMBL::ExternalData::DAS::XrefPeptideMapper->new('from', 'to', $from_cs, $to_cs, $xref, $prot);
          $mapper->external_id($segid);
          $mapper->ensembl_id($prot->stable_id);
          $self->{'mappers'}{$from_cs->name}{$from_cs->version}{$segid} = $mapper;
        }
        # Otherwise we assume the mappings are all 1:1 (i.e. IdentityXrefs are 100% identity)
        else {
          my $mapper = Bio::EnsEMBL::Mapper->new( 'from', 'to' );
          $mapper->{'from_cs'} = $from_cs;
          $mapper->{'to_cs'}   = $to_cs;
          my $len = $prot->length;
          $mapper->add_map_coordinates(
            $segid,           1, $len, 1,
            $prot->stable_id, 1, $len
          );
          $self->{'mappers'}{$from_cs->name}{$from_cs->version}{$segid} = $mapper;
        }
      }
    }
    
    # Mapping from gene-mapped xref to peptide
    elsif ( $callback = $XREF_GENE_FILTERS{$from_cs->name} ) {
      my $ga = $prot->adaptor->db->get_GeneAdaptor();
      $gene  = $ga->fetch_by_translation_stable_id($prot->stable_id);
      info(sprintf 'Adding (nonpositional) mappings for %s %s -> %s %s',
        $from_cs->name, $from_cs->version, $to_cs->name, $to_cs->version);
      for my $xref (grep { $callback->{'predicate'}($_) } @{ $gene->get_all_DBEntries() }) {
        my $segid = $callback->{'transformer'}( $xref );
        push @segments, [ $segid ];
        # Gene-based xrefs don't have alignments and so don't generate mappings.
        # It is enough to simply collate the segment ID's; only non-positional
        # features will mapped.
      }
    }
    
    else {
      warning($problem = sprintf 'Mapping from %s to %s is not supported', $from_cs->name, $to_cs->name);
    }
  }
  # No need to map from snpid to snpid
  elsif ( $to_cs->equals( $self->{'snp_cs'} ) && $from_cs->equals( $self->{'snp_cs'} ) ) {
      push @segments, [ $snp->name ];
  }
  else {
    warning($problem = sprintf 'Mapping to %s is not supported', $to_cs->name);
  }
  
   my @filtered;
   my $last_segment;
   
  # Assembly mappings can often create separate segments which are contiguous
  # in the "from" coordinate system. To save multiple requests and reduce
  # receiving duplicate features, we join contiguous segments before querying.
  
  for my $segment (sort { $a->[0] cmp $b->[0] || ($a->[1] || 0) <=> ($b->[1] || 0) } @segments) {
    if ($last_segment) {
      # For new segment IDs, or noncontiguous segments, just add the segment
      if ($segment->[0] ne $last_segment->[0] || !$segment->[1] || !$last_segment->[1] || $segment->[1] > $last_segment->[2]+1) {
        push @filtered, $last_segment;
      }
      # For contiguous (or overlapping) segments, join together
      else {
        info(sprintf 'Joining %s %s segments %s:%s,%s and %s:%s,%s',
                     $from_cs->name, $from_cs->version,
                     @{$last_segment},@{$segment});
        $segment->[1] = $last_segment->[1] if ($last_segment->[1] < $segment->[1]);
        $segment->[2] = $last_segment->[2] if ($last_segment->[2] > $segment->[2]);
      }
    }
    $last_segment = $segment;
  }
  if ($last_segment) {
    push @filtered, $last_segment;
  }
  
  return ( \@filtered, $problem );
}

sub _choose_coord_systems {
  my ( $self, $target_cs, $target_ob, $coord_systems ) = @_;
  
  if (scalar @{ $coord_systems } < 2) {
    return $coord_systems;
  }
  
  my @best_genomic = ();
  my @best_gene    = ();
  my @best_protein = ();
  my @best_snp = ();
  
  my $csa = $target_ob->adaptor->db->get_CoordSystemAdaptor;
  my $ens_rank;
  my $ens_gene;
  my $ens_prot;
  my $ens_snp;
  
  for my $cs ( @{ $coord_systems } ) {
    if ( $cs->equals( $target_cs ) ) {
      return [ $cs ];
    }
    if ( is_genomic($cs) || $cs->name eq 'toplevel' ) {
      my $tmp = $csa->fetch_by_name( $cs->name, $cs->version ) || $csa->fetch_by_name( $cs->name ) || next;
      if ( !defined $ens_rank || $tmp->rank < $ens_rank ) {
        $ens_rank = $tmp->rank;
        @best_genomic = ($cs);
      } elsif ( $tmp->rank == $ens_rank ) {
        push @best_genomic, $cs;
      }
    }
    elsif ( $GENE_COORDS{$cs->name} ) {
      if ( $cs->equals( $self->{'gene_cs'} ) ) {
        $ens_gene = 1;
        @best_gene = ($cs);
      }
      elsif ( !$ens_gene ) {
        push @best_gene, $cs;
      }
    }
    elsif ( $PROT_COORDS{$cs->name} ) {
      if ( $cs->equals( $self->{'prot_cs'} ) ) {
        $ens_prot = 1;
        @best_protein = ($cs);
      }
      elsif ( !$ens_prot ) {
        push @best_protein, $cs;
      }
    }
    elsif ( $SNP_COORDS{$cs->name} ) {
      if ( $cs->equals( $self->{'snp_cs'} ) ) {
        $ens_snp = 1;
        @best_snp = ($cs);
      }
      elsif ( !$ens_snp ) {
        push @best_snp, $cs;
      }
    }
  }
  
  my $best = [];
  if ( is_genomic($target_cs) || $target_cs->name eq 'toplevel' ) {
    $best = @best_genomic ? \@best_genomic : @best_protein ? \@best_protein : \@best_gene;
  } elsif ( $GENE_COORDS{$target_cs->name} ) {
    $best = @best_gene    ? \@best_gene    : @best_genomic ? \@best_genomic : \@best_protein;
  } elsif ( $PROT_COORDS{$target_cs->name} ) {
    $best = @best_protein ? \@best_protein : @best_gene    ? \@best_gene    : \@best_genomic;
  } elsif ( $SNP_COORDS{$target_cs->name} ) {
    $best = @best_snp ? \@best_snp : @best_gene    ? \@best_gene    : \@best_genomic;
  }
  
  info('Chosen from '.scalar @{$coord_systems}.' coords: ' . join '; ', map { $_->name .' '. $_->version } @{$best});
  return $best;
}

1;
