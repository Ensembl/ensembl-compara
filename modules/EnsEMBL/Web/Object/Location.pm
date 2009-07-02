package EnsEMBL::Web::Object::Location;

use strict;
use warnings;
no warnings "uninitialized";
use Data::Dumper;
use POSIX qw(floor ceil);
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Cache;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Object);

sub _filename {
  my $self = shift;
  my $name = sprintf '%s-%d-%s_%s_%s_%s',
    $self->species,
    $self->species_defs->ENSEMBL_VERSION,
    $self->Obj->{seq_region_name},
    $self->Obj->{seq_region_start},
    $self->Obj->{seq_region_end},
    $self->Obj->{seq_region_strand};

  $name =~ s/[^-\w\.]/_/g;
  return $name;
}

sub availability {
  my $self = shift;
  my $hash = $self->_availability;
  my %chrs = map { $_,1 } @{$self->species_defs->ENSEMBL_CHROMOSOMES || []};
  $hash->{'karyotype'}   = 1;
  $hash->{'chromosome'}  = $chrs{ $self->Obj->{'seq_region_name'} } ? 1 : 0;
  $hash->{'has_chromosomes'} = @{$self->species_defs->ENSEMBL_CHROMOSOMES || []} ? 1 : 0;
  $hash->{'has_strains'} = 
    exists $self->species_defs->databases->{'DATABASE_VARIATION'} &&
    $self->species_defs->databases->{'DATABASE_VARIATION'}{'#STRAINS'} ? 1 : 0;
  $hash->{'slice'}       = $self->Obj->{'seq_region_name'} && 
                           $self->Obj->{'seq_region_name'} ne $self->core_objects->{'parameters'}{'r'} ? 1 : 0;
  my %synteny_hash = $self->species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
  
  $hash->{'has_synteny'} = scalar( keys %{ $synteny_hash{$self->species}||{} } ) ? 1 : 0;
  $hash->{'has_LD'} =   exists $self->species_defs->databases->{'DATABASE_VARIATION'} && 
    $self->param('opt_pop') &&
    $self->species_defs->databases->{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'} ? 1 : 0;
    my $rows = $self->table_info( $self->get_db, 'stable_id_event' )->{'rows'};
  $hash->{'has_markers'} = $self->table_info( $self->get_db, 'marker_feature' )->{'rows'} ? 1 : 0;
  return $hash;
}

our $MEMD = new EnsEMBL::Web::Cache;

sub counts {
  my $self = shift;
  my $obj = $self->Obj;
  my $key = '::COUNTS::LOCATION::'. $ENV{ENSEMBL_SPECIES};
  my $counts;
  $counts = $MEMD->get($key) if $MEMD;

  unless ($counts) {
    my $species = $self->species;

    # Count the entries in the synteny hash for this species...
    my %synteny_hash = $self->species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
    my ($alignments, $align_contig) = $self->count_alignments;
    $counts = {
      'synteny'      => scalar keys %{$synteny_hash{$species}||{}},
      'alignments'   => $alignments,
      'align_contig' => scalar keys %$align_contig
    };
    $counts->{'pairwise_alignments'} = $self->count_pairwise_alignments;
    if ($self->species_defs->databases->{'DATABASE_VARIATION'}) {
      my $reseq = $self->species_defs->databases->{'DATABASE_VARIATION'}{'#STRAINS'};
      $counts->{'reseq_strains'} = $reseq;
    }
    
    $MEMD->set($key, $counts, undef, 'COUNTS') if $MEMD;
  }

  return $counts;
}

sub count_pairwise_alignments {
  my $self = shift;
  my $species = $self->species;
  my %alignments = $self->species_defs->multi('DATABASE_COMPARA','ALIGNMENTS');
  my $c;
  foreach my $align (values %alignments) {
    next unless $align->{'class'} =~ /pairwise_alignment/;
    $c++ if $align->{'species'}{$species};
  }
  return $c;
}

sub short_caption {
  my $self = shift;
  return 'Location-based displays';
  #return $self->seq_region_name.': '.$self->thousandify($self->seq_region_start).'-'.
  #  $self->thousandify($self->seq_region_end);

}

sub caption {
  my $self = shift;
  return "Karyotype" unless $self->seq_region_name;
  return $self->neat_sr_name($self->seq_region_type,$self->seq_region_name).': '.$self->thousandify($self->seq_region_start).'-'.
                                     $self->thousandify($self->seq_region_end);
}
sub centrepoint      { return ( $_[0]->Obj->{'seq_region_end'} + $_[0]->Obj->{'seq_region_start'} ) / 2; }
sub length           { return   $_[0]->Obj->{'seq_region_end'} - $_[0]->Obj->{'seq_region_start'} + 1; }

sub slice            {
  my $self = shift;
  return $self->Obj->{'slice'} ||= $self->database('core',$self->real_species)->get_SliceAdaptor->fetch_by_region(
    $self->seq_region_type, $self->seq_region_name, $self->seq_region_start, $self->seq_region_end, $self->seq_region_strand );
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
  if ($self->param('fdb')){ $db = $self->param('fdb');}
  my ($identifier, $fetch_call, $featureobj, $dataobject, $subtype);
  
  ## Are we inputting IDs or searching on a text term?
  if ($self->param('xref_term')) {
    my @exdb = $self->param('xref_db');
    $features = $self->search_Xref($db, \@exdb, $self->param('xref_term'));
  }
  else {
    my $feature_type  = $self->param('ftype') ||$self->param('type') || 'ProbeFeature';  
    if ( ($self->param('ftype') eq 'ProbeFeature') && $self->param('ptype')) {
      $subtype = $self->param('ptype');
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
     $self->problem( 'Fatal', 'Database Error', "Could not connect to the $db database." );
     return undef;
   }
  return $db_adaptor;
}

sub _get_core_adaptor {
   my $self = shift;
   my $db_adaptor  = $self->database('core');
   unless( $db_adaptor ){
     $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." );
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
  my ( $self, $db, $id, $name ) = @_;

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
   "cisRED group motif" => "cisRED group motifs",
   "miRanda miRNA_target" => "miRanda miRNA",
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


## The following are used to convert full objects into simple data hashes, for use by drawing code

sub retrieve_userdata {
  ## Based on DnaAlignFeature, below
  my ($self, $data) = @_;
  my $type = 'DnaAlignFeature';
  my $results = [];

  foreach my $f ( @$data ) {
#     next unless ($f->score > 80);
    my $coord_systems = $self->coord_systems();
    my( $region, $start, $end, $strand ) = ( $f->seq_region_name, $f->start, $f->end, $f->strand );
    if( $f->coord_system_name ne $coord_systems->[0] ) {
      foreach my $system ( @{$coord_systems} ) {
        # warn "Projecting feature to $system";
        my $slice = $f->project( $system );
        # warn @$slice;
        if( @$slice == 1 ) {
          ($region,$start,$end,$strand) = ($slice->[0][2]->seq_region_name, $slice->[0][2]->start, $slice->[0][2]->end, $slice->[0][2]->strand );
          last;
        }
      }
    }
    push @$results, {
        'region'   => $region,
        'start'    => $start,
        'end'      => $end,
        'strand'   => $strand,
        'length'   => $f->end-$f->start+1,
        'label'    => $f->display_id." (@{[$f->hstart]}-@{[$f->hend]})",
        'gene_id'  => '',
        'extra' => [ $f->alignment_length, $f->strand, $f->hstart, $f->hend, $f->hstrand, $f->score ]
    };
  }
  
  my $feature_mapped = 1; ## TODO - replace with $self->feature_mapped call once unmapped feature display is added
  if ($feature_mapped) {
    return $results, [ 'Alignment length', 'Rel ori', 'Hit start', 'Hit end', 'Hit Strand', 'Score' ], $type;
  }
  else {
    return $results, [], $type;
  }

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
      my $trans = EnsEMBL::Web::Proxy::Object->new('Transcript',$t, $self->__data);
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

sub retrieve_Xref {
  my ($self, $data, $type) = @_;
  my $results = [];
  foreach my $array (@$data) {
    my $xref = shift @$array;
    push @$results, {
      'label'     => $xref->primary_id,
      'xref_id'   => [ $xref->primary_id ],
      'extname'   => $xref->display_id,
      'extra'     => [ $xref->description, $xref->dbname ]
    };
    ## also get genes
    foreach my $g (@$array) {
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

sub retrieve_ProbeFeature {
  my ($self, $data, $type) = @_;
  my $results = [];
  
  foreach my $probefeature (@$data) { 
    my $probe = $probefeature->probe;
    if (ref($probe) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($probe);
      push(@$results, $unmapped);
    }
    else {
      my $names = join ' ', map { /^(.*):(.*):\2/? "$1:$2" : $_ } sort @{$probe->get_all_complete_names()};
      foreach my $f (@{$probe->get_all_ProbeFeatures()}) {  
        push @$results, {
          'region'   => $f->seq_region_name,
          'start'    => $f->start,
          'end'      => $f->end,
          'strand'   => $f->strand,
          'length'   => $f->end-$f->start+1,
          'label'    => $names,
          'gene_id'  => [$names],
          'extra'    => [ $f->mismatchcount, $f->cigar_string ]
        }
      }
    }
  }
  return ( $results, ['Mismatches', 'Cigar_String'], $type );
}

sub retrieve_DnaAlignFeature {
  my ($self, $data, $type) = @_;
  my $results = [];
  foreach my $f ( @$data ) {
    if (ref($f) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($f);
      push(@$results, $unmapped);
    }
    else {
#     next unless ($f->score > 80);
      my $coord_systems = $self->coord_systems();
      my( $region, $start, $end, $strand ) = ( $f->seq_region_name, $f->start, $f->end, $f->strand );
      if( $f->coord_system_name ne $coord_systems->[0] ) {
        foreach my $system ( @{$coord_systems} ) {
          # warn "Projecting feature to $system";
          my $slice = $f->project( $system );
          # warn @$slice;
          if( @$slice == 1 ) {
            ($region,$start,$end,$strand) = ($slice->[0][2]->seq_region_name, $slice->[0][2]->start, $slice->[0][2]->end, $slice->[0][2]->strand );
            last;
          }
        }
      }
      push @$results, {
        'region'   => $region,
        'start'    => $start,
        'end'      => $end,
        'strand'   => $strand,
        'length'   => $f->end-$f->start+1,
        'label'    => $f->display_id." (@{[$f->hstart]}-@{[$f->hend]})",
        'gene_id'  => ["@{[$f->hstart]}-@{[$f->hend]}"],
        'extra' => [ $f->alignment_length, $f->hstrand * $f->strand, $f->percent_id, $f->score, $f->p_value ]
      };
    }
  }
  my $feature_mapped = 1; ## TODO - replace with $self->feature_mapped call once unmapped feature display is added
  if ($feature_mapped) {
    return $results, [ 'Alignment length', 'Rel ori', '%id', 'score', 'p-value' ], $type;
  }
  else {
    return $results, [], $type;
  }
}

sub retrieve_ProteinAlignFeature {
  my ($self, $data, $type) = @_;
  return $self->retrieve_DnaAlignFeature($data,$type);
}

sub retrieve_RegulatoryFactor {
  my ($self, $data, $type) = @_;
  my $results = [];
  my $flag = 0;
  foreach my $reg (@$data) {
    my @stable_ids;
    my $gene_links;
    my $db_ent = $reg->get_all_DBEntries;
    foreach ( @{ $db_ent} ) {
      push @stable_ids, $_->primary_id;
      my $url = $self->_url({'type' => 'Gene', 'action' => 'Summary', 'g' => $stable_ids[-1] }); 
      $gene_links  .= qq(<a href="$url">$stable_ids[-1]</a>);  
    }

    my @extra_results = $reg->analysis->description;
    $extra_results[0] =~ s/(https?:\/\/\S+[\w\/])/<a rel="external" href="$1">$1<\/a>/ig;

    unshift (@extra_results, $gene_links);# if $gene_links;

    push @$results, {
      'region'   => $reg->seq_region_name,
      'start'    => $reg->start,
      'end'      => $reg->end,
      'strand'   => $reg->strand,
      'length'   => $reg->end-$reg->start+1,
      'label'    => $reg->display_label,
      'gene_id'  => \@stable_ids,
      'extra'    => \@extra_results,
    }
  }
  my $extras = ["Feature analysis"];
  unshift @$extras, "Associated gene";# if $flag;
  return ( $results, $extras, $type );
}

sub unmapped_object {
  my ($self, $unmapped) = @_;
  my $analysis = $unmapped->analysis;

  my $result = {
    'label'     => $unmapped->{'_id_'},
    'reason'    => $unmapped->description,
    'object'    => $unmapped->ensembl_object_type,
    'score'     => $unmapped->target_score,
    'analysis'  => $$analysis{'_description'},
  };

  return $result;
}


######## SYNTENYVIEW CALLS ################################################

sub get_synteny_matches {
  my $self = shift;

  my @data;
  my $OTHER = $self->param('otherspecies') || 
              $self->param('species')      ||
              ( $ENV{ 'ENSEMBL_SPECIES' } eq 'Homo_sapiens' ? 'Mus_musculus' : 'Homo_sapiens' );
  my $gene2_adaptor = $self->database( 'core', $OTHER )->get_GeneAdaptor();
  my $localgenes = $self->get_synteny_local_genes;
  my $offset = $self->seq_region_start;

  foreach my $localgene (@$localgenes){
    my ($sppgene, $separate, $syntenygene);
    my $data;
    my $spp = $ENV{ 'ENSEMBL_SPECIES'};
    my $homologues = $self->fetch_homologues_of_gene_in_species($localgene->stable_id, $OTHER);
    my $homol_num = scalar @{$homologues};
    my $gene_synonym = $localgene->external_name || $localgene->stable_id;

    if(@{$homologues}) {
      foreach my $homol(@{$homologues}) {
        #warn "....    ", $homol->stable_id;
        my $gene       = $gene2_adaptor->fetch_by_stable_id( $homol->stable_id,1 );
        my $homol_id   = $gene->external_name || $gene->stable_id;
        my $gene_slice = $gene->slice;
        my $H_START    = $gene->start;
        my $H_CHR;
        if( $gene_slice->coord_system->name eq "chromosome" ) {
          $H_CHR = $gene_slice->seq_region_name;
        } else {
          my $coords =$gene_slice->project("chromosome");
          $H_CHR = $coords->[0]->[2]->seq_region_name() if @$coords;
        }
        push @data, {
          'sp_stable_id'    =>  $localgene->stable_id,
          'sp_synonym'      =>  $gene_synonym,
          'sp_chr'          =>  $localgene->seq_region_name,
          'sp_start'        =>  $localgene->seq_region_start,
          'sp_end'          =>  $localgene->seq_region_end,
          'sp_length'       =>  $self->bp_to_nearest_unit($localgene->start()+$offset),
          'other_stable_id' =>  $homol->stable_id,
          'other_synonym'   =>  $homol_id,
          'other_chr'       =>  $H_CHR,
          'other_start'     =>  $H_START,
          'other_end'       =>  $gene->end,
          'other_length'    =>  $self->bp_to_nearest_unit($gene->end - $H_START),
          'homologue_no'    =>  $homol_num
        };
      }
    } else {
      push @data, { 
        'sp_stable_id'      =>  $localgene->stable_id,
        'sp_chr'            =>  $localgene->seq_region_name,
        'sp_start'          =>  $localgene->seq_region_start,
        'sp_end'            =>  $localgene->seq_region_end,
        'sp_synonym'        =>  $gene_synonym,
        'sp_length'         =>  $self->bp_to_nearest_unit($localgene->start()+$offset) 
      };
    }
  }
    return \@data;
}

sub get_synteny_local_genes {
  my $self = shift ;

  my $flag = @_ ? 1 : 0;
  my $slice = shift || $self->core_objects->location;
  unless( $flag || $self->param('r') =~ /:/) {
    $slice = $slice->sub_Slice(1,1e6);
  }
  my $localgenes = [];

  ## Ensures that only protein coding genes are included in syntenyview
  my @biotypes = ('protein_coding', 'V_segments', 'C_segments');
  foreach my $type (@biotypes) {
    my $genes = $slice->get_all_Genes_by_type($type);
    push @$localgenes, @$genes if scalar(@$genes);
  }

  my @sorted = sort {$a->start <=> $b->start} @$localgenes;
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
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_dbID($pop_id);
  return {} unless $pop;
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
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $self->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH = $self->species_defs->ENSEMBL_TMP_TMP;

  $width = $self->param('w') || "50000" unless $width;
  my ($seq_region, $start, $seq_type ) = ($self->seq_region_name, $self->seq_region_start, $self->seq_region_type);
  return [] unless $seq_region;

  my $end   = $start + $width;
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

sub generate_query_hash {
  my $self = shift;
  return {
    'c'     => $self->seq_region_name.':'.$self->centrepoint.':'.$self->seq_region_strand,
    'w'     => $self->length,
    'h'     => $self->highlights_string(),
    'pop'   => $self->param('pop'),
 };
}

sub get_variation_features {

  ### Example : my @vari_features = $self->get_variation_features;
  ### Description : gets the Variation features found  on a slice
  ### Returns Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

   my $self = shift;
   my $slice = $self->slice_cache;
   return unless $slice;
   return $slice->get_all_VariationFeatures || [];
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


sub current_pop_name {
  my $self = shift; 
  my %pops_on;
  my %pops_off;
  my $view_config = $self->get_viewconfig();

  ## Hack to work with population passed through via url , ability to add more than one population to be added back at a later date. 
  my $pop =  $self->param('opt_pop');
  $pop =~s/\:on//;
  $pops_on{$pop} = 1; 


  # Read in all in viewconfig stuff
  foreach ($view_config->options) {
    next unless $_ =~ s/opt_pop_//;
    warn $_;
    $pops_on{$_}  = 1 if $view_config->get("opt_pop_$_") eq 'on';
    $pops_off{$_} = 1 if $view_config->get("opt_pop_$_") eq 'off';
  }

  # Set options according to bottom
  # if param bottom   #pop_CSHL-HAPMAP:HapMap-JPT:on;
  if ( $self->param('bottom') ) {
    foreach( split /\|/, ($self->param('bottom') ) ) {
      next unless $_ =~ /opt_pop_(.*):(.*)/;
      if ($2 eq 'on') {
	$pops_on{$1} = 1;
	delete $pops_off{$1};
      }
      elsif ($2 eq 'off') {
	$pops_off{$1} = 1;
	delete $pops_on{$1};
      }
    }
    return ( [keys %pops_on], [keys %pops_off] )  if keys %pops_on or keys %pops_off;
  }

  # Get pops switched on via pop arg if no bottom
  if ( $self->param('pop') ) {
    # put all pops_on keys in pops_off
    map { $pops_off{$_} = 1 } (keys %pops_on);
    %pops_on = ();
    map { $pops_on{$_} = 1 if $_ } $self->param('pop');
  }

  return ( [keys %pops_on], [keys %pops_off] )  if keys %pops_on or keys %pops_off;
  return [] if $self->param('bottom') or $self->param('pop');
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


sub getVariationsOnSlice {
  my $self = shift;
  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $self->slice_cache, $self->__data
       );

  my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures;
  return ($count_snps, $filtered_snps);
}


sub get_genotyped_VariationsOnSlice {
  my $self = shift;
  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $self->slice_cache, $self->__data
       );

  my ($count_snps, $filtered_snps) = $sliceObj->get_genotyped_VariationFeatures;
  return ($count_snps, $filtered_snps);
}

sub get_source {
  my $self = shift;
  my $default = shift;
  my $vari_adaptor = $self->database('variation')->get_db_adaptor('variation');
  unless ($vari_adaptor) {
    warn "ERROR: Can't get variation adaptor";
    return ();
  }

  if ($default) {
    return  $vari_adaptor->get_VariationAdaptor->get_default_source();
  }
  else {
    return $vari_adaptor->get_VariationAdaptor->get_all_sources();
  }
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

#------ Individual stuff ------------------------------------------------

sub individual_genotypes {

  ### individual_table_calls
  ### Arg1: variation feature object
  ### Example    : my $ind_genotypes = $object->individual_table;
  ### Description: gets Individual Genotype data for this variation
  ### Returns hashref with all the data

  my ($self, $vf, $slice_genotypes) = @_;
  if (! defined $slice_genotypes->{$vf->seq_region_name.'-'.$vf->seq_region_start}){
      return {};
  }
  my $individual_genotypes = $slice_genotypes->{$vf->seq_region_name.'-'.$vf->seq_region_start};
  return {} unless @$individual_genotypes; 
  my %data = ();
  my %genotypes = ();

  my %gender = qw (Unknown 0 Male 1 Female 2 );
  foreach my $ind_gt_obj ( @$individual_genotypes ) { 
    my $ind_obj   = $ind_gt_obj->individual;
    next unless $ind_obj;

    # data{name}{AA}
    #we should only consider 1 base genotypes (from compressed table)
    next if ( CORE::length($ind_gt_obj->allele1) > 1 || CORE::length($ind_gt_obj->allele2)>1);
    foreach ($ind_gt_obj->allele1, $ind_gt_obj->allele2) {
      my $allele = $_ =~ /A|C|G|T|N/ ? $_ : "N";
      $genotypes{ $ind_obj->name }.= $allele;
    }
    $data{ $ind_obj->name }{gender}   = $gender{$ind_obj->gender} || 0;
    $data{ $ind_obj->name }{mother}   = $self->parent($ind_obj, "mother");
    $data{ $ind_obj->name }{father}   = $self->parent($ind_obj, "father");
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
  my $iga = $variation_db->get_IndividualGenotypeAdaptor;
  my $genotypes = $iga->fetch_all_by_Slice($slice);
  #will return genotypes as a hash, having the region_name-start as key for rapid acces
  my $genotypes_hash = {};
  foreach my $genotype (@{$genotypes}){
    push @{$genotypes_hash->{$genotype->seq_region_name.'-'.$genotype->seq_region_start}},$genotype;
  }
  return $genotypes_hash;
}

### Calls for LD view ##########################################################

sub focus {
  ### Information_panel
  ### Purpose : outputs focus of page e.g.. gene, SNP (rs5050)or slice
  ### Description : adds pair of values (type of focus e.g gene or snp and the ID) to panel if the paramater "gene" or "snp" is defined

  my ( $obj ) = @_; 
  my ( $info, $focus );
  if ( $obj->param('v') ) {
    $focus = "Variant";
    my $snp = $obj->core_objects->variation;
    my $name = $snp->name;
    my $source = $snp->source;
    my $link_name  = $obj->get_ExtURL_link($name, 'SNP', $name) if $source eq 'dbSNP';# warn $link_name;
    $info .= "$link_name ($source ". $snp->adaptor->get_source_version($source).")";
  }
  elsif ( $obj->core_objects->{'parameters'}{'g'} ) {
    $focus = "Gene";
    my $gene_id = $obj->name;
    $info = ("Gene ". $gene_id);
    my $url = $obj->_url({ 'type' => 'Gene', 'action' => 'Summary', 'g' => $obj->param('g') });
    $info .= "  [<a href=$url>View Gene</a>]";
  }
  else {
    return 1;
  }
  return $info;
}

sub can_export {
  my $self = shift;
  return $self->action =~ /^Export$|^Chromosome$|^Genome$|^Synteny$/ ? 0 : $self->availability->{'slice'};
}

sub other_locations {
  my $self = shift;
  return $self->{'data'}{'_other_locations'} ? $self->{'data'}{'_other_locations'} : [];
}

1;
