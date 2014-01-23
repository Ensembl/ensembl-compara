#!/usr/local/bin/perl -w
=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
    if ($db =~ /^ENS_/) {
      $indexer = 'ENSEMBL_RETRIEVE';
      $exe     = 1;
    }
    else {
      $indexer = $self->{'species_defs'}->ENSEMBL_EXTERNAL_DATABASES->{ $db }
         || $self->{'species_defs'}->ENSEMBL_EXTERNAL_DATABASES->{ 'DEFAULT'  }
         || 'PFETCH' ;
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
  my %options = ( 'id' => undef, 'acc' => undef, 'seq' => undef, 'desc' => undef, 'mismatch' => undef, 'all' => undef );
  $args->{'OPTIONS'} = 'all' unless exists $args->{'OPTIONS'} && exists $options{ $args->{'OPTIONS'} };
    
  ############################################
  # retrieve the indexer and executable names
  ############################################
  my $db = $args->{'DB'} || 'DEFAULT';

  my $indexer = $self->get_indexer( $db );

  if( $indexer && defined $args->{$type} ) {
    my $function='get_seq_by_'.lc($type);
    if(! $indexer->can($function)){return [];}
    $self->{'indexers'}{$db}{'module'} || new
    return $indexer->$function( {
      'EXE'          => $self->{'databases'}{$db}{'exe'},
      'DB'           => $db,
      'species_defs' => $self->{'species_defs'},
      'ID'           => $args->{$type},
      'FORMAT'       => $args->{'FORMAT'},
      'OPTIONS'      => $args->{'OPTIONS'},
      'strand_mismatch' => $args->{'strand_mismatch'} 
    } );
  } else {
    warn "No indexer for DB of type $db";
    return [];
  }
}   

1;
