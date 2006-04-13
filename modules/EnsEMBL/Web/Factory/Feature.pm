package EnsEMBL::Web::Factory::Feature;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
                                                                                   
our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self   = shift;
  my $feature_type  = $self->param('type') || 'OligoProbe';
  $feature_type = 'OligoProbe' if $feature_type eq 'AffyProbe'; ## catch old links

  my $create_method = "create_$feature_type";

  my ($identifier, $fetch_call, $featureobj, $dataobject);
  my $db        = $self->param('db')  || 'core';

  $featureobj    = defined &$create_method ? $self->$create_method($db) : undef;
  $dataobject    = EnsEMBL::Web::Proxy::Object->new( 'Feature', $featureobj, $self->__data );

  if( $dataobject ) {
    $dataobject->feature_type( $feature_type );
    $dataobject->feature_id( $self->param( 'id' ));
    $self->DataObjects( $dataobject );
  }
  
}

#---------------------------------------------------------------------------

sub create_OligoProbe {
    # get Oligo hits plus corresponding genes
    my $probe = $_[0]->_generic_create( 'OligoProbe', 'fetch_all_by_probeset', $_[1] );
    my $probe_genes = $_[0]->_generic_create( 'Gene', 'fetch_all_by_external_name', $_[1],undef, 'no_errors' );
    my $features = {'OligoProbe'=>$probe};
    $$features{'Gene'} = $probe_genes if $probe_genes;
    return $features;
}

sub create_DnaAlignFeature {
  my $features =  {'DnaAlignFeature' => $_[0]->_generic_create( 'DnaAlignFeature', 'fetch_all_by_hit_name', $_[1] ) }; 
  return $features;
}
sub create_ProteinAlignFeature {
  my $features = {'ProteinAlignFeature' => $_[0]->_generic_create( 'ProteinAlignFeature', 'fetch_all_by_hit_name', $_[1] ) };
  return $features;
}

sub create_Gene {
  my $features = {'Gene' => $_[0]->_generic_create( 'Gene', 'fetch_all_by_external_name', $_[1] ) }; 
  return $features;
}


sub create_Disease {
    # get disease hits plus corresponding genes
    my $disease = $_[0]->_generic_create( 'DBEntry', 'fetch_by_db_accession', $_[1] );
    my $disease_genes = $_[0]->_generic_create( 'Gene', 'fetch_all_by_external_name', $_[1],undef, 'no_errors' );
    my $features = {'Disease'=>$disease};
    $$features{'Gene'} = $disease_genes if $disease_genes;
    return $features;
}


sub _generic_create {
  my( $self, $object_type, $accessor, $db, $id, $flag ) = @_;
  $db ||= 'core';
                                                                                   
  $id ||= $self->param( 'id' );
  my $extra = 'MIM' if $object_type eq 'DBEntry';
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
    foreach my $fid ( split /\s+/, $id ) {
      my $t_features;
      if ($extra) {
        eval {
         $t_features = [$db_adaptor->$adaptor_name->$accessor($extra, $fid)];
        };
      }
      else {
        eval {
         $t_features = $db_adaptor->$adaptor_name->$accessor($fid);
        };
      }
      ## if no result, check for unmapped features
      if ($t_features && ref($t_features) eq 'ARRAY' && !@$t_features) {
        my $uoa = $db_adaptor->get_UnmappedObjectAdaptor;
        $t_features = $uoa->fetch_by_identifier($fid);
      }

      if( $t_features && ref($t_features) eq 'ARRAY') {
        foreach my $f (@$t_features) { 
          $f->{'_id_'} = $fid;
        }
        push @$features, @$t_features;
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

# For a Regulatory Factor ID display all the RegulatoryFeatures
sub create_RegulatoryFactor {
  my ( $self, $db, $id ) = @_;
  $id ||= $self->param( 'id' );

  my $db_adaptor  = $self->database(lc($db));
  unless( $db_adaptor ){
    $self->problem( 'Fatal', 'Database Error', "Could not connect to the $db database." );
    return undef;
  }
  my $reg_feature_adaptor = $db_adaptor->get_RegulatoryFeatureAdaptor;
  my $reg_factor_adaptor = $db_adaptor->get_RegulatoryFactorAdaptor;

  my $features = [];
  foreach my $fid ( split /\s+/, $id ) {
    my $t_features;
    eval {
      $t_features = $reg_feature_adaptor->fetch_all_by_factor_name($fid);
    };
     if( $t_features ) {
      foreach( @$t_features ) { $_->{'_id_'} = $fid; }
      push @$features, @$t_features;
    }
  }
  my $feature_set = {'RegulatoryFactor' => $features};
  return $feature_set;

  return $features if $features && @$features; # Return if we have at least one feature
  # We have no features so return an error....
  $self->problem( 'no_match', 'Invalid Identifier', "Regulatory Factor $id was not found" );
  return undef;
}
1;

