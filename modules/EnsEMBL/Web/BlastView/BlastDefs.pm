#!/usr/local/bin/perl -w
#======================================================================
#   
#   Name:        BlastDefs.pm
#   
#   Description: module to create blastview config data 
#
#======================================================================

package EnsEMBL::Web::BlastView::BlastDefs;

use strict;
use Data::Dumper;
use EnsEMBL::Web::SpeciesDefs;

use vars qw( $SPECIES_DEFS );
BEGIN{ $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new() }

#----------------------------------------------------------------------
# Some class variables
my $CONF = {};
my $FACT = []; # 'fact-like' table for describing all query types

#$METHOD->{method_name}->{sub_method_name} = $query_type.$subject_type
#my $METHODS = {};
#$METHODS->{ssaha} = {};
#$METHODS->{blast} = {};
#$METHODS->{ssaha}->{ssahan}  = 'NN';
#$METHODS->{blast}->{blastn}  = 'NN';
#$METHODS->{blast}->{blastx}  = 'NP';
#$METHODS->{blast}->{tblastx} = 'NN';
#$METHODS->{blast}->{blastp}  = 'PP';
#$METHODS->{blast}->{tblastn} = 'PN';

#----------------------------------------------------------------------
# Prepare the config

=head2 new

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub new{
  my $class = shift;
  my $self = bless( {}, $class );
#  if( ! $CONF ){ 
    $self->_build_conf;
#  }
  return bless( $self );
}

#----------------------------------------------------------------------
sub _build_conf{

  my @species = sort grep{ !/_map$/ } $SPECIES_DEFS->valid_species();

  my $method_conf = $SPECIES_DEFS->multi_val('ENSEMBL_BLAST_METHODS');

  if( ref( $method_conf ) ne 'HASH' or ! scalar( %$method_conf ) ){
    warn( "ENSEMBL_BLAST_METHODS config unavailable" );
    return;
  }

  my @methods = map{ uc($_) } sort keys %$method_conf;
  my @types   = qw( dna peptide );

  $CONF->{default_type}         = 'dna';
  $CONF->{default_method}       = 'BLAT';
  $CONF->{default_species}      = 'Homo_sapiens';
  $CONF->{default_database}     = 'LATESTGP';

#  my %confkeys = ( BLAST      => 'BLAST_DATASOURCES',
#		   WUBLASTN   => 'WUBLASTN_DATASOURCES',
#		   SSAHA      => 'SSAHA_DATASOURCES',
#		   SSAHA_PERL => 'SSAHA_DATASOURCES' );

  foreach my $sp( @species ){
    foreach my $me( 'BLAST', @methods ){
      #warn "METHOD $me";

      my $conf = $SPECIES_DEFS->get_config( $sp, "${me}_DATASOURCES" );
      #warn "CONF ".Dumper($conf);

      # Check that there's something in the conf
      if( ref( $conf ) ne 'HASH' or ! scalar( keys %$conf ) ){ next }

      # Get method type
      my $dty = $conf->{DATASOURCE_TYPE};

      # Update conf
      $CONF->{species_by_method}->{$me} ||= {};
      $CONF->{species_by_method}->{$me}->{$sp} = 1;
      # Loop for each conf entry
      foreach my $db( sort keys %$conf ){	
	      my $lb = '';
	      if( $db =~ /^DATASOURCE/ ){ next }
	      if( $me eq 'BLAST' ){ 
	        if( $db =~ /DEFAULT/ ){ next }
	        $lb = $conf->{$db};
	        $CONF->{DATABASES}->{$db}->{LABEL} = $lb;
	        next;
	      }
  	    if( $me eq 'SSAHA' ){ 
	        if( $db =~ /^SOURCE/ ){ next }
	      }

	      my $qty = $db =~ /PEP/ ? 'peptide' : 'dna';

        #my $a = [ $sp, $db, $me, $qty, $dty ];
	      push @$FACT, [ $sp, $db, $me, $qty, $dty ];
        #warn "DATASOURCE ".Dumper($a);

	      $CONF->{SPECIES}->{$sp}->{$db} = 1;
	      $CONF->{DATABASES}->{$db}->{LABEL}       = $lb if $lb;
	      $CONF->{DATABASES}->{$db}->{D_TYPE}      = $dty;
	      $CONF->{DATABASES}->{$db}->{$sp} = 1;

      }
    }
  }
  #warn Dumper( $FACT );
  return 1;

}

#----------------------------------------------------------------------
=head2 default_species

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub default_species{
  my $key = 'default_species';
  return $CONF->{$key}
}

#----------------------------------------------------------------------
=head2 default_method

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub default_method{
  my $key = 'default_method';
  return $CONF->{$key}
}

#----------------------------------------------------------------------
=head2 default_type

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub default_type{
  my $key = 'default_type';
  return $CONF->{$key}
}
#----------------------------------------------------------------------
=head2 default_database

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub default_database{
  my $key = 'default_database';
  return $CONF->{$key}
}
#----------------------------------------------------------------------

=head2 database_labels

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub database_labels {
  my $self = shift;
  return ( map{$_, $CONF->{DATABASES}->{$_}->{LABEL} } 
	   keys %{$CONF->{DATABASES}} );
}


#----------------------------------------------------------------------

=head2 dice

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub dice {
  my $self = shift;
  my %args = @_;
  my @avail = @{$FACT};

  if(my $val = $args{-species }){ @avail = grep{ $_->[0] eq $val } @avail }
  if(my $val = $args{-database}){ @avail = grep{ $_->[1] eq $val } @avail }
  if(my $val = $args{-method  }){ @avail = grep{ $_->[2] eq $val } @avail }
  if(my $val = $args{-d_type  }){ @avail = grep{ $_->[3] eq $val } @avail }
  if(my $val = $args{-q_type  }){ @avail = grep{ $_->[4] eq $val } @avail }
  
  my %out;
  $args{-out} ||= 'species';
  if( $args{-out} eq 'species'  ){ %out = map{ $_->[0]=>1 } @avail }
  if( $args{-out} eq 'database' ){ %out = map{ $_->[1]=>1 } @avail }
  if( $args{-out} eq 'method'   ){ %out = map{ $_->[2]=>1 } @avail }
  if( $args{-out} eq 'd_type'   ){ %out = map{ $_->[3]=>1 } @avail }
  if( $args{-out} eq 'q_type'   ){ %out = map{ $_->[4]=>1 } @avail }
 
#  warn Dumper( \%args );
#  warn Dumper( \@avail );

  return keys %out;
}

#----------------------------------------------------------------------

1;
