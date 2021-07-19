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

package EnsEMBL::Web::Object::Location;

### NAME: EnsEMBL::Web::Object::Location
### Wrapper around a Bio::EnsEMBL::Slice object  

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION
### Typically contains a Slice, unless dealing with the entire
### Genome (e.g. to display the karyotype)

use strict;

use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

use base qw(EnsEMBL::Web::Object);

sub _filename {
  my $self = shift;
  my $name = sprintf '%s-%d-%s_%s_%s_%s',
    $self->species,
    $self->species_defs->ENSEMBL_VERSION,
    $self->Obj->{'seq_region_name'},
    $self->Obj->{'seq_region_start'},
    $self->Obj->{'seq_region_end'},
    $self->Obj->{'seq_region_strand'};

  $name =~ s/[^-\w\.]/_/g;
  return $name;
}

sub default_action {
  my $self         = shift;
  my $availability = $self->availability;
  return $availability->{'slice'} ? 'View' : $availability->{'chromosome'} ? 'Chromosome' : 'Genome';
}

sub availability {
  my $self = shift;
  
  if (!$self->{'_availability'}) {
    my $species_defs    = $self->species_defs;
    my $variation_db    = $species_defs->databases->{'DATABASE_VARIATION'};
    my @chromosomes     = @{$species_defs->ENSEMBL_CHROMOSOMES || []};
    my %chrs            = map { $_, 1 } @chromosomes;
    my %synteny_hash    = $species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
    my $rows            = $self->table_info($self->get_db, 'stable_id_event')->{'rows'};
    my $seq_region_name = $self->Obj->{'seq_region_name'};
    my $counts          = $self->counts;
    my $availability    = $self->_availability;
    
    $availability->{'chromosome'}      = exists $chrs{$seq_region_name};
    $availability->{'has_chromosomes'} = scalar @chromosomes;
    $availability->{'variation'}       = $variation_db;
    $availability->{'has_strains'}     = $variation_db && $variation_db->{'#STRAINS'};
    $availability->{'slice'}           = $seq_region_name && $seq_region_name ne $self->hub->core_param('r');
    $availability->{'has_synteny'}     = scalar keys %{$synteny_hash{$species_defs->get_config($self->species, 'SPECIES_PRODUCTION_NAME')} || {}};
    $availability->{'has_LD'}          = $variation_db && $variation_db->{'DEFAULT_LD_POP'};
    $availability->{'has_markers'}     = ($self->param('m') || $self->param('r')) && $self->table_info($self->get_db, 'marker_feature')->{'rows'};
    $availability->{"has_$_"}          = $counts->{$_} for qw(alignments pairwise_alignments);
  
    $self->{'_availability'} = $availability;
  }
  
  return $self->{'_availability'};
}

sub has_strainpop {
  my ($self) = @_;

  my $hub = $self->hub;
  my $pop_adaptor = $hub->species_defs->databases->{'DATABASE_VARIATION'} ? $hub->get_adaptor('get_PopulationAdaptor','variation') : undef;
  my $pop = $pop_adaptor && $pop_adaptor->fetch_by_name('Mouse Genomes Project');
  return defined $pop;
}

sub implausibility {
  my ($self) = @_;

  if(!$self->{'_implausibility'}) {
    my $implausibility = {};
    $implausibility->{'strainpop'} = !$self->has_strainpop;
    $self->{'_implausibility'} = $implausibility;
  }
  return $self->{'_implausibility'};
}

sub counts {
  my $self      = shift;

  my $obj       = $self->Obj;
  my $cache     = $self->hub->cache;
  my $key       = '::COUNTS::LOCATION::' . $self->species . '::' . $self->slice->seq_region_name;
  my $counts    = $self->{'_counts'};
     $counts  ||= $cache->get($key) if $cache;

  if (!$counts) {
    my %synteny = $self->species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
    my $alignments = $self->count_alignments;
    
    $counts = {
      synteny             => scalar keys %{$synteny{$self->species}||{}},
      alignments          => $alignments->{'all'},
      pairwise_alignments => $alignments->{'pairwise'} + $alignments->{'patch'}
    };
    
    $counts->{'reseq_strains'} = $self->species_defs->databases->{'DATABASE_VARIATION'}{'#STRAINS'} if $self->species_defs->databases->{'DATABASE_VARIATION'};
    
    $counts = {%$counts, %{$self->_counts}};
    
    $cache->set($key, $counts, undef, 'COUNTS') if $cache;
    $self->{'_counts'} = $counts;
  }

  return $counts;
}

sub count_alignments {
  my $self          = shift;
  my $cdb           = shift || 'DATABASE_COMPARA';
  my $c             = $self->SUPER::count_alignments($cdb);
  my %intra_species = $self->species_defs->multi($cdb, 'INTRA_SPECIES_ALIGNMENTS');
  
  $c->{'patch'} = scalar @{$intra_species{'REGION_SUMMARY'}{$self->species}{$self->slice->seq_region_name} || []};
  
  return $c; 
}

sub short_caption {
  my $self = shift;

  return shift eq 'global' ?
    'Location: ' . $self->Obj->{'seq_region_name'} . ':' . $self->thousandify($self->Obj->{'seq_region_start'}) . '-' . $self->thousandify($self->Obj->{'seq_region_end'}) :
    'Location-based displays';
}

sub caption {
  my $self = shift;
  return $self->hub->action eq 'Genome' ? '' : $self->neat_sr_name($self->seq_region_type, $self->seq_region_name) . ': ' . $self->thousandify($self->seq_region_start) . '-' . $self->thousandify($self->seq_region_end);
}

sub centrepoint      { return ( $_[0]->Obj->{'seq_region_end'} + $_[0]->Obj->{'seq_region_start'} ) / 2; }
sub length           { return   $_[0]->Obj->{'seq_region_end'} - $_[0]->Obj->{'seq_region_start'} + 1; }

sub slice {
  my $self = shift;
  $self->Obj->{'slice'} ||= $self->database('core', $self->real_species)->get_SliceAdaptor->fetch_by_region(map $self->$_, qw(seq_region_type seq_region_name seq_region_start seq_region_end seq_region_strand));
  return $self->Obj->{'slice'} unless shift eq 'expand';
  my ($flank5, $flank3) = map $self->param($_), qw(flank5_display flank3_display);
  return $flank5 || $flank3 ? $self->Obj->{'slice'}->expand($flank5, $flank3) : $self->Obj->{'slice'};
}

# Find out if a slice exists for given coordinates
sub check_slice {
  my $self = shift;
  my ($chr, $start, $end, $strand) = @_;
  return $self->database('core', $self->real_species)->get_SliceAdaptor->fetch_by_region($self->seq_region_type, $chr, $start, $end, $strand);
}

sub chromosome {
  my ($self, $species) = @_;
  my $sliceAdaptor = $self->get_adaptor('get_SliceAdaptor');
  return $sliceAdaptor->fetch_by_region( undef, $self->seq_region_name);
}

sub get_snp { return $_[0]->__data->{'snp'}[0] if $_[0]->__data->{'snp'}; }

sub attach_slice       { $_[0]->Obj->{'slice'} = $_[1];              }
sub real_species       :lvalue { $_[0]->Obj->{'real_species'};       }
sub raw_feature_strand :lvalue { $_[0]->Obj->{'raw_feature_strand'}; }
sub strand             :lvalue { $_[0]->Obj->{'strand'};             }
sub name               :lvalue { $_[0]->Obj->{'name'};               }
sub sub_type           :lvalue { $_[0]->Obj->{'type'};               }
sub synonym            :lvalue { $_[0]->Obj->{'synonym'};            }
sub seq_region_name    :lvalue { $_[0]->Obj->{'seq_region_name'};    }
sub seq_region_start   :lvalue { $_[0]->Obj->{'seq_region_start'};   }
sub seq_region_end     :lvalue { $_[0]->Obj->{'seq_region_end'};     }
sub seq_region_strand  :lvalue { $_[0]->Obj->{'seq_region_strand'};  }
sub seq_region_type    :lvalue { $_[0]->Obj->{'seq_region_type'};    }
sub seq_region_length  :lvalue { $_[0]->Obj->{'seq_region_length'};  }

sub align_species {
    my $self = shift;
    if (my $add_species = shift) {
        $self->Obj->{'align_species'} = $add_species;
    }
    return $self->Obj->{'align_species'};
}

sub coord_systems {
  ## Needed by Location/Karyotype to display DnaAlignFeatures
  my $self = shift;
  my ($exemplar) = keys(%{$self->Obj});
#warn $self->Obj->{$exemplar}->[0];
  return [ map { $_->name } @{ $self->database('core',$self->real_species)->get_CoordSystemAdaptor()->fetch_all() } ];
}

sub misc_set_code {
  my $self = shift;
  if( @_ ) { 
    $self->Obj->{'misc_set_code'} = shift;
  }
  return $self->Obj->{'misc_set_code'};
}

sub setCentrePoint {
  my $self        = shift;
  my $centrepoint = shift;
  my $length      = shift || $self->length;
  $self->seq_region_start = $centrepoint - ($length-1)/2;
  $self->seq_region_end   = $centrepoint + ($length+1)/2;
}

sub setLength {
  my $self        = shift;
  my $length      = shift;
  $self->seq_region_start = $self->centrepoint - ($length-1)/2;
  $self->seq_region_end   = $self->seq_region_start + ($length-1)/2;
}

sub addContext {
  my $self = shift;
  my $context = shift;
  $self->seq_region_start -= int($context);
  $self->seq_region_end   += int($context);
}


######## "FeatureView" calls ##########################################

sub create_features {
  my $self = shift;
  my $features = {};

  my $db        = $self->param('db')  || 'core'; 
  my ($identifier, $fetch_call, $featureobj, $dataobject, $subtype);
  
  ## Are we inputting IDs or searching on a text term?
  if ($self->param('xref_term')) {
    my @exdb = $self->param('xref_db');
    $features = $self->search_Xref($db, \@exdb, $self->param('xref_term'));
  }
  else {
    my $feature_type  = $self->param('ftype') ||$self->param('type') || 'ProbeFeature';  
    if ( ($self->param('ftype') eq 'ProbeFeature')){
      $db = 'funcgen';
      if ( $self->param('ptype')) {
        $subtype = $self->param('ptype');
      }
    } 
   ## deal with xrefs
    if ($feature_type =~ /^Xref_/) {
      ## Don't use split here - external DB name may include underscores!
      ($subtype = $feature_type) =~ s/Xref_//;
      $feature_type = 'Xref';
    }

    my $create_method = "_create_$feature_type"; 
    $features    = defined &$create_method ? $self->$create_method($db, $subtype) : undef;
  }
  return $features;
}

sub _create_Domain {
  my $self =shift;
  my $id = $self->param('id');
  my $a = $self->get_adaptor('get_GeneAdaptor'); 
  my $domains = $a->fetch_all_by_domain($id);
  my %features = ('Domain' => $domains);

  return \%features;
}

sub _create_Phenotype {
  my ($self, $db) = @_;  
  my $slice;
  my $features;
  my $array = [];  
  my $id = $self->param('id');
        
  my @chrs = @{$self->species_defs->ENSEMBL_CHROMOSOMES};  

  foreach my $chr (@chrs)
  {
    $slice = $self->database('core')->get_SliceAdaptor()->fetch_by_region("chromosome", $chr);
    my $array2 = $self->database('variation')->get_PhenotypeFeatureAdaptor()->fetch_all_by_phenotype_id_source_name($id);

    push(@$array,@$array2) if (@$array2);
  }  
  $features = {'Variation' => $array};      
  return $features;
}

sub _create_ProbeFeature {
  # get Oligo hits plus corresponding genes
  my $probe;
  if ( $_[2] eq 'pset'){  
    $probe = $_[0]->_generic_create( 'ProbeFeature', 'fetch_all_by_probeset_name', $_[1] );
  } else {
    $probe = $_[0]->_create_ProbeFeatures_by_probe_id;
  }
  #my $probe_trans = $_[0]->_generic_create( 'Transcript', 'fetch_all_by_external_name', $_[1], undef, 'no_errors' );
  my $probe_trans = $_[0]->_create_ProbeFeatures_linked_transcripts($_[2]);
  my %features = ('ProbeFeature' => $probe);
  $features{'Transcript'} = $probe_trans if $probe_trans;
  return \%features;
}

sub _create_ProbeFeatures_by_probe_id {
  my $self = shift;
  my $db_adaptor = $self->_get_funcgen_db_adaptor; 
  my $probe_adaptor = $db_adaptor->get_ProbeAdaptor;  
  my @probe_objs = @{$probe_adaptor->fetch_all_by_name($self->param('id'))};
  my $probe_obj = $probe_objs[0];
  my $probe_feature_adaptor = $db_adaptor->get_ProbeFeatureAdaptor;
  my @probe_features =  @{$probe_feature_adaptor->fetch_all_by_Probe($probe_obj)};
  return \@probe_features;
}

sub _create_ProbeFeatures_linked_transcripts {
  my ($self, $ptype)  = @_;
  my $db_adaptor = $self->_get_funcgen_db_adaptor;
  my (@probe_objs, @transcripts, %seen );

  if ($ptype eq 'pset'){
  my  $probe_feature_adaptor = $db_adaptor->get_ProbeFeatureAdaptor;
  @probe_objs = @{$probe_feature_adaptor->fetch_all_by_probeset($self->param('id'))}; 
  } else {
    my  $probe_adaptor = $db_adaptor->get_ProbeAdaptor;
    @probe_objs = @{$probe_adaptor->fetch_all_by_name($self->param('id'))};
  } 
 ## Now retrieve transcript ID and create transcript Objects 
  foreach my $probe (@probe_objs){
    my @dbentries = @{$probe->get_all_Transcript_DBEntries};
    foreach my $entry (@dbentries) {
      my $core_db_adaptor = $self->_get_core_adaptor ;
      my $transcript_adaptor = $core_db_adaptor->get_TranscriptAdaptor; 
      unless (exists $seen{$entry->primary_id}){
        my $transcript = $transcript_adaptor->fetch_by_stable_id($entry->primary_id);  
        push (@transcripts, $transcript);  
        $seen{$entry->primary_id} =1;
      }
    }
  }

  return \@transcripts;
}

sub _get_funcgen_db_adaptor {
   my $self = shift;
   my $db = $self->param('db');
   if ($self->param('fdb')) { $db = $self->param('fdb');}
   my $db_adaptor  = $self->database(lc($db));
   unless( $db_adaptor ){
     $self->problem( 'fatal', 'Database Error', "Could not connect to the $db database." );
     return undef;
   }
  return $db_adaptor;
}

sub _get_core_adaptor {
   my $self = shift;
   my $db_adaptor  = $self->database('core');
   unless( $db_adaptor ){
     $self->problem( 'fatal', 'Database Error', "Could not connect to the core database." );
     return undef;
   }
  return $db_adaptor;
}

sub _create_DnaAlignFeature {
  my $features = {'DnaAlignFeature' => $_[0]->_generic_create( 'DnaAlignFeature', 'fetch_all_by_hit_name', $_[1] ) };
  my $genes = $_[0]->_generic_create( 'Gene', 'fetch_all_by_external_name', $_[1],undef, 'no_errors' );
  $features->{'Gene'} = $genes if $genes;
  return $features;
}

sub _create_ProteinAlignFeature {
  my $features = {'ProteinAlignFeature' => $_[0]->_generic_create( 'ProteinAlignFeature', 'fetch_all_by_hit_name', $_[1] ) };
  my $genes = $_[0]->_generic_create( 'Gene', 'fetch_all_by_external_name', $_[1],undef, 'no_errors' );
  $features->{'Gene'} = $genes if $genes;
  return $features;
}

sub _create_Gene {
  my ($self, $db) = @_;
  if ($self->param('id') =~ /^ENS/) {
    return {'Gene' => $self->_generic_create( 'Gene', 'fetch_by_stable_id', $db ) };
  }
  else {
    return {'Gene' => $self->_generic_create( 'Gene', 'fetch_all_by_external_name', $db ) };
  }
}

# For a Regulatory Factor ID display all the RegulatoryFeatures
sub _create_RegulatoryFactor {
  my ( $self, $db, $id ) = @_;

  if (!$id ) {$id = $self->param('id'); }
  my $analysis = $self->param('analysis');

  my $db_type  = 'funcgen';
  my $efg_db = $self->database(lc($db_type));
  if(!$efg_db) {
     warn("Cannot connect to $db_type db");
     return [];
  }
  my $features;
  my $feats = (); 

  my %fset_types = (
   "cisRED group motif" => "cisRED motifs",
   "miRanda miRNA_target" => "miRanda miRNA targets",
   "BioTIFFIN motif" => "BioTIFFIN motifs",
   "VISTA" => 'VISTA enhancer set'
  );

  if ($analysis eq 'Regulatory_Build'){
    my $regfeat_adaptor = $efg_db->get_RegulatoryFeatureAdaptor;
    my $feature = $regfeat_adaptor->fetch_by_stable_id($id);
    push (@$feats, $feature);
    $features = {'RegulatoryFactor'=> $feats};

  } else {
    if ($self->param('dbid')){
      my $ext_feat_adaptor = $efg_db->get_ExternalFeatureAdaptor;
      my $feature = $ext_feat_adaptor->fetch_by_dbID($self->param('dbid'));
      my @assoc_features = @{$ext_feat_adaptor->fetch_all_by_Feature_associated_feature_types($feature)};

      if (scalar @assoc_features ==0) {
         push @assoc_features, $feature;
      }
      $features= {'RegulatoryFactor' => \@assoc_features};
    } else {
      my $feature_set_adaptor = $efg_db->get_FeatureSetAdaptor;
      my $feat_type_adaptor =  $efg_db->get_FeatureTypeAdaptor; 
      my $ftype = $feat_type_adaptor->fetch_by_name($id);  
      my @ftypes = ($ftype); 
      my $type = $ftype->description; 
      my $fstype = $fset_types{$type};  
      my $fset = $feature_set_adaptor->fetch_by_name($fstype); 
      my @fsets = ($fstype);
      my $feats = $fset->get_Features_by_FeatureType($ftype);
      $features = {'RegulatoryFactor'=> $feats};
    }
  }

  return $features if $features && keys %$features; # Return if we have at least one feature
  # We have no features so return an error....
  $self->problem( 'no_match', 'Invalid Identifier', "Regulatory Factor $id was not found" );
  return undef;
}

sub _create_Xref {
  # get OMIM hits plus corresponding Ensembl genes
  my ($self, $db, $subtype) = @_;
  my $t_features = [];
  my ($xrefarray, $genes);

  if ($subtype eq 'MIM') {
    my $mim_g = $self->_generic_create( 'DBEntry', 'fetch_by_db_accession', [$db, 'MIM_GENE'] );
    my $mim_m = $self->_generic_create( 'DBEntry', 'fetch_by_db_accession', [$db, 'MIM_MORBID'] );
    @$t_features = (@$mim_g, @$mim_m);
  }
  else { 
    $t_features = $self->_generic_create( 'DBEntry', 'fetch_by_db_accession', [$db, $subtype] );
  }
  if( $t_features && ref($t_features) eq 'ARRAY') {
    ($xrefarray, $genes) = $self->_create_XrefArray($t_features, $db);
  }

  my $features = {'Xref'=>$xrefarray};
  $features->{'Gene'} = $genes if $genes;
  return $features;
}

sub _create_XrefArray {
  my ($self, $t_features, $db) = @_;
  my (@features, @genes);

  foreach my $t (@$t_features) {
    ## we need to keep each xref and its matching genes together
    my @matches;
    push @matches, $t;
    ## get genes for each xref
    my $id = $t->primary_id;
    my $t_genes = $self->_generic_create( 'Gene', 'fetch_all_by_external_name', $db, $id, 'no_errors' );
    if ($t_genes && @$t_genes) {
      push (@matches, @$t_genes);
      push (@genes, @$t_genes);
    }
    push @features, \@matches;
  }

  return (\@features, \@genes);
}

sub _generic_create {
  my( $self, $object_type, $accessor, $db, $id, $flag ) = @_; 
  $db ||= 'core';
  if (!$id ) {
    my @ids = $self->param( 'id' );
    $id = join(' ', @ids);
  }
  elsif (ref($id) eq 'ARRAY') {
    $id = join(' ', @$id);
  }

  ## deal with xrefs
  my $xref_db;
  if ($object_type eq 'DBEntry') {
    my @A = @$db;
    $db = $A[0];
    $xref_db = $A[1];
  }

  if( !$id ) {
    return undef; # return empty object if no id
  }
  else {
# Get the 'central' database (core, est, vega)
    my $db_adaptor  = $self->database(lc($db));
    unless( $db_adaptor ){
      $self->problem( 'fatal', 'Database Error', "Could not connect to the $db database." );
      return undef;
    }
    my $adaptor_name = "get_${object_type}Adaptor";
    my $features = [];
    $id =~ s/\s+/ /g;
    $id =~s/^ //;
    $id =~s/ $//;
    foreach my $fid ( split /\s+/, $id ) {
      my $t_features;
      if ($xref_db) {
        eval {
         $t_features = [$db_adaptor->$adaptor_name->$accessor($xref_db, $fid)];
        };
      }
      elsif ($accessor eq 'fetch_by_stable_id') { ## Hack to get gene stable IDs to work!
        eval {
         $t_features = [$db_adaptor->$adaptor_name->$accessor($fid)];
        };
      }
      else {
        eval {
         $t_features = $db_adaptor->$adaptor_name->$accessor($fid);
        };
      }
      ## if no result, check for unmapped features
      if ($t_features && ref($t_features) eq 'ARRAY') {
        if (!@$t_features) {
          my $uoa = $db_adaptor->get_UnmappedObjectAdaptor;
          $t_features = $uoa->fetch_by_identifier($fid);
        }
        else {
          foreach my $f (@$t_features) {
            next unless $f;
            $f->{'_id_'} = $fid;
            push @$features, $f;
          }
        }
      }
    }
    return $features if $features && @$features; # Return if we have at least one feature

    # We have no features so return an error....
    unless ( $flag eq 'no_errors' ) {
      $self->problem( 'no_match', 'Invalid Identifier', "$object_type $id was not found" );
    }
    return undef;
  }

}


## The following are used to convert full objects into simple data hashes, for use by drawing code

sub get_tracks {
  my ($self, $key) = @_;
  my $data = $self->hub->fetch_userdata_by_id($key);
  my $tracks = {};

  if (my $parser = $data->{'parser'}) {
    while (my ($type, $track) = each(%{$parser->get_all_tracks})) {
      my @A = @{$track->{'features'}};
      my @rows;
      foreach my $feature (@{$track->{'features'}}) {
        my $data_row = {
          'chr'     => $feature->seqname(),
          'start'   => $feature->rawstart(),
          'end'     => $feature->rawend(),
          'label'   => $feature->id(),
          'gene_id' => $feature->id(),
        };
        push (@rows, $data_row);
      }
      $tracks->{$type} = {'features' => \@rows, 'config' => $track->{'config'}};
    }
  }
  else { 
    while (my ($analysis, $track) = each(%{$data})) {
      my @rows;
      foreach my $f (
        map { $_->[0] }
        sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
        map { [$_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20 , $_->{'region'},
$_->{'start'}] }
        @{$track->{'features'}}
        ) {
        my $data_row = {
          'chr'       => $f->{'region'},          
          'start'     => $f->{'start'},
          'end'       => $f->{'end'},
          'length'    => $f->{'length'},
          'label'     => $f->{'label'},
          'gene_id'   => $f->{'gene_id'},
        };
        push (@rows, $data_row);
      }
      $tracks->{$analysis} = {'features' => \@rows, 'config' => $track->{'config'}};
    } 
  } 

  return $tracks;
}

sub retrieve_features {
  my ($self, $features) = @_;
  my $method;
  my $results = [];  
  while (my ($type, $data) = each (%$features)) { 
    $method = 'retrieve_'.$type; 
    push @$results, [$self->$method($data,$type)] if defined &$method;
  }  

  return $results;
}

sub retrieve_Gene {
  my ($self, $data, $type) = @_;
  my $results = [];
  foreach my $g (@$data) {
    if (ref($g) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($g);
      push(@$results, $unmapped);
    }
    else {
      push @$results, {
        'region'   => $g->seq_region_name,
        'start'    => $g->start,
        'end'      => $g->end,
        'strand'   => $g->strand,
        'length'   => $g->end-$g->start+1,
        'extname'  => $g->external_name,
        'label'    => $g->stable_id,
        'gene_id'  => [ $g->stable_id ],
        'extra'    => [ $g->description ]
      }
    }
  }

  return ( $results, ['Description'], $type );
}

sub retrieve_Transcript {
  my ($self, $data, $type) = @_;
  my $results = [];
  foreach my $t (@$data) {
    if (ref($t) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($t);
      push(@$results, $unmapped);
    }
    else {
      my $trans = $self->new_object('Transcript',$t, $self->__data);
      my $desc = $trans->trans_description();
      push @$results, {
        'region'   => $t->seq_region_name,
        'start'    => $t->start,
        'end'      => $t->end,
        'strand'   => $t->strand,
        'length'   => $t->end-$t->start+1,
        'extname'  => $t->external_name,
        'label'    => $t->stable_id,
        'trans_id' => [ $t->stable_id ],
        'extra'    => [ $desc ]
      }
    }
  }
  return ( $results, ['Description'], $type );
}

sub retrieve_Variation {
  my ($self, $data, $type) = @_;
  my $hub          = $self->hub;
  my $phenotype_id = $hub->param('id');
  my $results      = [];
  
  # getting associated phenotype with the variation
  my $variation_array = Bio::EnsEMBL::Registry->get_adaptor($hub->species, 'variation', 'phenotypefeature')->fetch_all_by_VariationFeature_list($data);

  foreach my $v (@$data) {  
    # getting all genes located in that specific location
    my ($seq_region, $start, $end) = ($v->seq_region_name, $v->seq_region_start, $v->end);    
    my $slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('chromosome', $seq_region, $start, $end);
    my $genes = $slice->get_all_Genes;
    my ($gene_link, $add_comma, $associated_phenotype, $associated_gene, $p_value_log);
    
    foreach my $row (@$genes) {
      my $gene_symbol;
      $gene_symbol = '(' . $row->display_xref->display_id . ')' if $row->{'stable_id'};
      
      my $gene_name = $row->{'stable_id'};
      my $gene_url  = $hub->url({ type => 'Gene', action => 'Summary', g => $gene_name});        
      $gene_link   .= qq{, } if $gene_link;
      $gene_link   .= qq{<a href="$gene_url">$gene_name</a> $gene_symbol};        
    }
    
    my @associated_gene_array;

    # getting associated phenotype and associated gene with the variation
    foreach my $variation (@$variation_array) {      
      # only get associated gene and phenotype for matching variation id
      if ($variation->{'_variation_id'} eq $v->{'_variation_id'}) {          
        $associated_phenotype .= qq{$variation->{'phenotype_description'}, } if $associated_phenotype !~ /, $variation->{'phenotype_description'}/g;          
              
        if ($variation->{'_phenotype_id'} eq $phenotype_id) {
          # if there is more than one associated gene (comma separated) split them to generate the URL for each of them          
          if ($variation->{'associated_gene'} =~ /,/g) {            
            push @associated_gene_array, split /,/, $variation->{'associated_gene'};
          } else {
            push @associated_gene_array, $variation->{'associated_gene'};
          }

          $p_value_log = -(log($variation->{'p_value'}) / log(10)) if $variation->{'p_value'} != 0; # only get the p value log 10 for the pointer matching phenotype id and variation id
        }
      }      
    }  
    
    # preparing the URL for all the associated genes and ignoring duplicate one
    foreach my $gene (@associated_gene_array) {              
      if ($gene) {
        $gene =~ s/\s//gi;
        my $associated_gene_url = $hub->url({ type => 'Gene', action => 'Summary', g => $gene, v => $v->variation_name, vf => $v->dbID });                                                        
        $associated_gene .= qq{$gene, } if($gene eq 'Intergenic');
        $associated_gene .= qq{<a href=$associated_gene_url>$gene</a>, } if($associated_gene !~ /$gene/i && $gene ne 'Intergenic');
      }                            
    }
    
    $associated_gene =~ s/\s$//g;        # removing the last white space
    $associated_gene =~ s/,$|^,//g;      # replace the last or first comma if there is any
    
    $associated_phenotype =~ s/\s$//g;   # removing the last white space
    $associated_phenotype =~ s/,$|^,//g; # replace the last or first comma if there is any
    
    if (ref($v) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($v);
      push @$results, $unmapped;
    } else {
      # making the location 10kb if it a one base pair
      if ($v->end - $v->start == 0) {
        $start = $start - 5000;
        $end = $end + 5000;
      }
      
      push @$results, {
        region         => $v->seq_region_name,
        start          => $start,
        end            => $end,
        strand         => $v->strand,        
        label          => $v->variation_name,        
        href           => $hub->url({ type => 'Variation', action => 'Variation', v => $v->variation_name, vf => $v->dbID, vdb => 'variation' }),
        extra          => [ $gene_link, $associated_gene, $associated_phenotype, sprintf '%.1f', $p_value_log ],
        p_value        => $p_value_log,  
        colour_scaling => 1,
      }
    }
  }
  
  return ($results, [ 'Located in gene(s)', 'Reported Gene(s)', 'Associated Phenotype(s)', 'P value (negative log)' ], $type);
}

sub retrieve_Xref {
  my ($self, $data, $type) = @_;
  my $results = [];
  
  foreach my $array (@$data) {
    my $xref = shift @$array;
    
    push @$results, {
      label     => $xref->primary_id,
      xref_id   => [ $xref->primary_id ],
      extname   => $xref->display_id,
      extra     => [ $xref->description, $xref->dbname ]
    };
    
    ## also get genes
    foreach my $g (@$array) {
      push @$results, {
        region   => $g->seq_region_name,
        start    => $g->start,
        end      => $g->end,
        strand   => $g->strand,
        length   => $g->end - $g->start + 1,
        extname  => $g->external_name,
        label    => $g->stable_id,
        gene_id  => [ $g->stable_id ],
        extra    => [ $g->description ]
      }
    }
  }
  return ($results, ['Description'], $type);
}

sub retrieve_ProbeFeature {
  my ($self, $data, $type) = @_;
  my $results = [];
  
  foreach my $probefeature (@$data) { 
    my $probe = $probefeature->probe;
    
    if (ref($probe) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($probe);
      push(@$results, $unmapped);
    } else {
      my $names = join ' ', map { /^(.*):(.*):\2/? "$1:$2" : $_ } sort @{$probe->get_all_complete_names};
      
      foreach my $f (@{$probe->get_all_ProbeFeatures}) {  
        push @$results, {
          region   => $f->seq_region_name,
          start    => $f->start,
          end      => $f->end,
          strand   => $f->strand,
          length   => $f->end - $f->start + 1,
          label    => $names,
          gene_id  => [ $names ],
          extra    => [ $f->mismatchcount, $f->cigar_string ]
        }
      }
    }
  }
  return ($results, ['Mismatches', 'Cigar String'], $type);
}

sub retrieve_Domain {
  my ($self, $data, $type) = @_;
  my $hub     = $self->hub;
  my $results = [];
  
  foreach my $f (@$data) {
    if (ref($f) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($f);
      push @$results, $unmapped;
    } else {
      my $location      = $f->seq_region_name . ':' . $f->start . '-' . $f->end;
      my $location_url  = $hub->url({ type => 'Location', action => 'View', r => $location });
      my $location_link = qq{<a href="$location_url">$location</a>};
      
      push @$results,{
        region  => $f->seq_region_name,
        start   => $f->start,
        end     => $f->end,
        strand  => $f->strand,
        length  => $f->end - $f->start + 1,
        extname => $f->external_name,
        label   => $f->stable_id,
        gene_id => [ $f->stable_id ],
        extra   => [ $location_link, $f->description ]
      }
    }
  }

  return ($results, [ 'Genomic Location', 'Description' ], $type);
}

sub retrieve_DnaAlignFeature {
  my ($self, $data, $type) = @_;
  my $results = [];
  
  foreach my $f (@$data) {
    if (ref($f) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($f);
      push(@$results, $unmapped);
    }  else {
      my $coord_systems = $self->coord_systems;
      my ($region, $start, $end, $strand) = ($f->seq_region_name, $f->start, $f->end, $f->strand);
      
      if ($f->coord_system_name ne $coord_systems->[0]) {
        foreach my $system ( @{$coord_systems} ) {
          my $slice = $f->project( $system );
          
          if (scalar @$slice == 1) {
            ($region, $start, $end, $strand) = ($slice->[0][2]->seq_region_name, $slice->[0][2]->start, $slice->[0][2]->end, $slice->[0][2]->strand);
            last;
          }
        }
      }
      
      push @$results, {
        region  => $region,
        start   => $start,
        end     => $end,
        strand  => $strand,
        length  => $f->end - $f->start + 1,
        label   => sprintf('%s %s-%s', $f->display_id, $f->hstart, $f->hend),
        gene_id => [ sprintf('%s-%s', $f->hstart, $f->hend) ],
        extra   => [ $f->alignment_length, $f->hstrand * $f->strand, $f->percent_id, $f->score, $f->p_value ]
      };
    }
  }
  
  my $feature_mapped = 1; ## TODO - replace with $self->feature_mapped call once unmapped feature display is added
  
  if ($feature_mapped) {
    return $results, [ 'Alignment length', 'Rel ori', '%id', 'score', 'p-value' ], $type;
  }  else {
    return $results, [], $type;
  }
}

sub retrieve_ProteinAlignFeature {
  my ($self, $data, $type) = @_;
  return $self->retrieve_DnaAlignFeature($data,$type);
}

sub retrieve_RegulatoryFactor {
  my ($self, $data, $type) = @_;
  my $hub     = $self->hub;
  my $results = [];
  my $flag    = 0;
  
  foreach my $reg (@$data) {
    my @stable_ids;
    my $gene_links;
    my $db_ent = $reg->get_all_DBEntries;
    
    foreach (@$db_ent) {
      push @stable_ids, $_->primary_id;
      my $url      = $hub->url({ type => 'Gene', action => 'Summary', g => $stable_ids[-1] }); 
      $gene_links .= qq(<a href="$url">$stable_ids[-1]</a>);  
    }
    
    my @extra_results = $reg->analysis->description;
    $extra_results[0] =~ s/(https?:\/\/\S+[\w\/])/<a rel="external" href="$1">$1<\/a>/ig;

    unshift @extra_results, $gene_links;

    push @$results, {
      region  => $reg->seq_region_name,
      start   => $reg->start,
      end     => $reg->end,
      strand  => $reg->strand,
      length  => $reg->end-$reg->start+1,
      label   => $reg->display_label,
      gene_id => \@stable_ids,
      extra   => \@extra_results,
    }
  }
  
  my $extras = [ 'Feature analysis' ];
  unshift @$extras, 'Associated gene';
  
  return ($results, $extras, $type);
}

sub unmapped_object {
  my ($self, $unmapped) = @_;
  my $analysis = $unmapped->analysis;

  my $result = {
    label    => $unmapped->{'_id_'},
    reason   => $unmapped->description,
    object   => $unmapped->ensembl_object_type,
    score    => $unmapped->target_score,
    analysis => $$analysis{'_description'},
  };

  return $result;
}


######## SYNTENYVIEW CALLS ################################################

sub fetch_homologues_of_gene_in_species {
  my $self = shift;
  my ($gene_stable_id, $paired_species) = @_;
  
  return [] unless $self->database('compara');

  my $qy_member = $self->database('compara')->get_GeneMemberAdaptor->fetch_by_stable_id($gene_stable_id);
  
  return [] unless defined $qy_member; 

  my $ha = $self->database('compara')->get_HomologyAdaptor;
  my @homologues;
  
  foreach my $homology (@{$ha->fetch_all_by_Member($qy_member, -TARGET_SPECIES => [$paired_species])}) {
    # The target member is guaranteed to be in second position in the array
    push @homologues, $homology->get_all_Members()->[1]->gene_member();
  }
  
  return \@homologues;
}

sub bp_to_nearest_unit {
  my $self = shift ;
  my ($bp, $dp) = @_;
  
  $dp = 2 unless defined $dp;
  
  my @units = qw(bp Kb Mb Gb Tb);
  
  my $power_ranger = int((CORE::length(abs $bp) - 1) / 3);
  my $unit         = $units[$power_ranger];
  my $value        = int($bp / (10 ** ($power_ranger * 3)));
  my $unit_str;
  
  if ($unit ne 'bp'){
    $unit_str = sprintf "%.${dp}f%s", $bp / (10 ** ($power_ranger * 3)), " $unit";
  } else {
    $unit_str = "$value $unit";
  }
  
  return $unit_str;
}

sub get_synteny_matches {
  my ($self, $other_species) = @_;

  my @data;
  $other_species ||= $self->hub->otherspecies;
  my $gene2_adaptor = $self->database('core', $other_species)->get_GeneAdaptor;
  my $localgenes    = $self->get_synteny_local_genes;
  my $offset        = $self->seq_region_start;

  foreach my $localgene (@$localgenes){
    my $homologues   = $self->fetch_homologues_of_gene_in_species($localgene->stable_id, $other_species);
    my $homol_num    = scalar @$homologues;
    my $gene_synonym = $localgene->external_name || $localgene->stable_id;

    if (@$homologues) {
      foreach my $homol (@$homologues) {
        my $gene       = $gene2_adaptor->fetch_by_stable_id($homol->stable_id);
        my $homol_id   = $gene->external_name || $gene->stable_id;
        my $gene_slice = $gene->slice;
        my $h_start    = $gene->start;
       
        push @data, {
          'sp_stable_id'    => $localgene->stable_id,
          'sp_synonym'      => $gene_synonym,
          'sp_chr'          => $localgene->seq_region_name,
          'sp_start'        => $localgene->seq_region_start,
          'sp_end'          => $localgene->seq_region_end,
          'sp_length'       => $self->bp_to_nearest_unit($localgene->start + $offset),
          'other_stable_id' => $homol->stable_id,
          'other_synonym'   => $homol_id,
          'other_chr'       => $gene_slice->seq_region_name,
          'other_start'     => $h_start,
          'other_end'       => $gene->end,
          'other_length'    => $self->bp_to_nearest_unit($gene->end - $h_start),
          'homologue_no'    => $homol_num
        };
      }
    } else {
      push @data, { 
        'sp_stable_id' => $localgene->stable_id,
        'sp_chr'       => $localgene->seq_region_name,
        'sp_start'     => $localgene->seq_region_start,
        'sp_end'       => $localgene->seq_region_end,
        'sp_synonym'   => $gene_synonym,
        'sp_length'    => $self->bp_to_nearest_unit($localgene->start + $offset) 
      };
    }
  }
  
  return \@data;
}

sub get_synteny_local_genes {
  my $self  = shift ;
  my $flag  = @_ ? 1 : 0;
  my $slice = shift || $self->slice;
  my @localgenes;
  
  $slice = $slice->sub_Slice(1, 1e6) if !$flag && $slice->length >= 1e6 && $self->param('r') !~ /:/;

  ## Ensures that only protein coding genes are included in syntenyview
  my @biotypes = ('protein_coding', 'V_segments', 'C_segments');
  
  foreach my $type (@biotypes) {
    my $genes = $slice->get_all_Genes_by_type($type);
    push @localgenes, @$genes if scalar @$genes;
  }

  my @sorted = sort { $a->start <=> $b->start } @localgenes;
  return \@sorted;
}

######## LDVIEW CALLS ################################################


sub get_default_pop_name {

  ### Example : my $pop_id = $self->DataObj->get_default_pop_name
  ### Description : returns population id for default population for this species
  ### Returns population dbID

  my $self = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pop_adaptor = $variation_db->get_PopulationAdaptor;
  my $pop = $pop_adaptor->fetch_default_LDPopulation(); 
  return unless $pop;
  return $pop->name;
}

sub pop_obj_from_name {

  ### Arg1    : Population name
  ### Example : my $pop_name = $self->DataObj->pop_obj_from_name($pop_id);
  ### Description : returns population info for the given population name
  ### Returns population object

  my $self = shift;
  my $pop_name = shift; 
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_name($pop_name); 
  return {} unless $pop;
  my $data = $self->format_pop( [$pop] );
  return $data;
}


sub pop_name_from_id {

  ### Arg1 : Population id
  ### Example : my $pop_name = $self->DataObj->pop_name_from_id($pop_id);
  ### Description : returns population name as string
  ### Returns string

  my $self = shift;
  my $pop_id = shift;
  return $pop_id if $pop_id =~ /\D+/ && $pop_id !~ /^\d+$/;
  
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_dbID($pop_id);
  return "" unless $pop;
  return $self->pop_name( $pop );
}


sub extra_pop {  ### ALSO IN SNP DATA OBJ

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Arg[2]      : string "super", "sub"
  ### Example : $genotype_freq = $self->DataObj->extra_pop($pop, "super");
  ### Description : gets any super/sub populations
  ### Returns String

  my ($self, $pop_obj, $type)  = @_;
  return {} unless $pop_obj;
  my $call = "get_all_$type" . "_Populations";
  my @populations = @{ $pop_obj->$call};
  return  $self->format_pop(\@populations);
}


sub format_pop {

  ### Arg1 : population object
  ### Example : my $data = $self->format_pop
  ### Description : returns population info for the given population obj
  ### Returns hashref

  my $self = shift;
  my $pops = shift;
  my %data;
  foreach (@$pops) {
    my $name = $self->pop_name($_);
    $data{$name}{Name}       = $self->pop_name($_);
    $data{$name}{dbID}       = $_->dbID;
    $data{$name}{Size}       = $self->pop_size($_);
    $data{$name}{PopLink}    = $self->pop_links($_);
    $data{$name}{Description}= $self->pop_description($_);
    $data{$name}{PopObject}  = $_;  ## ok maybe this is cheating..
  }
  return \%data;
}



sub pop_name {

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Example : $self->DataObj->pop_name($pop);
  ### Description : gets the Population name
  ###  Returns String

  my ($self, $pop_obj)  = @_;
  return unless $pop_obj;
  return $pop_obj->name;
}


sub ld_for_slice {

  ### Arg1 : population object (optional)
  ### Arg2 : width for the slice (optional)
  ### Example : my $container = $self->ld_for_slice;
  ### Description : returns all LD values on this slice as a
  ###               Bio::EnsEMBL::Variation::LDFeatureContainer
  ### Returns    :  Bio::EnsEMBL::Variation::LDFeatureContainer

  my ($self, $pop_obj, $width) = @_;
  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE     = $self->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::VCF_BINARY_FILE = $self->species_defs->ENSEMBL_LD_VCF_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH        = $self->species_defs->ENSEMBL_TMP_TMP;

  my ($seq_region, $start, $end, $seq_type ) = ($self->seq_region_name, $self->seq_region_start, $self->seq_region_end, $self->seq_region_type);
  $width = $self->param('w') || $end - $start unless $width;
  return [] unless $seq_region;

  $end   = $start + $width;
  my $slice = $self->slice_cache($seq_type, $seq_region, $start, $end, 1);
  return {} unless $slice;

  return  $slice->get_all_LD_values($pop_obj) || {};
}


sub pop_links {

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Example : $genotype_freq = $self->DataObj->pop_links($pop);
  ### Description : gets the Population description
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->get_all_synonyms("dbSNP");
}


sub pop_size {

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Example : $genotype_freq = $self->DataObj->pop_size($pop);
  ### Description : gets the Population size
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->size;
}

sub pop_description {

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Example : $genotype_freq = $self->DataObj->pop_description($pop);
  ### Description : gets the Population description
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->description;
}

sub location { 

  ### Arg1 : (optional) String  Name of slice
  ### Example : my $location = $self->DataObj->name;
  ### Description : getter/setter for slice name
  ### Returns String for slice name

    return $_[0]; 
}

sub get_variation_features {

  ### Example : my @vari_features = $self->get_variation_features;
  ### Description : gets the Variation features found  on a slice
  ### Returns Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

   my $self = shift;
   my $slice = $self->slice_cache;
   return unless $slice;
   my $vf_adaptor = $self->hub->database('variation')->get_VariationFeatureAdaptor;
   return $vf_adaptor->fetch_all_by_Slice($slice) || [];
}

sub slice_cache {
  my $self = shift;
  my( $type, $region, $start, $end, $strand ) = @_;
  $type   ||= $self->seq_region_type;
  $region ||= $self->seq_region_name;
  $start  ||= $self->seq_region_start;
  $end    ||= $self->seq_region_end;
  $strand ||= $self->seq_region_strand;

  my $key = join '::', $type, $region, $start, $end, $strand;
  unless ($self->__data->{'slice_cache'}{$key}) {
    $self->__data->{'slice_cache'}{$key} =
      $self->database('core')->get_SliceAdaptor()->fetch_by_region(
        $type, $region, $start, $end, $strand
      );
  }
  return $self->__data->{'slice_cache'}{$key};
}


sub current_pop_id {
  my $self = shift; 
  
  my %pops_on = map { $self->param("pop$_") => $_ } grep s/^pop(\d+)$/$1/, $self->param;

  return [keys %pops_on]  if keys %pops_on;
  my $default_pop =  $self->get_default_pop_name;
  warn "*****[ERROR]: NO DEFAULT POPULATION DEFINED.\n\n" unless $default_pop;
  return ( [$default_pop], [] );
}


sub pops_for_slice {

   ### Example : my $data = $self->DataObj->ld_for_slice;
   ### Description : returns all population IDs with LD data for this slice
   ### Returns hashref of population dbIDs

  my $self = shift;
  my $width  = shift || 100000;

  my $ld_container = $self->ld_for_slice(undef, $width);
  return [] unless $ld_container;

  my $pop_ids = $ld_container->get_all_populations();
  return [] unless @$pop_ids;

  my @pops;
  foreach (@$pop_ids) {
    my $name = $self->pop_name_from_id($_);
    push @pops, $name;
  }

  my @tmp_sorted =  sort {$a cmp $b} @pops;
  return \@tmp_sorted;
}

sub get_source {
  my $self = shift;

  my $vari_adaptor = $self->database('variation')->get_db_adaptor('variation');
  unless ($vari_adaptor) {
    warn "ERROR: Can't get variation adaptor";
    return ();
  }
  return $vari_adaptor->get_VariationAdaptor->get_all_sources();
}

sub get_all_misc_sets {
  my $self = shift;
  my $temp  = $self->database('core')->get_db_adaptor('core')->get_MiscSetAdaptor()->fetch_all;
  my $result = {};
  foreach( @$temp ) {
    $result->{$_->code} = $_;
  }
  return $result;
}

sub get_ld_values {
  my $self = shift;
  my ($populations, $snp) = @_;
  
  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE     = $self->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::VCF_BINARY_FILE = $self->species_defs->ENSEMBL_LD_VCF_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH        = $self->species_defs->ENSEMBL_TMP_TMP;
  
  my %ld_values;
  my $display_zoom = $self->round_bp($self->seq_region_end - $self->seq_region_start);

  foreach my $pop_name (sort split (/\|/, $populations)) {
    my $pop_obj = $self->pop_obj_from_name($pop_name);
    
    next unless $pop_obj;
    
    my $pop_id = $pop_obj->{$pop_name}{'dbID'};
    my $data = $self->ld_for_slice($pop_obj->{$pop_name}{'PopObject'});
    
    foreach my $ld_type ('r2', 'd_prime') {
      my $display = $ld_type eq 'r2' ? 'r2' : "D'";
      my $no_data = "No $display linkage data in $display_zoom window for population $pop_name";
      
      unless (%$data && keys %$data) {
        $ld_values{$ld_type}{$pop_name}{'text'} = $no_data;
        next;
      }


      my $pos2vf = $data->_pos2vf();
      my @snp_list = map { [ $_, $pos2vf->{$_} ] } sort {$a <=> $b} keys %$pos2vf;

      unless (scalar @snp_list) {
        $ld_values{$ld_type}{$pop_name}{'text'} = $no_data;
        next;
      }

      # Do each column starting from 1 because first col is empty
      my @table;
      my $flag = 0;
      
      for (my $x = 0; $x < scalar @snp_list; $x++) { 
        # Do from left side of table row across to current snp
        for (my $y = 0; $y < $x; $y++) {
          my $ld_pair1 = "$snp_list[$x]->[0]" . -$snp_list[$y]->[0];
          my $ld_pair2 = "$snp_list[$y]->[0]" . -$snp_list[$x]->[0];
          my $cell;
          
          if ($data->{'ldContainer'}{$ld_pair1}) {
            $cell = $data->{'ldContainer'}{$ld_pair1}{$pop_id}{$ld_type};
          } elsif ($data->{'ldContainer'}{$ld_pair2}) {
            $cell = $data->{'ldContainer'}{$ld_pair2}{$pop_id}{$ld_type};
          }
          
          $flag = $cell ? 1 : 0 unless $flag;
          $table[$x][$y] = $cell;
        }
      }
      
      unless ($flag) {
        $ld_values{$ld_type}{$pop_name}{'text'} = $no_data;
        next;
      }

      # Turn snp_list from an array of variation_feature IDs to SNP 'rs' names
      # Make current SNP bold
      my @snp_names;
      my @starts_list;
      
      foreach (@snp_list) {
        my $name = $_->[1]->variation_name;
        
        if ($name eq $snp || $name eq "rs$snp") {
          push (@snp_names, "*$name*");
        } else { 
          push (@snp_names, $name);
        }

        my ($start, $end) = ($_->[1]->start, $_->[1]->end);
        my $pos = $start;
        
        if ($start > $end) {
          $pos = "between $start & $end";
        } elsif ($start < $end) {
          $pos = "$start-$end";
        }
        
        push (@starts_list, $pos);
      }

      my $location = $self->seq_region_name . ':' . $self->seq_region_start . '-' . $self->seq_region_end;
      
      $ld_values{$ld_type}{$pop_name}{'text'} = "Pairwise $display values for $location. Population: $pop_name";
      $ld_values{$ld_type}{$pop_name}{'data'} = [ \@starts_list, \@snp_names, \@table ];
    }
  }
  
  return \%ld_values;
}

#------ Sample stuff ------------------------------------------------

sub sample_genotypes {

  ### sample_table_calls
  ### Arg1: variation feature object
  ### Example    : my $sample_genotypes = $object->sample_table;
  ### Description: gets Sample Genotype data for this variation
  ### Returns hashref with all the data

  my ($self, $vf, $slice_genotypes) = @_;
  if (! defined $slice_genotypes->{$vf->seq_region_name.'-'.$vf->seq_region_start}){
      return {};
  }
  my $sample_genotypes = $slice_genotypes->{$vf->seq_region_name.'-'.$vf->seq_region_start};
  return {} unless @$sample_genotypes; 
  my %data = ();
  my %genotypes = ();

  my %gender = qw (Unknown 0 Male 1 Female 2 );
  foreach my $sample_gt_obj ( @$sample_genotypes ) { 
    my $sample_obj = $sample_gt_obj->sample;
    next unless $sample_obj;

    # data{name}{AA}
    #we should only consider 1 base genotypes (from compressed table)
    next if ( CORE::length($sample_gt_obj->allele1) > 1 || CORE::length($sample_gt_obj->allele2)>1);
    foreach ($sample_gt_obj->allele1, $sample_gt_obj->allele2) {
      my $allele = $_ =~ /A|C|G|T|N/ ? $_ : "N";
      $genotypes{ $sample_obj->name }.= $allele;
    }
    $data{ $sample_obj->name }{gender} = $gender{$sample_obj->individual->gender} || 0;
    $data{ $sample_obj->name }{mother} = $self->parent($sample_obj->individual, "mother");
    $data{ $sample_obj->name }{father} = $self->parent($sample_obj->individual, "father");
  }
  return \%genotypes, \%data;
}


sub parent {

  ### Individual_genotype_table_calls
  ### Args1      : Bio::EnsEMBL::Variation::Individual object
  ### Arg2      : string  "mother" "father"
  ### Example    : $mother = $object->parent($individual, "mother");
  ### Description: gets name of parent if known
  ### Returns string (name of parent if known, else 0)

  my ($self, $ind_obj, $type)  = @_;
  my $call =  $type. "_Individual";
  my $parent = $ind_obj->$call;
  return 0 unless $parent;
  return $parent->name || 0;
}


sub get_all_genotypes{
  my $self = shift;

  my $slice = $self->slice_cache;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $sga = $variation_db->get_SampleGenotypeAdaptor;
  my $genotypes = $sga->fetch_all_by_Slice($slice);
  #will return genotypes as a hash, having the region_name-start as key for rapid acces
  my $genotypes_hash = {};
  foreach my $genotype (@{$genotypes}){
    push @{$genotypes_hash->{$genotype->seq_region_name.'-'.$genotype->seq_region_start}},$genotype;
  }
  return $genotypes_hash;
}

sub can_export {
  my $self = shift;
  return $self->action =~ /^(Export|Chromosome|Genome|Synteny|Compara_Alignments)$/ ? 0 : $self->availability->{'slice'};
}

sub multi_locations {
  my $self = shift;
  
  my $locations = [];

  if ($self->hub->param('export')) {
    ## Force creation of the data, if coming from an export form
    my $factory = $self->hub->builder->create_factory('MultipleLocation');
    my $location = $factory->DataObjects->{'Location'}[0];
    $locations  = $location->{'data'}{'_multi_locations'} || [];
  }
  else {
    $locations = $self->{'data'}{'_multi_locations'} || [];
  }

  if (!scalar @$locations) {
    my $slice = $self->slice;
    
    push @$locations, {      
      slice         => $slice,
      species       => $self->species,
      target        => $slice->seq_region_name,
      species_check => $self->species,
      name          => $slice->seq_region_name,
      short_name    => $self->chr_short_name,
      start         => $slice->start,
      end           => $slice->end,
      strand        => $slice->strand,
      length        => $slice->seq_region_length
    }
  }
  
  return $locations;
}

# generate short caption name
sub chr_short_name {
  my $self = shift;
  
  my $slice   = shift || $self->slice;
  my $species = shift || $self->species;
  
  my $type = $slice->coord_system_name;
  my $chr_name = $slice->seq_region_name;
  my $chr_raw = $chr_name;
  
  my %short = (
    chromosome  => 'Chr.',
    supercontig => "S'ctg",
    plasmid => 'Pla.',
  );
  
  if ($chr_name !~ /^$type/i) {
    $type = $short{lc $type} || ucfirst $type;
    $chr_name = "$type $chr_name";
  }
  
  $chr_name = $chr_raw if CORE::length($chr_name) > 9;
  
  (my $abbrev = $species) =~ s/^(\w)\w+_(\w{3})\w+$/$1$2/g;
  $abbrev ||= $species;

  return "$abbrev $chr_name";
}

sub sorted_marker_features {
  my ($self, $marker) = @_;
  
  my $c = 1000;
  my %sort = map { $_, $c-- } @{$self->species_defs->ENSEMBL_CHROMOSOMES || []};
  my @marker_features = ref $marker eq 'ARRAY' ? map @{$_->get_all_MarkerFeatures || []}, @$marker : @{$marker->get_all_MarkerFeatures || []};
  
  return map $_->[-1], sort { 
    ($sort{$b->[0]} <=> $sort{$a->[0]} || $a->[0] cmp $b->[0]) || 
    $a->[1] <=> $b->[1] || 
    $a->[2] <=> $b->[2] 
  } map [ $_->seq_region_name, $_->start, $_->end, $_ ], @marker_features;
}

## Allele/genotype colours
sub get_allele_genotype_colours {
  my $self = shift;

  my %colours = ('A' => '<span style="color:green">A</span>',
                 'C' => '<span style="color:blue">C</span>',
                 'G' => '<span style="color:#ff9000">G</span>',
                 'T' => '<span style="color:red">T</span>'
                );
  return \%colours;
}

# Return alignments based on hierarchy of methods
sub filter_alignments_by_method {
  my $self       = shift;
  my $alignments = shift || {};

  # Convert hash with species_set_id as the keys
  my $transform  = shift;
  my $methods_hierarchy = $self->hub->species_defs->ENSEMBL_ALIGNMENTS_HIERARCHY;

  my $available_alignments = {};

  foreach my $align_id (keys %$alignments) {
    push @{$available_alignments->{$alignments->{$align_id}{'species_set_id'}}}, $alignments->{$align_id};
  }

  my $final_alignments = {};

  my $ss_id_hash_flag = {};
  my ($alignment, $method, $re, $i, $j, $ss_id);

  foreach $ss_id (keys %$available_alignments) {
    for ($i=0; $i<=$#$methods_hierarchy; $i++) {
      $method = $methods_hierarchy->[$i];
      $re = qr /$method/i;
      for ($j=0; $j<=$#{$available_alignments->{$ss_id}}; $j++) {
        $alignment = $available_alignments->{$ss_id}->[$j];
        # If type found and if no previous alignments assigned then proceed
        if ($alignment->{type} =~ $re && !$ss_id_hash_flag->{$ss_id}) {
          $final_alignments->{$alignment->{'id'}} = $alignment;
          $ss_id_hash_flag->{$ss_id} = 1;
          last;
        }

        # Assign any alignment that does not match the conditions above.
        if (!$ss_id_hash_flag->{$alignment->{'species_set_id'}} && $i == $#$methods_hierarchy && $j == $#{$available_alignments->{$ss_id}}) {
          $final_alignments->{$alignment->{'id'}} = $alignment;
          $ss_id_hash_flag->{$alignment->{'species_set_id'}} = 1;
          last;
        }
      }

      if ($final_alignments->{$alignment->{'id'}}) {
        last;
      }
    }
  }
  return $final_alignments || $alignments;
}

1;
