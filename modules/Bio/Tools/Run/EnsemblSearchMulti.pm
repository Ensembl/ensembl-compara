# Let the code begin...
package Bio::Tools::Run::EnsemblSearchMulti;

use strict;
use DBI;
use Data::Dumper qw( Dumper );

use vars qw(@ISA);

use Bio::Tools::Run::SearchMulti;
use Bio::Root::IO;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::DBSQL::DBConnection;
use Bio::Search::Result::ResultFactory;
use Bio::Search::Hit::HitFactory;
use Bio::Search::HSP::HSPFactory;

@ISA = qw( Bio::Tools::Run::SearchMulti );

use vars qw( $RESULT_FACTORY $HIT_FACTORY $HSP_FACTORY
	     $WORKDIR $TEMPLATE
	     $SPECIES_DEFS );

BEGIN:{

  # TODO: Pass $WORKDIR as arg from BlastView
  $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new();
  $WORKDIR = $SPECIES_DEFS->ENSEMBL_TMP_DIR_BLAST;
  if( ! $WORKDIR    ){ die( "ENSEMBL_TMP_DIR_BLAST not configured" ) }
  if( ! -d $WORKDIR ){ die( "$WORKDIR directory does not exist" ) } 

  # TODO: Pass $TEMPLATE as arg from BlastView
  $TEMPLATE = "BLA_XXXXXXXXXX";

  # Create Ensembl-specific result factories
  my $restype = 'Bio::Search::Result::EnsemblResult';
  my $hittype = 'Bio::Search::Hit::EnsemblHit';
  my $hsptype = 'Bio::Search::HSP::EnsemblHSP';
  $RESULT_FACTORY = Bio::Search::Result::ResultFactory->new(-type=>$restype);
  $HIT_FACTORY    = Bio::Search::Hit::HitFactory->new(-type=>$hittype);
  $HSP_FACTORY    = Bio::Search::HSP::HSPFactory->new(-type=>$hsptype);

}

#----------------------------------------------------------------------

=head2 new

  Arg [1]   :
  Function  : Builds a new Bio::Tools::Run::EnsemblSearchMulti object
  Returntype: Bio::Tools::Run::EnsemblSearchMulti
  Exceptions: 
  Caller    : 
  Example   : my $container = Bio::Tools::Run::EnsemblSearchMulti->new()

=cut

sub new {
  my( $caller, %opts ) = @_;

  # Ensembl code gets workdir from the EnsWeb::species_defs config
  my $workdir = tempdir( "BLA_XX/XXXXXXX", 
			 DIR      => $WORKDIR,
			 CLEANUP  => 0 );

  $opts{-workdir}        = $workdir;
  $opts{-template}       = $TEMPLATE;
  $opts{-result_factory} = $RESULT_FACTORY;
  $opts{-hit_factory}    = $HIT_FACTORY;
  $opts{-hsp_factory}    = $HSP_FACTORY;
  
  return $caller->SUPER::new(%opts);
}

#----------------------------------------------------------------------

=head2 core_adaptor

  Arg [1]   : [required] scalar (species)
  Arg [2]   : [optional] Bio::EnsEMBL::Adaptor (adaptor) 
  Function  : Accessor for the species-specific Ensembl core database adaptor
  Returntype: Bio::EnsEMBL::Adaptor
  Exceptions: 
  Caller    : 
  Example   : $hsp->core_adaptor( 'Homo_sapiens', $core_adpt )
  Example   : $core_adpt = $hsp->core_adaptor( 'Homo_sapiens' )

=cut

sub core_adaptor {
  my $key = '__core_adaptor'; # Don't serialise
  my $self    = shift;
  my $species = shift || ( $self->warn( "Need a species!" ) && return );
  $self->{$key} ||= {};
  if( @_ ){ $self->{$key}->{$species} = shift }
  return $self->{$key}->{$species};
}

#----------------------------------------------------------------------

=head2 tempdir

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub tempdir {
  my $template = shift;
  my %pars     = @_;
  srand( time() ^ ( $$ + ( $$ << 15 ) ) );

  my $path = '';
  my $good = 0;
  my $max_tries = 10;
  for( my $try=0; $try<$max_tries; $try++ ){
    my $file = $template;
    $file =~ s/X/['0'..'9','A'..'Z','a'..'z']->[int(rand 54)]/ge;
    my @dirs = split '/', $file;
    $path = $pars{'DIR'};
    my $last = pop @dirs;
    foreach my $dir ( @dirs ) {
      $path.="/$dir";
      if(!-e $path) {
        # Only warn if command fails - poss race with another process
	mkdir( $path ) || warn("Could not mkdir $path: $!");
      }
    }
    $path.="/$last";
    system( 'mkdir', $path );
    if( $? != 0 ){
      warn( "Could not mkdir $path: $!" );
      next;
    }
    else{
      $good = 1;
      last;
    }
  }

  if( ! $good ){
    die( "Could not create tempdir after $max_tries attempts" );
  }

#  ( my $filename = $template ) =~ s/X/['0'..'9','A'..'Z','a'..'z']->[int(rand 54)]/ge;
#
#  my @bits = split '/', $filename;
#  my $PATH = $pars{'DIR'};
#  foreach my $bit ( @bits ) {
#    $PATH.="/$bit";
#    if(!-e $PATH) {
#      mkdir $PATH;
#    }
#  }

  return $path;
}

#----------------------------------------------------------------------

=head2 token

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub token{
  my $self = shift;
  my $token = shift;
  if( $token ){ $self->{-ticket} = $token }
  elsif( ! $self->{-ticket} ){
    my $PS       = $Bio::Root::IO::PATHSEP;
    my @bits = split( $PS, $self->workdir );
    my ($T) = $self->workdir =~/(BLA_.*)/;
    $T =~ s/\///;
    $self->{-ticket}  =$T;  pop( @bits );
  }
  return $self->{-ticket};
}

#----------------------------------------------------------------------

=head2 _initialise_runnables

  Arg [1]   : None
  Function  : Registers a new ResultSearch method against method, db and seq
  Returntype: Boolean
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _initialise_runnables{
  my $self = shift;
  foreach my $me( keys %{$self->{-methods}} ){
    foreach my $db( keys %{$self->{-databases}} ){

      # Query SPECIES_DEFS to get database string from species, method, db key
      my( $sp, $db_key ) = $db =~ /^([A-Z][a-z_]+)_([A-Z_]+)$/;
      $db_key || $self->throw( "$db bad db format; must be ${sp}_${db}" );
      my $me_key = $me."_DATASOURCES";
      my $datasources = $SPECIES_DEFS->get_config( $sp, $me_key ) ||
	$self->throw("Nothing in config $sp: $me_key" );
      ref( $datasources ) eq 'HASH' ||
	$self->throw("Nothing in config $sp: $me_key" );
      my $db_str = $datasources->{$db_key}||
	$self->throw("Nothing in config $sp: $me_key: $db_key" );

      # -Gather blast environment variables from EnsEMBL::Web::SpeciesDefs
      my %config;
      foreach my $key( qw(
			  ENSEMBL_BINARIES_PATH
			  ENSEMBL_BLAST_BIN_PATH
			  ENSEMBL_BLAST_MATRIX
			  ENSEMBL_BLAST_FILTER
			  ENSEMBL_BLAST_DATA_PATH
			  ENSEMBL_BLAST_DATA_PATH_EXTRA
			 ) ){
	$config{$key} = $SPECIES_DEFS->get_config($sp, $key);
      }
      # -End gathering

      foreach my $sid( keys %{$self->{-seqs}} ){
	if( defined( $self->{-runnable_index}->{$me}->{$db}->{$sid} ) ){next}

	my $factory = $self->{-methods}->{$me};
	$factory->retrievable && $factory->retrieve(undef, $self->adaptor );
	# Update factory status to prevent any more parameters being set
	$factory->status("RUNNING"); 

	my $run_obj = $factory->new(
				    -database=>$db_str,
				    -seq=>$self->{-seqs}->{$sid},
				    -workdir=>$self->workdir,
				   );
        my $DBC = EnsEMBL::Web::DBSQL::DBConnection->new($sp,$SPECIES_DEFS);
	my $dbadpt = $DBC->get_DBAdaptor( 'core' );

	#- apply environment variables
	my $path = join( ':', 
			 ( $ENV{PATH} || () ),
			 ( $config{ENSEMBL_BINARIES_PATH}  || () ),
			 ( $config{ENSEMBL_BLAST_BIN_PATH} || () ) );
	$path && 
	  $run_obj->environment_variable( 'PATH', $path );

	$config{ENSEMBL_BLAST_MATRIX} &&
	  $run_obj->environment_variable( 'BLASTMAT', 
					  $config{ENSEMBL_BLAST_MATRIX} );


	$config{ENSEMBL_BLAST_FILTER} &&
	  $run_obj->environment_variable( 'BLASTFILTER', 
					  $config{ENSEMBL_BLAST_FILTER} );
	
	my $blastdb = join( '/', 
			    ( $config{ENSEMBL_BLAST_DATA_PATH}       || () ),
			    ( $config{ENSEMBL_BLAST_DATA_PATH_EXTRA} || () ) );
	$blastdb &&
	  $run_obj->environment_variable( 'BLASTDB', $blastdb );
	#- end application

	$run_obj->adaptor( $self->adaptor );
	$run_obj->result->core_adaptor( $dbadpt );
	$run_obj->result->database_species( $sp );
	$run_obj->result->database_type( $db_key );

	$run_obj->verbose( $self->verbose );
	push @{$self->{-runnables}}, $run_obj;
	#$run_obj->number( $self->num_runnables );
	my $idx = scalar @{$self->{-runnables}} - 1;
	$self->{-runnable_index}->{$me}->{$db}->{$sid} = $idx;
	$self->modified(1);
      }
    }
  }
}

#======================================================================
1;
