package EnsEMBL::Web::Factory::Transcript;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
our @ISA = qw(  EnsEMBL::Web::Factory );

sub fastCreateObjects {
  my $self = shift;
  my $adaptor_call = sprintf( "get_%sAdaptor", $self->param('type') || 'Transcript' );
  $self->DataObjects( EnsEMBL::Web::Proxy::Object->new(
    'Transcript', 
    $self->database($self->param('db')||'core')->$adaptor_call->fetch_by_stable_id( $self->param('transcript') ),
    $self->__data 
  ));
}

sub createObjects {   
  my $self = shift;
  my ($identifier, @fetch_calls, $transobj);
  if( $self->core_objects->transcript ) {
    warn "Creating transcript object!.....!";
    $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Transcript', $self->core_objects->transcript, $self->__data ));
    return;
  }

  my $db          = $self->param( 'db' ) || 'core';
     $db          = 'otherfeatures' if $db eq 'est';
  my $db_adaptor  = $self->database($db) ;	
  unless ($db_adaptor){
    $self->problem('Fatal', 
		   'Database Error', 
		   "Could not connect to the $db database."  ); 
    return ;
  }

  my $KEY = 'transcript';
  if( $identifier = $self->param( 'peptide' ) ){ 
    @fetch_calls = qw(fetch_by_translation_stable_id fetch_by_stable_id);
  } elsif( $identifier = $self->param( 'transcript' ) ){ 
    @fetch_calls = qw(fetch_by_stable_id fetch_by_translation_stable_id);
  } elsif( $identifier = $self->param( 'exon' ) ){
    @fetch_calls = qw(fetch_all_by_exon_stable_id);
  } elsif( $identifier = $self->param( 'anchor1' ) ) {
    @fetch_calls = qw(fetch_by_stable_id fetch_by_translation_stable_id);
    @fetch_calls = reverse @fetch_calls if($self->param( 'type1' ) eq 'peptide');
    $KEY = 'anchor1';
  } else {
    $self->problem('fatal', 'Please enter a valid identifier',
		     "This view requires a transcript, peptide 
                   or exon identifier in the URL.")  ;
    return;
  }

  foreach my $adapt_class("TranscriptAdaptor","PredictionTranscriptAdaptor"){
    my $adapt_getter = "get_$adapt_class";
    my $adaptor = $db_adaptor->$adapt_getter;
    (my $T = $identifier) =~ s/^(\S+)\.\d*/$1/g ; # Strip versions
    (my $T2 = $identifier) =~ s/^(\S+?)(\d+)(\.\d*)?/$1.sprintf("%011d",$2)/eg ; # Strip versions

    foreach my $fetch_call (@fetch_calls) {
    eval { $transobj = $adaptor->$fetch_call($identifier) };
    last if $transobj;
    eval { $transobj = $adaptor->$fetch_call($T2) };
    last if $transobj;
    eval { $transobj = $adaptor->$fetch_call($T) };
    last if $transobj;
    }
    last if $transobj;
  }

  if( ref( $transobj ) eq 'ARRAY' ){ 
    # if fetch_call is type 'fetch_all', take first object
    $transobj = $transobj->[0];
  }

  if(!$transobj || $@) { 
    # Query xref IDs
    $self->_archive( 'Transcript', $KEY );
    return if( $self->has_a_problem );
    $self->_known_feature('Transcript', $KEY );
    return ;	
  }

  # Set transcript param to Ensembl Stable ID
  # $self->param( 'transcript',[ $transobj->stable_id ] );
  $self->problem( 'redirect', $self->_url({'db'=>$db, 't' =>$transobj->stable_id,'g'=>undef,'r'=>undef}));
  return;#
  $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Transcript', $transobj, $self->__data ) );
}


1;
