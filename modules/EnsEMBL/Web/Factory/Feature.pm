package EnsEMBL::Web::Factory::Feature;

### NAME: EnsEMBL::Web::Factory::Feature
### Creates a hash of API objects

### STATUS: Under development

### DESCRIPTION:

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Data::Bio::Gene;
use EnsEMBL::Web::Data::Bio::Transcript;
use EnsEMBL::Web::Data::Bio::Variation;
use EnsEMBL::Web::Data::Bio::ProbeFeature;
use EnsEMBL::Web::Data::Bio::AlignFeature;

use base qw(EnsEMBL::Web::Factory);

sub createObjects {  
  my $self = shift;
  my $hub = $self->hub;
  my $features = {};
  my $feature_type;

  my $db = $hub->param('db')  || 'core';
  my ($identifier, $fetch_call, $featureobj, $dataobject, $subtype);

  ## Are we inputting IDs or searching on a text term?
  if ($hub->param('xref_term')) {
    my @exdb = $hub->param('xref_db');
    $features = $self->search_Xref($db, \@exdb, $self->param('xref_term'));
  }
  else {
    if ($hub->type eq 'LRG') {
      $feature_type = 'LRG';
    }
    else {
      $feature_type  = $hub->param('ftype') || $hub->param('type') || 'ProbeFeature';
    }
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
    $features    = defined &$create_method ? $self->$create_method($db, $subtype) : [];
  }
  return unless $features && ref($features) eq 'HASH' && keys %$features;

  $self->DataObjects($features);
}

sub _create_Domain {
### Fetches all the genes for a domain
  my ($self, $db) = @_;
  my $id  = $self->hub->param('id');
  my $dbc = $self->hub->database($db);
  my $a   = $dbc->get_adaptor('Gene');
  my $genes = $a->fetch_all_by_domain($id);
  return unless $genes && ref($genes) eq 'ARRAY';
  return {'Gene' => EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes)};
}

sub _create_Phenotype {
### Fetches all the variation features associated with a phenotype
  my ($self, $db) = @_; 
  my $slice;
  my $features;
  my $array = [];
  my $id = $self->hub->param('id');

  my @chrs = @{$self->hub->species_defs->ENSEMBL_CHROMOSOMES};

  foreach my $chr (@chrs) {
    $slice = $self->hub->database('core')->get_adaptor('Slice')->fetch_by_region("chromosome", $chr);
    my $array2 = $slice->get_all_VariationFeatures_with_annotation(undef, undef, $id);

    push(@$array,@$array2) if (@$array2);
  }
  return {'Variation' => EnsEMBL::Web::Data::Bio::Variation->new($self->hub, @$array)};
}

sub _create_ProbeFeature {
  # get Oligo hits plus corresponding genes
  my $probe;
  if ( $_[2] eq 'pset'){
    $probe = $_[0]->_generic_create( 'ProbeFeature', 'fetch_all_by_probeset', $_[1] );
  } else {
    $probe = $_[0]->_create_ProbeFeatures_by_probe_id;
  }
  #my $probe_trans = $_[0]->_generic_create( 'Transcript', 'fetch_all_by_external_name', $_[1], undef, 'no_errors' );
  my $probe_trans = $_[0]->_create_ProbeFeatures_linked_transcripts($_[2]);
  my $features = {'ProbeFeature' => EnsEMBL::Web::Data::Bio::ProbeFeature->new($_[0]->hub, @$probe)};
  if ($probe_trans) {
    $features->{'Transcript'} = EnsEMBL::Web::Data::Bio::Transcript->new($_[0]->hub, @$probe_trans);
  }
  return $features;
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
  my $hub = $self->hub;
  my $db = $hub->param('db');
  if ($hub->param('fdb')) { $db = $hub->param('fdb');}
  my $db_adaptor  = $self->database(lc($db));
  unless( $db_adaptor ){
    $self->problem( 'Fatal', 'Database Error', "Could not connect to the $db database." );
    return undef;
  }
  return $db_adaptor;
}

sub _get_core_adaptor {
  my $self = shift;
  my $db_adaptor  = $self->hub->database('core');
  unless( $db_adaptor ){
    $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." );
    return undef;
  }
  return $db_adaptor;
}

sub _create_DnaAlignFeature {
  my ($self, $args) = @_;
  warn "@@@ CREATING DNA ALIGN FEATURES";
  my $daf = $self->_generic_create( 'DnaAlignFeature', 'fetch_all_by_hit_name', $args);
  warn ">> DAF = ".@$daf;
  my $features = {'DnaAlignFeature' => EnsEMBL::Web::Data::Bio::AlignFeature->new($self->hub, @$daf)};
  warn ">>> FEATURES $features";
  my $genes = $self->_generic_create( 'Gene', 'fetch_all_by_external_name', $args, undef, 'no_errors' );
  if ($genes) {
    $features->{'Gene'} = EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes);
  }
  while (my($k,$v) = each (%$features)) {
    warn ">>> $k = $v";
  } 
  return $features;
}

sub _create_ProteinAlignFeature {
  my ($self, $args) = @_;
  my $paf = $self->_generic_create( 'ProteinAlignFeature', 'fetch_all_by_hit_name', $args);
  my $features = {'ProteinAlignFeature' => EnsEMBL::Web::Data::Bio::AlignFeature->new($self->hub, @$paf)};
  my $genes = $self->_generic_create( 'Gene', 'fetch_all_by_external_name', $args, undef, 'no_errors' );
  if ($genes) {
    $features->{'Gene'} = EnsEMBL::Web::Data::Bio::Gene->new($self->hub, @$genes);
  }
  return $features;
}

sub create_UserDataFeature {
  my ($self, $logic_name) = @_;
  my $dbs      = EnsEMBL::Web::DBSQL::DBConnection->new( $self->species );
  my $dba      = $dbs->get_DBAdaptor('userdata');
  my $features = [];
  return [] unless $dba;

  $dba->dnadb($self->database('core'));

  ## Have to do the fetch per-chromosome, since API doesn't have suitable call
  my $chrs = $self->species_defs->ENSEMBL_CHROMOSOMES;
  foreach my $chr (@$chrs) {
    my $slice = $self->database('core')->get_SliceAdaptor()->fetch_by_region(undef, $chr);
    if ($slice) {
      my $dafa     = $dba->get_adaptor( 'DnaAlignFeature' );
      my $F = $dafa->fetch_all_by_Slice($slice, $logic_name );
      push @$features, @$F;
    }
  }
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

  if ($analysis eq 'RegulatoryRegion'){
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

sub _create_LRG {
  my $self = shift;
  my $db_adaptor  = $self->hub->database('core');
  unless( $db_adaptor ){
    $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." );
    return undef;
  }
  my $adaptor = $db_adaptor->get_SliceAdaptor;
  my $slices = [];
  if ($self->hub->param('id')) {
    my @ids = ($self->hub->param('id'));
    foreach my $id (@ids) {
      push @$slices, $adaptor->fetch_by_region('lrg', $id);
    }
  }
  else {
    $slices = $adaptor->fetch_all('lrg');
  }
  return {'Slice' => $slices};
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
      $self->problem( 'Fatal', 'Database Error', "Could not connect to the $db database." );
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

1;

