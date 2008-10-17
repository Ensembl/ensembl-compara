package EnsEMBL::Web::Component::Location::KaryotypeImage;

### Module to replace Karyoview

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
use Data::Dumper;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::File::Text;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;

  ## Form with hidden elements for click-through
  my $config = $object->image_config_hash('Vkaryotype');
     $config->set_parameter(
       'container_width',
       $object->species_defs->MAX_CHR_LENGTH
     );

  my $ideo_height = $config->get_parameter('image_height');
  my $top_margin  = $config->get_parameter('top_margin');

  my $image    = $object->new_karyotype_image();

  my $pointers = [];
  my %pointer_defaults = (
    'Gene'        => ['blue', 'lharrow'],
    'OligoProbe'  => ['red', 'rharrow'],
  );
  
  ## Check if there is userdata in session
  my $userdata = $object->get_session->get_tmp_data;

  warn keys %$userdata; 
  ## Do we have feature "tracks" to display?
  my $hidden = {
    'karyotype'   => 'yes',
    'max_chr'     => $ideo_height,
    'margin'      => $top_margin,
    'chr'         => $object->seq_region_name,
    'start'       => $object->seq_region_start,
    'end'         => $object->seq_region_end,
  };
  if( $userdata && $userdata->{'filename'} ) {
    ## Set some basic image parameters
warn "trying to create image";
    $image->imagemap = 'no';
    $image->set_button( 'form', 'id'=>'vclick', 'URL'=>"/$species/jump_to_location_view", 'hidden'=> $hidden );
    $image->caption = 'Click on the image above to jump to an overview of the chromosome';
   
    ## Create pointers from user data
    my $pointer_set = $self->create_userdata_pointers($image, $userdata);
warn keys %$pointer_set; 
    push(@$pointers, $pointer_set);
  } elsif ($object->param('id')) {
    $image->image_name = "feature-$species";
    $image->imagemap = 'yes';
    my $features = $self->_get_features;
    my $i = 0;
    my $zmenu_config;
    foreach my $ftype  (keys %$features) {
      my $pointer_ref = $image->add_pointers( $object, {
        'config_name'  => 'Vkaryotype',
        'features'      => $features,
        'zmenu_config'  => $zmenu_config,
        'feature_type'  => $ftype,
        'color'         => $object->param("col_$i")   || $pointer_defaults{$ftype}[0],
        'style'         => $object->param("style_$i") || $pointer_defaults{$ftype}[1]}
      );
      push(@$pointers, $pointer_ref);
      $i++;
    }
  } else {
    $image->image_name = "karyotype-$species";
    $image->imagemap = 'no';
    $image->set_button('form', 'id'=>'vclick', 'URL'=>"/$species/jump_to_location_view", 'hidden'=> $hidden);
    $image->caption = 'Click on the image above to jump to an overview of the chromosome';
  }
  
  $image->karyotype( $object, $pointers, 'Vkaryotype' );

  return $image->render;
}

sub _get_features {
### Creates some raw API objects of the selected type(s), 
### and returns a ref to hash whose keys are the types
  my $self = shift;
  my $object = $self->object;
  my $features = {};

  my $db        = $object->param('db')  || 'core';
  my ($identifier, $fetch_call, $featureobj, $dataobject);

  ## Are we inputting IDs or searching on a text term?
  if ($object->param('xref_term')) {
    my @exdb = $object->param('xref_db');
    $features = $self->search_Xref($db, \@exdb, $object->param('xref_term'));
  }
  else {
    my $feature_type  = $object->param('type') || 'OligoProbe';
    $feature_type = 'OligoProbe' if $feature_type eq 'AffyProbe'; ## catch old links
    ## deal with xrefs
    my $subtype;
    if ($feature_type =~ /^Xref_/) {
      ## Don't use split here - external DB name may include underscores!
      ($subtype = $feature_type) =~ s/Xref_//;
      $feature_type = 'Xref';
    }

    my $create_method = "create_$feature_type";
    $features    = defined &$create_method ? $self->$create_method($db, $subtype) : undef;
  }

  return $features;
}

################ Create required feature objects #################

sub create_OligoProbe {
    # get Oligo hits plus corresponding genes
    my $probe = $_[0]->_generic_create( 'OligoProbe', 'fetch_all_by_probeset', $_[1] );
    my $probe_genes = $_[0]->_generic_create( 'Gene', 'fetch_all_by_external_name', $_[1],undef, 'no_errors' );
    my %features = ('OligoProbe' => $probe);
    $features{'Gene'} = $probe_genes if $probe_genes;
    return \%features;
}

sub create_DnaAlignFeature {
  my $features = {'DnaAlignFeature' => $_[0]->_generic_create( 'DnaAlignFeature', 'fetch_all_by_hit_name', $_[1] ) };
  my $genes = $_[0]->_generic_create( 'Gene', 'fetch_all_by_external_name', $_[1],undef, 'no_errors' );
  $features->{'Gene'} = $genes if $genes;
  return $features;
}

sub create_ProteinAlignFeature {
  my $features = {'ProteinAlignFeature' => $_[0]->_generic_create( 'ProteinAlignFeature', 'fetch_all_by_hit_name', $_[1] ) };
  my $genes = $_[0]->_generic_create( 'Gene', 'fetch_all_by_external_name', $_[1],undef, 'no_errors' );
  $features->{'Gene'} = $genes if $genes;
  return $features;
}

sub create_Gene {
  my ($self, $db) = @_;
  my $object = $self->object;
  if ($object->param('id') =~ /^ENS/) {
    return {'Gene' => $self->_generic_create( 'Gene', 'fetch_by_stable_id', $db ) };
  }
  else {
    return {'Gene' => $self->_generic_create( 'Gene', 'fetch_all_by_external_name', $db ) };
  }
}

# For a Regulatory Factor ID display all the RegulatoryFeatures
sub create_RegulatoryFactor {
  my ( $self, $db, $id, $name ) = @_;
  my $object = $self->object;

  if (!$id ) {
    my @ids = $object->param( 'id' );
    $id = join(' ', @ids);
  }
  elsif (ref($id) eq 'ARRAY') {
    $id = join(' ', @$id);
  }
  if (!$name ) {
    my @names = $object->param( 'name' );
    $name = join(' ', @names);
  }
  elsif (ref($name) eq 'ARRAY') {
    $name = join(' ', @$name);
  }


  my $objs = $self->DataObjects();
  my $features = [];

  my $db_type  = 'funcgen';
  my $efg_db = $object->database(lc($db_type));
  if(!$efg_db) {
     warn("Cannot connect to $db_type db");
     return [];
  }

  my %fset_types = (
   "cisRED group motif" => "cisRED group motifs",
   "miRanda miRNA_target" => "miRanda miRNA",
   "BioTIFFIN motif" => "BioTIFFIN motifs"
  );

  my $feature_set_adaptor = $efg_db->get_FeatureSetAdaptor;
  my $feature_type_adaptor = $efg_db->get_FeatureTypeAdaptor;
  my $ftype =  $feature_type_adaptor->fetch_by_name($name);
  my $type = $ftype->description;
  my $fstype = $fset_types{$type};
  my $fset = $feature_set_adaptor->fetch_by_name($fstype);
  $features = $fset->get_Features_by_FeatureType($ftype);

  my $feature_set = {'RegulatoryFactor' => $features};
  return $feature_set;

  return $features if $features && @$features; # Return if we have at least one feature
  # We have no features so return an error....
  $self->problem( 'no_match', 'Invalid Identifier', "Regulatory Factor $id was not found" );
  return undef;
}

sub create_Xref {
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
    ($xrefarray, $genes) = $self->create_XrefArray($t_features, $db);
  }

  my $features = {'Xref'=>$xrefarray};
  $features->{'Gene'} = $genes if $genes;
  return $features;
}

sub create_XrefArray {
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
  my $object = $self->object;
  $db ||= 'core';

  if (!$id ) {
    my @ids = $object->param( 'id' );
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
    my $db_adaptor  = $object->database(lc($db));
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


######################## Search methods ##########################

sub search_Xref {
  my ($self, $db, $exdb, $string, $flag) = @_;

  my $db_adaptor  = $self->object->database(lc($db));
  unless( $db_adaptor ){
    $self->problem( 'Fatal', 'Database Error', "Could not connect to the $db database." );
    return undef;
  }

  my @xref_dbs = @$exdb;
  my ($features, $total_features, $genes);
  foreach my $x (@xref_dbs) {
    my $t_features;
    eval {
     $t_features = $db_adaptor->get_DBEntryAdaptor->fetch_all_by_description('%'.$string.'%', $x);
    };
    if( $t_features && ref($t_features) eq 'ARRAY') {
      push @$total_features, @$t_features;
    }
  }
  ($features, $genes) = $self->create_XrefArray($total_features, $db);

  if ($features && @$features) { ## Return if we have at least one feature
    my %results = ('Xref'=>$features);
    $results{'Gene'} = $genes if $genes;
    return \%results;
  }

  # We have no features so return an error....
  unless ( $flag eq 'no_errors' ) {
    $self->problem( 'no_match', 'No Match', "No features could be found matching the search term '$string'" );
  }
  return undef;
}

1;
