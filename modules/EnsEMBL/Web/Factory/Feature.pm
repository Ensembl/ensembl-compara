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

package EnsEMBL::Web::Factory::Feature;

### NAME: EnsEMBL::Web::Factory::Feature
### Creates a hash of API objects to be displayed on a karyotype or chromosome

### STATUS: Under development

### DESCRIPTION:
### This factory creates data for "featureview", i.e. a display of data over a 
### large region such as a whole chromosome or even the entire genome. 
### Unlike most Factories it does not create  a single domain object but a hash i
### of key-value pairs, e.g.:
### {'Gene' => Data::Bio::Gene, 'ProbeFeature' => Data::Bio::ProbeFeature};

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Data::Bio::Slice;
use EnsEMBL::Web::Data::Bio::Gene;
use EnsEMBL::Web::Data::Bio::Transcript;
use EnsEMBL::Web::Data::Bio::Variation;
use EnsEMBL::Web::Data::Bio::ProbeFeature;
use EnsEMBL::Web::Data::Bio::ProbeTranscript;
use EnsEMBL::Web::Data::Bio::AlignFeature;
use EnsEMBL::Web::Data::Bio::RegulatoryFeature;
use EnsEMBL::Web::Data::Bio::RegulatoryFactor;
use EnsEMBL::Web::Data::Bio::Xref;
use EnsEMBL::Web::Data::Bio::LRG;

use base qw(EnsEMBL::Web::Factory);

sub createObjects {  
  ### Identifies the type of API object(s) required, based on CGI parameters,
  ### and calls the relevant helper method to create them.
  ### Arguments: None
  ### Returns: undef (data is put into Factory->DataObjects, from where it can
  ### be retrieved by the Model)
  
  my $self     = shift;
  my $db       = $self->param('db') || 'core';
  my $features = {};
  my ($feature_type, $subtype);
  
  ## Are we inputting IDs or searching on a text term?
  if ($self->param('xref_term')) {
    my @exdb  = $self->param('xref_db');
    $features = $self->search_Xref($db, \@exdb, $self->param('xref_term'));
  } else {
    if ($self->hub->type eq 'LRG') {
      $feature_type = 'LRG';
    } else {
      $feature_type = $self->param('ftype') || $self->param('type') || $self->hub->type;
    }
    
    if ($self->param('ftype') eq 'ProbeFeature') {
      $db      = 'funcgen';
      $subtype = $self->param('ptype') if $self->param('ptype');
    }
    
    ## deal with xrefs
    if ($feature_type =~ /^Xref_/) {
      ## Don't use split here - external DB name may include underscores!
      ($subtype = $feature_type) =~ s/Xref_//;
      $feature_type = 'Xref';
    }

    my $func  = "_create_$feature_type";
    $features = $self->can($func) ? $self->$func($db, $subtype) : {};
  }
  
  $self->DataObjects($self->new_object('Feature', $features, $self->__data)) if keys %$features;
}

sub _create_Domain {
  ### Fetches all the genes for a given domain
  ### Args: db
  ### Returns: hashref of API objects
  
  my ($self, $db) = @_;
  my $id          = $self->param('id');
  my $dbc         = $self->hub->database($db);
  my $a           = $dbc->get_adaptor('Gene');
  my $genes       = $a->fetch_all_by_domain($id);
  
  return unless $genes && ref($genes) eq 'ARRAY';
  return {'Gene' => EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes)};
}

sub _create_Phenotype {
  ### Fetches all the variation features associated with a phenotype
  ### Args: db 
  ### Returns: hashref of API objects
  
  my ($self, $db) = @_;
  
  my $id         = $self->param('id');   
  my $dbc        = $self->hub->database('variation');
  my $a          = $dbc->get_adaptor('VariationFeature');
  my $func       = $self->param('somatic') ? 'fetch_all_somatic_with_phenotype' : 'fetch_all_with_phenotype';
  my $variations = $a->$func(undef, undef, $id);
  
  return unless $variations and scalar @$variations > 0; 
  return { 'Variation' => EnsEMBL::Web::Data::Bio::Variation->new($self->hub, @$variations) };
}

sub _create_ProbeFeature {
  ### Fetches Oligo hits plus corresponding transcripts
  ### Args: db, subtype (string)
  ### Returns: hashref of API objects
  
  my ($self, $db, $subtype)  = @_;
  my $db_adaptor  = $self->_get_funcgen_db_adaptor; 
  my $pf_adaptor  = $db_adaptor->get_ProbeFeatureAdaptor;

  my $method    = $subtype && $subtype eq 'pset' ? 'fetch_all_by_array_name_probeset_name' : 'fetch_all_by_array_name_probe_name';
  my $probe     = $pf_adaptor->$method($self->param('array'), $self->param('id'));   
  my $features  = { ProbeFeature => EnsEMBL::Web::Data::Bio::ProbeFeature->new($self->hub, @$probe) };

  my $probe_trans = $self->_create_ProbeFeatures_linked_transcripts($subtype);
  $features->{'ProbeTranscript'} = EnsEMBL::Web::Data::Bio::ProbeTranscript->new($self->hub, @$probe_trans) if $probe_trans;
  
  return $features;
}

sub _create_ProbeFeatures_linked_transcripts {
  ### Helper method called by _create_ProbeFeature
  ### Fetches the transcript(s) linked to a probeset
  ### Args: $ptype (string)
  ### Returns: arrayref of Bio::EnsEMBL::Transcript objects
  
  my ($self, $ptype) = @_;
  my $db_adaptor     = $self->_get_funcgen_db_adaptor;
  
  my (@probe_objs, @db_entries, @mappings, %seen);

  if ($ptype eq 'pset') {
    my $id = $self->param('id');
    my $probe_set_adaptor = $db_adaptor->get_ProbeSetAdaptor;
    my $probe_set = shift @{$probe_set_adaptor->fetch_all_by_name($id)};
    @db_entries = $probe_set ? @{$probe_set->get_all_ProbeSetTranscriptMappings} : ();
  } else {
    my $probe_adaptor = $db_adaptor->get_ProbeAdaptor;
    @probe_objs = @{$probe_adaptor->fetch_all_by_name($self->param('id'))};
    foreach my $probe (@probe_objs) {
      my @entries = @{$probe->get_all_ProbeTranscriptMappings};
      push(@db_entries, @entries);
    }
  }

  ## Now retrieve transcript ID and create transcript Objects 
  foreach my $entry (@db_entries) {
    my $core_db_adaptor    = $self->_get_core_adaptor;
    my $transcript_adaptor = $core_db_adaptor->get_TranscriptAdaptor;

    if (!exists $seen{$entry->stable_id}) {
      my $transcript = $transcript_adaptor->fetch_by_stable_id($entry->stable_id);
      push @mappings, {'Mapping' => $entry, 'Transcript' => $transcript} if $transcript;
      $seen{$entry->stable_id} = 1;
    }
  }

  return \@mappings;
}

sub _get_funcgen_db_adaptor {
  ### Helper method used by _create_ProbeFeatures_linked_transcripts
  ### Args: none
  ### Returns: database adaptor
  
  my $self        = shift;
  my $db          = $self->param('fdb') || $self->param('db');
  my $db_adaptor  = $self->database(lc $db);
  
  if (!$db_adaptor) {
    $self->problem('fatal', 'Database Error', "Could not connect to the $db database.");
    return undef;
  }
  
  return $db_adaptor;
}

sub _get_core_adaptor {
  ### Helper method used by _create_ProbeFeatures_linked_transcripts
  ### Args: none
  ### Returns: database adaptor
  
  my $self       = shift;
  my $db_adaptor = $self->hub->database('core');
  
  if (!$db_adaptor) {
    $self->problem('fatal', 'Database Error', 'Could not connect to the core database.');
    return undef;
  }
  
  return $db_adaptor;
}

sub _create_DnaAlignFeature {
  ### Fetches all the DnaAlignFeatures with a given ID, and associated genes
  ### Args: db
  ### Returns: hashref of API objects
  
  my ($self, $db) = @_;
  my $hub = $self->hub;
  my $daf = [];
  if ($hub->param('logic_name')) {
    my $db_adaptor = $self->database(lc $db);
    if (!$db_adaptor) {
      $self->problem('fatal', 'Database Error', "Could not connect to the $db database.");
      return undef;
    }
    else {
      my $slice = $db_adaptor->get_SliceAdaptor->fetch_by_region('chromosome', $hub->param('id'));
      $daf = $slice->get_all_DnaAlignFeatures($hub->param('logic_name'));
    }
  }
  else {
    $daf = $self->_generic_create('DnaAlignFeature', 'fetch_all_by_hit_name', $db);
  }
  my $genes = $self->_generic_create('Gene', 'fetch_all_by_external_name', $db, undef, 'no_errors');
  my $features    = { DnaAlignFeature => EnsEMBL::Web::Data::Bio::AlignFeature->new($hub, @$daf) };
  
  $features->{'Gene'} = EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes) if $genes;
  
  return $features;
}

sub _create_ProteinAlignFeature {
  ### Fetches all the DnaAlignFeatures with a given ID, and associated genes
  ### Args: db
  ### Returns: hashref of API objects
  my ($self, $db) = @_;
  my $paf         = $self->_generic_create('ProteinAlignFeature', 'fetch_all_by_hit_name', $db);
  my $genes       = $self->_generic_create('Gene', 'fetch_all_by_external_name', $db, undef, 'no_errors');
  my $features    = { ProteinAlignFeature => EnsEMBL::Web::Data::Bio::AlignFeature->new($self->hub, @$paf) };
  
  $features->{'Gene'} = EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes) if $genes;
  
  return $features;
}

sub _create_Gene {
  ### Fetches all the genes for a given identifier 
  ### Args: db
  ### Returns: hashref containing a Data::Bio::Gene object
  
  my ($self, $db) = @_;

  ## Default to checking by external name (check for stable IDs in _generic_create)
  my $genes       = $self->_generic_create('Gene', 'fetch_all_by_external_name', $db);
  
  return { Gene => EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes) };
}

sub _create_RegulatoryFactor {
  ### Fetches all the regulatory features for a given regulatory factor ID 
  ### Args: db, id (optional)
  ### Returns: hashref containing a Data::Bio::RegulatoryFeature object
  
  my ($self, $db, $id) = @_;
  my $fg_db            = $self->hub->database('funcgen');
  
  if (!$fg_db) {
     warn('Cannot connect to funcgen db');
     return undef;
  }
  
  $id ||= $self->param('id');
  
  my $features = $fg_db->get_ExternalFeatureAdaptor->fetch_all_by_display_label($id) || [];
  if (!@$features) {
    unless ($self->param('fset')) {
      $self->problem('fatal', 'No identifier', "No feature set provided.");
      return undef;
    }
    if ($self->param('fset') =~ /TarBase/) {
      my $mirna_adaptor = $fg_db->get_MirnaTargetFeatureAdaptor;
      $features = $mirna_adaptor->fetch_all_by_display_label($id);
    }
    else {
      my $fset  = $fg_db->get_featureSetAdaptor->fetch_by_name($self->param('fset'));
      my $ftype = $fg_db->get_FeatureTypeAdaptor->fetch_by_name($id);
      ## Defensive programming against API barfs
      if (ref($ftype)) {
        $features = $fset->get_Features_by_FeatureType($ftype);
      }
      else {
        warn ">>> UNKNOWN FEATURE TYPE";
      }
    }
  }

  if (@$features) {
    return { RegulatoryFeature => EnsEMBL::Web::Data::Bio::RegulatoryFeature->new($self->hub, @$features) }
  } else {
    # We have no features so return an error
    $self->problem('no_match', 'Invalid Identifier', "Regulatory Factor $id was not found");
    return undef;
  }
}

sub _create_Xref {
  ### Fetches Xrefs plus corresponding genes
  ### Args: db, subtype (string)
  ### Returns: hashref of API objects
  
  my ($self, $db, $subtype) = @_;
  my $t_features            = [];
  my ($xrefs, $genes); 

  if ($subtype eq 'MIM') {
    my $mim_g    = $self->_generic_create('DBEntry', 'fetch_by_db_accession', [ $db, 'MIM_GENE'   ]);
    my $mim_m    = $self->_generic_create('DBEntry', 'fetch_by_db_accession', [ $db, 'MIM_MORBID' ]);
    @$t_features = (@$mim_g, @$mim_m);
  }  else {
    $t_features = $self->_generic_create('DBEntry', 'fetch_by_db_accession', [ $db, $subtype ]);
  }
  
  ($xrefs, $genes) = $self->_create_XrefArray($t_features, $db, $subtype) if $t_features && ref $t_features eq 'ARRAY';
  
  my $features = { Xref => EnsEMBL::Web::Data::Bio::Xref->new($self->hub, @$xrefs) };
  $features->{'Gene'} = EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes) if $genes;
  
  return $features;
}

sub _create_XrefArray {
  ### Helper method used by _create_Xref
  
  my ($self, $t_features, $db, $subtype) = @_;
  my (@features, @genes);

  foreach my $t (@$t_features) { 
    my @matches = ($t); ## we need to keep each xref and its matching genes together
    my $id      = $t->primary_id;
    my $t_genes = $self->_generic_create('Gene', 'fetch_all_by_external_name', $db, $id, 'no_errors', $subtype); ## get genes for each xref
    
    if ($t_genes && @$t_genes) { 
      push @matches, @$t_genes;
      push @genes, @$t_genes;
    }
    
    push @features, \@matches;
  }

  return (\@features, \@genes);
}

sub _create_LRG {
  ### Fetches LRG region(s)
  ### Args: none
  ### Returns: hashref containing Bio::EnsEMBL::Slice objects
  my $self       = shift;
  my $hub        = $self->hub;
  my $db_adaptor = $hub->database('core');
  
  if (!$db_adaptor) {
    $self->problem('fatal', 'Database Error', 'Could not connect to the core database.');
    return undef;
  }
  
  ## Get LRG slices
  my $sa     = $db_adaptor->get_SliceAdaptor;
  my $slices = [];
  my @ids    = $self->param('id');
  
  if (@ids && $ids[0]) {
    push @$slices, $sa->fetch_by_region('lrg', $_) for @ids;
  } else {
    $slices = $sa->fetch_all('lrg', undef, 1, undef, 1);
  }
 
  ## Map slices to chromosomal coordinates
  my $mapped_slices = [];
  my $csa           = $hub->database('core',$hub->species)->get_CoordSystemAdaptor;
  my $ama           = $hub->database('core', $hub->species)->get_AssemblyMapperAdaptor;
  my $old_cs        = $csa->fetch_by_name('lrg');
  my $new_cs        = $csa->fetch_by_name('chromosome', $hub->species_defs->ASSEMBLY_VERSION);
  my $mapper        = $ama->fetch_by_CoordSystems($old_cs, $new_cs);

  foreach my $s (@$slices) {
    my @coords = $mapper->map($s->seq_region_name, $s->start, $s->end, $s->strand, $old_cs);
    for (@coords) {
      next if (ref($_) eq 'Bio::EnsEMBL::Mapper::Gap'); 
      push @$mapped_slices, { lrg => $s, chr => $sa->fetch_by_seq_region_id($_->id, $_->start, $_->end) };
    }
  }
 
  return { LRG => EnsEMBL::Web::Data::Bio::LRG->new($self->hub, @$mapped_slices) };
}

sub _generic_create {
  ### Helper method used by various _create_ methods to get API objects from the database
  
  my ($self, $object_type, $accessor, $db, $id, $flag, $subtype) = @_;  
  $db ||= 'core';
  
  if (!$id) {
    my @ids = $self->param('id');
    $id = join ' ', @ids;
  } elsif (ref $id eq 'ARRAY') {
    $id = join ' ', @$id;
  }
  
  
  ## deal with xrefs
  my $xref_db;
  
  if ($object_type eq 'DBEntry') {
    my @A    = @$db;
    $db      = $A[0];
    $xref_db = $A[1];
  }

  if( !$id) {
    return undef; # return empty object if no id
  } else {
    # Get the 'central' database (core, est, vega)
    my $db_adaptor = $self->database(lc $db);
    
    if (!$db_adaptor) {
      $self->problem('fatal', 'Database Error', "Could not connect to the $db database.");
      return undef;
    }
    
    my $adaptor_name = "get_${object_type}Adaptor";
    my $features     = [];
    
    $id =~ s/,/ /g;
    $id =~ s/\s+/ /g;
    $id =~ s/^ //;
    $id =~ s/ $//;
    
    foreach my $fid (split /\s+/, $id) { 
      my $t_features;
      
      if ($xref_db) { 
        eval {
         $t_features = [$db_adaptor->$adaptor_name->$accessor($xref_db, $fid)];
        };
      } elsif ($subtype) {
        eval {
         $t_features = $db_adaptor->$adaptor_name->$accessor($fid, $subtype);
        };
      } else {

        ## Check for gene stable IDs
        my $gene_stable_id = 0;
        if ($object_type eq 'Gene') {
          my ($species, $obj_type) = Bio::EnsEMBL::Registry->get_species_and_object_type($fid); 
          $gene_stable_id = 1 if ($species && $obj_type && $obj_type eq 'Gene');
        }

        if ($gene_stable_id) { ## Hack to get gene stable IDs to work
          $accessor = 'fetch_by_stable_id';
          eval {
            $t_features = [ $db_adaptor->$adaptor_name->$accessor($fid) ];
          };
        } else { 
          eval {
           $t_features = $db_adaptor->$adaptor_name->$accessor($fid);
          };
        }
      }
      
      ## if no result, check for unmapped features
      if ($t_features && ref($t_features) eq 'ARRAY') {
        if (!@$t_features) {
          my $uoa = $db_adaptor->get_UnmappedObjectAdaptor;
          $t_features = $uoa->fetch_by_identifier($fid);
        } else {
          foreach my $f (@$t_features) {
            next unless $f;
            
            $f->{'_id_'} = $fid;
            push @$features, $f;
          }
        }
      }
    }
    
    return $features if $features && @$features; # Return if we have at least one feature

    # We have no features so return an error
    $self->problem('no_match', 'Invalid Identifier', "$object_type $id was not found") unless $flag eq 'no_errors';
    
    return undef;
  }
}

1;
