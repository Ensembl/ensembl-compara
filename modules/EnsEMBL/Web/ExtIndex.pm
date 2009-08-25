#!/usr/local/bin/perl -w

package EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::Root;

our @ISA = qw(EnsEMBL::Web::Root);

use strict;
use Data::Dumper;

sub new {
  my( $class, $species_defs ) = @_;
  my $self = { 'species_defs' => $species_defs, 'databases' => {}, 'indexers' => {} };
  return bless $self, $class;
}

sub get_indexer {
    my( $self, $db ) = @_;

    unless( $self->{'databases'}{$db} ) {
	my ($indexer,$exe);
	#get data from e! databases
	if ($db =~ /^ENS/) {
	    $indexer = 'ENSEMBL_RETRIEVE';
	    $exe     = 1;
	}
	else {
	    $indexer = $self->{'species_defs'}->ENSEMBL_EXTERNAL_DATABASES->{ $db } || 
		$self->{'species_defs'}->ENSEMBL_EXTERNAL_DATABASES->{ 'DEFAULT'  } || 'PFETCH' ;
	    $exe     = $self->{'species_defs'}->ENSEMBL_EXTERNAL_INDEXERS->{ $indexer };
	}
	if( $exe ) {
	    my $classname = "EnsEMBL::Web::ExtIndex::$indexer";
	    unless( exists $self->{'indexers'}{$classname} ) {
		if( $self->dynamic_use( $classname ) ) {
		    $self->{'indexers'}{$classname} = $classname->new();
		} else {
		    $self->{'indexers'}{$classname} = undef;
		}
		$self->{'databases'}{$db} = { 'module' => $self->{'indexers'}{$classname}, 'exe' => $exe };
	    }
	} else {
	    $self->{'databases'}{$db} = { 'module' => undef };
	}
    }
    return $self->{'databases'}{$db}{'module'};
}

sub get_seq_by_id{
  my ($self, $args)=@_;
  return $self->_get_seq( 'ID', $args );
}

sub get_seq_by_acc{
  my ($self, $args)=@_;
  return $self->_get_seq( 'ACC', $args );
}

sub _get_seq{
  my ($self,$type,$args)=@_;
    
  ###############################################
  # Check for valid options and fix if necessary
  ###############################################
  my %options = ( 'id' => undef, 'acc' => undef, 'seq' => undef, 'desc' => undef, 'all' => undef );
  $args->{'OPTIONS'} = 'all' unless exists $args->{'OPTIONS'} && exists $options{ $args->{'OPTIONS'} };
    
  ############################################
  # retrieve the indexer and executable names
  ############################################
  my $db = $args->{'DB'} || 'DEFAULT';

  my $indexer = $self->get_indexer( $db );

  if( $indexer && defined $args->{$type} ) {
    my $function='get_seq_by_'.lc($type);
    $self->{'indexers'}{$db}{'module'} || new
    return $indexer->$function( {
      'EXE'          => $self->{'databases'}{$db}{'exe'},
      'DB'           => $db,
      'species_defs' => $self->{'species_defs'},
      'ID'           => $args->{$type},
      'FORMAT'       => $args->{'FORMAT'},
      'OPTIONS'      => $args->{'OPTIONS'},
    } );
  } else {
    warn "No indexer for DB of type $db";
    return [];
  }
}   

1;

