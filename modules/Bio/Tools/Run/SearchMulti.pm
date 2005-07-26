
=head1 NAME

Bio::Tools::Run::SearchMulti - Wrapper for multiple Bio::Tools::Run::Search objs

=head1 SYNOPSIS

  use Bio::Tools::Run::SearchMulti;
  my $runmulti = Bio::Tools::Run::SearchMulti->new();
  $runmulti->add_method($method);    # Method string
  $runmulti->add_database($database);# Database string
  $runmulti->add_seq($seq);          # Bio::SeqI object

  # Get a list of Bio::Tools::Run::Search objects
  my @runnables = grep{ $_->run } $runmulti->runnables;

=head1 DESCRIPTION

Wrapper for handling multiple Bio::Tools::Run::Search (Sequence Database
Search) objects. 

A ticketing system has been implemented to allow Bio::Tools::Run::SearchMulti
objects to be safely saved to disk and recovered.

=cut

# Let the code begin...
package Bio::Tools::Run::SearchMulti;

use strict;
use Data::Dumper qw( Dumper );
use vars qw(@ISA);

use Bio::Root::Root;
use Bio::Root::Storable;
use Bio::Tools::Run::Search;

@ISA = qw( Bio::Root::Root Bio::Root::Storable );


#----------------------------------------------------------------------

=head2 new

  Arg [1]   : -workdir => $workdir (base directory for tmp files)
              -methods => @mtds (array of methods for building Run objs)
              -databases => @dbs (array of databases for building Run objs)
              -seqs => @seqs (array of Bio::SeqI objs for building Run objs),
              -result_factory => Object implement Bio::Factory::ObjectFactoryI
              -hit_factory    => Object implement Bio::Factory::ObjectFactoryI
              -hsp_factory    => Object implement Bio::Factory::ObjectFactoryI
  Function  : Builds a new Bio::Tools::Run::SearchMulti object.
  Returntype: Bio::Tools::Run::SearchMulti obj
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub new{

  my($caller,@args) = @_;
  my $class = ref($caller) || $caller;
  my $self = $class->SUPER::new(@args);
  $self->_initialise_storable(@args);

  my( $methods, $databases, $seqs, 
      $res_fact, $hit_fact, $hsp_fact ) = $self->_rearrange
	( [ qw( METHODS
		DATABASES
		SEQS
		RESULT_FACTORY
		HIT_FACTORY
		HSP_FACTORY ) ] , @args );

  $self->{_result_factory} = $res_fact;
  $self->{_hit_factory}    = $hit_fact;
  $self->{_hsp_factory}    = $hsp_fact;

  if( ref($methods) eq 'ARRAY' ){
    map{ $self->add_method($_) } @$methods;
  }
  if( ref($databases) eq 'ARRAY' ){
    map{ $self->add_database($_) } @$databases;
  }
  if( ref($seqs) eq 'ARRAY' ){
    map{ $self->add_seq($_) } @{$seqs};
  }
  
  $self->{-methods}   ||= {};
  $self->{-databases} ||= {};
  $self->{-seqs}      ||= {};
  $self->{-runnables} ||= [];
  $self->{-runnable_index} ||= {};

  $self->modified(1);
  return $self;
}

#----------------------------------------------------------------------

=head2 methods

  Arg [1]   : None
  Function  : Returns the list of methods registered with the obj
  Returntype: @methods (array of strings)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub methods{
  my $self   = shift;
  my @mtds;
  foreach my $me_id( sort keys %{$self->{-methods}} ){
    my $mtd = $self->{-methods}->{$me_id};
    if( $mtd->retrievable ){ $mtd->retrieve( undef, $self->adaptor ) }
    push @mtds, $mtd;
  }
  return @mtds;
  #return map{ $self->{-methods}->{$_} } sort keys %{$self->{-methods}};
}

#----------------------------------------------------------------------

=head2 add_method

  Arg [1]   : Bio::Tools::Run::Search object
  Function  : Adds a method to the list of methods.
              Uses the Bio::Tools::Run::Search obj to act as a template.
  Returntype: $method (string)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub add_method {
  my $self   = shift;
  my $method = shift;
  $method->workdir( $self->workdir );

  unless( ref($method) && $method->isa("Bio::Tools::Run::Search")){
    $self->throw( "Need a Bio::Tools::Run::Search obj" );
  }
  $self->{-methods} ||= {};

  # Propogate verbage
  $method->verbose || $method->verbose( $self->verbose );

  # Get a unique ID
  my $id = $method->id || $method->algorithm;
  my $id_new = $id;
  my $i = 0;
  while( $self->{-methods}->{$id} ){
    $i++; 
    $id_new = $id.'_'.$i;
  }
  $id = $id_new;
  $method->id( $id );
  $method->_eventHandler->register_factory('result',$self->{_result_factory});
  $method->_eventHandler->register_factory('hit',   $self->{_hit_factory});
  $method->_eventHandler->register_factory('hsp',   $self->{_hsp_factory});
  $method->workdir( $self->workdir );
  $method->verbose( $self->verbose );

#  my $factory = Bio::Tools::Run::Search->new( %opts );
  $self->{-methods}->{$id} = $method;

  $self->modified(1);

  return 1;
}

#----------------------------------------------------------------------

=head2 remove_method

  Arg [1]   : $method_name (string)
  Function  : Removes a method from the method list.
              Removes runnables dependent on this method.
  Returntype: $method (string)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub remove_method {
  my $self = shift;
  my $me   = shift || $self->throw( "Need a method ID" );
  
  if( ! $self->{-methods} ){ 
    $self->warn("No methods set") && return; 
  }
  if( ! $self->{-methods}->{$me} ){
    $self->warn("Method '$me' not set") && return;
  }

  # Remove method from list
  $self->{-methods}->{$me}->remove;
  delete( $self->{-methods}->{$me} );

  # Remove runnables
  my @idxes = $self->_runnable_indexes_like( -method=>$me );
  foreach my $i( @idxes ){
    defined( $i ) || next;
    my $runnable = $self->{-runnables}->[$i] || next;
    if( $runnable->isa('Bio::Root::Storable') ){
      $runnable->retrieve( undef, $self->adaptor ) if $runnable->retrievable;
      $runnable->remove;
    }
    undef($self->{-runnables}->[$i])
  }

  # Remove nodes from tree
  if( ref( $self->{-runnable_index} ) ne 'HASH' ){ return $me }
  delete( $self->{-runnable_index}->{$me} );

  $self->modified(1);

  return $me;
}

#----------------------------------------------------------------------

=head2 databases

  Arg [1]   : None
  Function  : Returns the list of databases registered with the obj
  Returntype: @databases (array of strings)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub databases{
  my $self   = shift;
  return sort keys %{$self->{-databases}};
}

#----------------------------------------------------------------------

=head2 add_database

  Arg [1]   : $database (string)
  Function  : Adds a database to the list of databases.
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub add_database{
  my $self   = shift;
  my $db = shift || $self->throw( "Need a database string" );

  $self->{-databases} ||= {};

  if( $self->{-databases}->{$db}){
    $self->warn("Database $db already set");
    return;
  }
  $self->{-databases}->{$db} = 1;

  $self->modified(1);

  return $db;
}

#----------------------------------------------------------------------

=head2 remove_database

  Arg [1]   : $database (string)
  Function  : Removes a database from the databases list.
              Removes runnables dependent on this database
  Returntype: $database (string)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub remove_database {
  my $self = shift;
  my $db   = shift || $self->throw( "Need a database" );

  $self->{-databases}        or $self->warn("No databases set")     && return;
  $self->{-databases}->{$db} or $self->warn("Database $db not set") && return;

  # Remove database from list
  delete( $self->{-databases}->{$db} );

  # Remove runnables
  my @idxes = $self->_runnable_indexes_like( -database=>$db );
  foreach my $i( @idxes ){
    defined( $i ) || next;
    my $runnable = $self->{-runnables}->[$i] || next;
    if( $runnable->can('remove') ){ $runnable->remove }
    undef($self->{-runnables}->[$i])
  }

  # Remove nodes from tree
  if( ref( $self->{-runnable_index} ) ne 'HASH' ){ return $db }
  foreach my $me( %{$self->{-runnable_index}} ){
    if( ref( $self->{-runnable_index}->{$me} ) ne 'HASH' ){ next }
    delete( $self->{-runnable_index}->{$me}->{$db} );
  }

  $self->modified(1);

  return $db;
}

#----------------------------------------------------------------------

=head2 seqs

  Arg [1]   : None
  Function  : Returns the list of Bio::SeqI objs registered with the RunMulti
  Returntype: @seqs (array of Bio::SeqI objs)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub seqs{
  my $self = shift;
  return map{ $self->{-seqs}->{$_} } sort keys %{$self->{-seqs}};
}

#----------------------------------------------------------------------

=head2 add_seq

  Arg [1]   : $seq (Bio::SeqI obj)
  Function  : Adds a Bio::SeqI obj to the list of sequences
  Returntype: $seq->display_id (string)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub add_seq{
  my $self = shift;
  my $seq  = shift;

  unless( ref($seq) && $seq->isa("Bio::Seq") ){
    $self->throw( "Need a Bio::Seq obj" );
  }
  

  $self->{-seqs} ||= {};

  # Get a unique ID
  my $id = $seq->display_id() || 'Unknown';
  my $id_new = $id;
  my $i = 0;
  while( $self->{-methods}->{$id} ){
    $i++; 
    $id_new = $id.'_copy'.$i;
  }
  $id = $id_new;
  $seq->display_id( $id );
  
  $self->{-seqs}->{$id} = $seq;

  $self->modified(1);

  return $id;
}

#----------------------------------------------------------------------

=head2 remove_seq

  Arg [1]   : $seq_id (string)
  Function  : Removes a Bio::SeqI object from the seqs list.
              Removes runnables dependent on this seq.
  Returntype: $seq_id (string)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub remove_seq{
  my $self = shift;
  my $seq  = shift || $self->throw( "Need a display ID" );

  $self->{-seqs}         or $self->warn("No sequences set")      && return;
  $self->{-seqs}->{$seq} or $self->warn("Sequence $seq not set") && return;

  # Remove sequence from list
  delete( $self->{-seqs}->{$seq} );
  
  # Remove runnables
  my @idxes = $self->_runnable_indexes_like( -seq=>$seq );
  foreach my $i( @idxes ){
    defined( $i ) || next;
    my $runnable = $self->{-runnables}->[$i] || next;
    if( $runnable->can('remove') ){ $runnable->remove }
    undef($self->{-runnables}->[$i])
  }

  # Remove nodes from tree
  if( ref( $self->{-runnable_index} ) ne 'HASH' ){ return $seq }
  foreach my $me( %{$self->{-runnable_index}} ){
    if( ref( $self->{-runnable_index}->{$me} ) ne 'HASH' ){ next }
    foreach my $db( %{$self->{-runnable_index}->{$me}} ){
      if( ref( $self->{-runnable_index}->{$me}->{$db} ) ne 'HASH' ){ next }
      delete( $self->{-runnable_index}->{$me}->{$db}->{$seq} );
    }
  }

  $self->modified(1);

  return $seq;
}

#----------------------------------------------------------------------

=head2 runnable_tokens

  Arg [1]   : 
  Function  : Returns an array of the tokens of all runnables registered
              with this instance. Does not retrieve runnables.
              Tokens are sorted by sequence display ID, then by database_name
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub runnable_tokens {
  my $self = shift;
  my @seqs = sort map{$_->display_id} $self->seqs;
  my @dbs  = sort $self->databases;

  my @sort_opts;
  foreach my $seq( sort map{$_->display_id} $self->seqs ){
    foreach my $db( sort $self->databases ){
      my %opts = ( -seq=>$seq, -database=>$db );
      push @sort_opts, \%opts;
    }
  }

  my @indexes = map{ $self->_runnable_indexes_like( %$_ ) } @sort_opts;
  return map{$_->token} $self->_runnables_by_indexes( @indexes );
}

#----------------------------------------------------------------------

=head2 num_runnables

  Arg [1]   : None
  Function  : Returns a count of the number of runnables held by the object
  Returntype: $count (integer)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub num_runnables{
  my $self = shift;
  return scalar( grep{$_} @{$self->{-runnables}} );
}



#----------------------------------------------------------------------

=head2 runnables

  Arg [1]   : None
  Function  : Returns the list of Bio::Tools::Run::Search objects
              registered with the object
  Returntype: @runnables (array of Bio::Tools::Run::Search::* objs)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub runnables{
  my $self = shift;
  my @ret = ();
  foreach( @{$self->{-runnables}} ){
    next if ! $_;
#    $_->retrievable;
    $_->retrieve( undef, $self->adaptor ) if $_->retrievable;
    push @ret, $_;
  }
  return @ret;
}

#----------------------------------------------------------------------

=head2 runnables_like

  Arg [1]   : -species=>$species
              -database=>$database
              -seq=>$seqID
              -ticket=>$runnable_ticket
  Function  : Returns list of Bio::Tools::Run::Search objects passing species, 
              database, sequence and ticket criteria
  Returntype: @runnables (array of Bio::Tools::Run::Search::* objs)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub runnables_like {
   my $self = shift;
   my %opts = @_;

   # Take an array slice
   my @indexes = $self->_runnable_indexes_like( %opts );

   my @runnables = $self->_runnables_by_indexes(@indexes);
   
   # Check for runnable token
   if( my $tid = $opts{-token} ){
     @runnables = grep{ $_->token eq $tid } @runnables
   }

   # Handle storable
   map{ $_->retrieve( undef, $self->adaptor ) if $_->retrievable } @runnables;

   # Check for result token
   if( my $rid = $opts{-result_token} ){
     @runnables = grep{ $_->result->token eq $rid } @runnables;
   }
   
   return @runnables;
}

#----------------------------------------------------------------------

=head2 _runnables_by_indexes

  Arg [1]   : 
  Function  : Maps list of indexes to runnables
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _runnables_by_indexes {
  my $self = shift;
  my @indexes = @_;
  return grep{ $_ } map{ $self->{-runnables}->[$_] } @indexes;
}

#----------------------------------------------------------------------

=head2 _runnable_indexes_like

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _runnable_indexes_like {
  my $self = shift;
  my %opts = @_;

  # Runnables stored in a tree structure keyed off method, database
  # and seq

  # Root node
  my @avail = ( $self->{-runnable_index} );
  
  # All conforming method nodes
  @avail = map{ $opts{-method} ? 
		$_->{$opts{-method}} : 
		values %{$_} } @avail;
  
  # All conforming database nodes
  @avail = map{ $opts{-database} ?
		 $_->{$opts{-database}} :
                 values %{$_} } @avail;

  # All conforming sequence nodes
  @avail = map{ $opts{-seq} ?
		$_->{$opts{-seq}} :
                values %{$_} } @avail;

  return @avail;
}



#----------------------------------------------------------------------

=head2 remove

  Arg [1]   : None
  Function  : Remove the object + any child objects
  Returntype: Boolean
  Exceptions:
  Caller    :
  Example   :

=cut

sub remove {
  my $self = shift;

  # Remove child objects (probably leaves method templates)
  foreach my $search( $self->runnables ){
    if( $search->isa('Bio::Root::Storable') and $search->retrievable ){
      $search->retrieve( undef, $self->adaptor );
    }
    $search->remove if $search->can('remove');
  }

  # Remove tempdir
  $self->rmtree( $self->{_tempdir} );

  return $self->SUPER::remove(@_);
}

#----------------------------------------------------------------------

=head2 run

  Arg [1]   : 
  Function  : initialises and runs all runnables in the 'PENDING' state
  Returntype: Integer - count of sucessful runnings
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub run {
  my $self = shift;
  $self->_initialise_runnables;
  my $count = 0;
  foreach my $runnable( $self->runnables() ){
    $runnable->status eq 'COMPLETED' && next;
    $runnable->run;
    $count++;
  }
  $self->debug( "Dispatched $count jobs\n" );
  return $count;
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
      foreach my $sid( keys %{$self->{-seqs}} ){
	if( defined( $self->{-runnable_index}->{$me}->{$db}->{$sid} ) ){next}

	my $factory = $self->{-methods}->{$me};
	$factory->retrievable && $factory->retrieve( undef, $self->adaptor );
	# Update factory status to prevent any more parameters being set
	$factory->status("RUNNING"); 

	my $run_obj = $factory->new(
				    -database=>$db,
				    -seq=>$self->{-seqs}->{$sid},
				    -workdir=>$self->workdir,
				   );
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

#----------------------------------------------------------------------
1;
