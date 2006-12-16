
=head1 NAME

Bio::Tools::Run::Search - Driver for running Sequence Database Searches

=head1 SYNOPSIS

  use Bio::Tools::Run::Search;
  # method can be 'ssaha', 'blast'
  my $runnable = new Bio::Tools::Run::Search( -method => 'blast' );
  $runnable->database( $database ); #Database string
  $runnable->seq( $seq );           #Bio::SeqI object
  $runnable->run; # Launch the query
  # Wait for runnable to complete
  while( $runnable->status eq 'RUNNING' ){ wait( 10 ) }

  # Get the Bio::Search::Result::ResultI object
  my $result = $runnable->result;

=head1 DESCRIPTION

A driver for running Sequence Database Searches (blast, ssaha
etc). This object serves as a wrapper for the methods in
Bio::Tools::Run::Search::*, (similar approach SeqIO and SearchIO).

Search results are available as Bio::Search::Result::ResultI objects,
or as raw output produced by the search method.

A ticketing system has been implemented to allow Bio::Tools::Run::Search
objects to be safely saved to disk and recovered.

=cut

# Let the code begin...
package Bio::Tools::Run::Search;

use strict;
use Data::Dumper qw( Dumper );
use vars qw(@ISA);

#use Bio::Root::Root;
use Bio::Root::Root;
use Bio::Root::Storable;
use Bio::Root::IO;
use Bio::SearchIO;
use Bio::SeqIO;
use Bio::Search::Result::ResultFactory;

use Bio::Search::Result::GenericResult;
use Bio::Tools::Run::WrapperBase;
use Bio::Event::EventGeneratorI;

@ISA = qw( Bio::Root::Root
	   Bio::Root::Storable 
	   Bio::Tools::Run::WrapperBase 
	   Bio::SearchIO ); 

#----------------------------------------------------------------------

=head2 new

  Arg [1]   : -method         => $method_str
              -database       => $database_str
              -seq            => $bio_seq_obj
              -id             => ID string
              -options        => hashref of method-specific options
       -environment_variables => hashref of method-specific env variables
              -priority       => Assigns priority to job - 
                                 used with job submission systems
  Function  : Instantiation finction for Bio::Tools::Run::Search::* objects
              Includes copy constructor
  Returntype: Bio::Tools::Run::Search::* object
  Exceptions: 
  Caller    : 
  Example   : $search = Bio::Tools::Run::Search->new(-method=>'wublastn');

=cut

sub new {
  my($caller,@args) = @_;
  my $class = ref($caller) || $caller;

  my %opts = @args;
  @opts{ map { lc $_ } keys %opts } = values %opts; # lowercase keys

  if( $class =~ /Bio::Tools::Run::Search::(\S+)/ ){ # Method class
    if( ref($caller) ){ # Copy constructor

      # General attributes
      $opts{-verbose}        ||= $caller->verbose;

      # Bio::Root::Storable attributes
      $opts{-workdir}        ||= $caller->workdir;
      $opts{-template}       ||= $caller->template;
      $opts{-suffix}         ||= $caller->suffix;

      # Bio::SearchIO attributes
      $opts{-result_factory} ||= $caller->_eventHandler->factory('result');
      $opts{-hit_factory}    ||= $caller->_eventHandler->factory('hit');
      $opts{-hsp_factory}    ||= $caller->_eventHandler->factory('hsp');

      # Bio::Tools::Run::Search attributes
      $opts{-seq}            ||= $caller->seq;
      $opts{-database}       ||= $caller->database;
      $opts{-priority}       ||= $caller->priority;
      $opts{-id}             ||= $caller->id;
      if( ! defined( $opts{-options} ) ){
        $opts{-options} = 
          { map{$_, [ $caller->option($_) ] } 
            $caller->option };
      }
      if( ! defined( $opts{-environment_variables} ) ){
        $opts{-environment_variables} = 
          { map{ $_, $caller->environment_variable($_) } 
            $caller->environment_variable };
      }
    }

    my $self = $class->SUPER::new( %opts );
    $self->{-method} = $1;
    $self->_initialise_storable( %opts );
    $self->_initialise_search(%opts);
    return $self;
  }
  else{ # Parent class
    my $method = $opts{-method} || $class->throw( 'Need a method arg' );
    $method = lc( $method );
    my $new_class = "${class}::${method}";
    $class->_load_module($new_class);
    return $new_class->new(@args);
  }
}

#----------------------------------------------------------------------

=head2 _initialise_search

  Arg [1]   : 
  Function  : Internal method called from new 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _initialise_search {
  my $self = shift;
  my @args = @_;
  my %opts = @args;

  my $PS = $Bio::Root::IO::PATHSEP;

  # Create a SearchIO::EventHandler
  my $sreb = Bio::SearchIO::SearchResultEventBuilder->new
    (-verbose=>$self->verbose);
  $self->attach_EventHandler($sreb);

  my( $seq, $database, $resfact, $hitfact, $hspfact, $priority, $id,
      $opts, $envs, $params ) =
    $self->_rearrange([qw( SEQ
			   DATABASE
			   RESULT_FACTORY 
			   HIT_FACTORY
			   HSP_FACTORY
			   PRIORITY
			   ID 
			   OPTIONS 
			   ENVIRONMENT_VARIABLES
			   PARAMETERS )], @args);

  $resfact  && $self->_eventHandler->register_factory('result', $resfact );
  $hitfact  && $self->_eventHandler->register_factory('hit', $hitfact );
  $hspfact  && $self->_eventHandler->register_factory('hsp', $hspfact );

  $seq      && $self->seq( $seq );
  $database && $self->database( $database );

  $priority && $self->priority( $priority );
  $id       && $self->id( $id );
  if( $opts ){
    if( ref($opts) ne 'HASH' ){ 
      $self->throw( "-options must be a hashref" ) 
    }
    map{ $self->option( $_, $opts->{$_} ) } keys %$opts;
  }
  if( $envs ){
    if( ref($envs) ne 'HASH' ){ 
      $self->throw( "-environment_variables must be a hashref" ) 
    }
    map{ $self->environment_variable( $_, $envs->{$_} ) } keys %$envs;
  }
  if( $params ){
    $self->warn( "-params is deprecated, use -options instead" );
    if( ref($params) ne 'HASH' ){ 
      $self->throw( "-parameters must be a hashref" ) 
    }
    map{$self->option($_, $params->{$_} ) } keys %$params;
  }

  return 1;
}

#----------------------------------------------------------------------

=head2 fastafile

  Arg [1]   : none
  Function  : Retrieves the filesystem location of the
              query fasta file
  Returntype: string: path to fastafile
  Exceptions: 
  Caller    : 
  Example   : $seq_io = Bio::SeqIO->new( -file=>$search->fastafile );

=cut

sub fastafile {
  my $key = "_fastafile";
  my $self = shift;
  $self->{$key} ||= $self->statefile . ".fasta";
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 reportfile

  Arg [1]   : none
  Function  : Retrieves the filesystem location of the
              search report file
  Returntype: string: path to reportfile
  Exceptions: 
  Caller    : 
  Example   : if( -e $search->reportfile ){ print "Report generated" }

=cut

sub reportfile {
  my $key = "_reportfile";
  my $self = shift;
  $self->{$key} ||= $self->statefile . ".out";
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 resultfile

  Arg [1]   : none
  Function  : DEPRECATED
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub resultfile {
  my $self = shift;
  my $caller = join(', ', (caller(0))[1..2] );
  my $class  = (caller(0))[3];
  $self->warn( "Deprecated $class; use reportfile method instead: $caller" );
  return $self->reportfile(@_);
}

#----------------------------------------------------------------------

=head2 errorfile

  Arg [1]   : none
  Function  : Retrieves the filesystem location of the 
              search error file
  Returntype: string: path to errorfile
  Exceptions: 
  Caller    : 
  Example   : if( -e $search->errorfile ){ print "Errors generated" }

=cut

sub errorfile {
  my $key = "_errorfile";
  my $self = shift;
  $self->{$key} ||= $self->statefile . ".fail";
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 program_name

  Arg [1]   : $program_name string (optional)
  Function  : Accessor for the name of the search program
  Returntype: $program_name string
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub program_name {
  my $key = "_program_name";
  my $self = shift;
  if( @_ ){
    my $new = shift;
    if( ( ! defined( $self->{$key} ) and defined( $new ) ) or
	( defined( $self->{$key} ) and ! defined( $new ) ) or
	$self->{$key} ne $new ){
      $self->modified(1);
      $self->{$key} = $new;
    }
  }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 program_dir

  Arg [1]   : $program_dir string (optional)
  Function  : Accessor for the filesystem directory containing
              the search program
  Returntype: $program_dir string 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub program_dir {
  my $key = "_program_dir";
  my $self = shift;
  if( @_ ){
    my $new = shift;
    if( ( ! defined( $self->{$key} ) and defined( $new ) ) or
	( defined( $self->{$key} ) and ! defined( $new ) ) or
	$self->{$key} ne $new ){
      $self->modified(1);
      $self->{$key} = $new;
    }
  }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 option

  Arg [1]   : string (optional)
  Arg [2]   : string or arrayref (optional)
  Function  : Used to get/set search method optional parameters..
              Without args; returns all options as a list.
              With a single arg in scalar context; returns a single 
                value for the named option.
              With a single arg in list context; returns a list of 
                values for the named option.
              With two args; sets the value (2nd arg) for the named
                option (first arg)
  Returntype: scalar or list, depending on invocation
  Exceptions: 
  Caller    : 
  Example   : $search->option( 'single_value','foo' );
              $search->option( 'multiple_value',['foo','bar'] );
              $val  = $search->option( 'single_value' );
              @vals = $search->option( 'multiple_value' );
              foreach $opt( $search->option ){ print "Option: $opt \n" }

=cut

sub option {
  my $self = shift;

  $self->{_options} ||= {};

  if( ! @_ ){ 
    # Return options list
    return( keys %{$self->{_options}} )
  };
  my $name = shift;
  if( @_ ){

    # Untaint name shell metachars
    my $clean_name;
    if( $name =~ /^([+-=\w.]+)$/ ){ $clean_name = $1 }
    else{ $self->throw( "$name is an invalid parameter name" ) } 
    $name = $clean_name;

    # Set new value
    my $val_ref = shift;
    if( ref( $val_ref ) ne 'ARRAY' ){ $val_ref = [$val_ref] } 

    if( ! defined $val_ref->[0] ){ # Explicit delete of param
      delete( $self->{_options}->{$name} );
      return wantarray ? () : undef;
    }

    foreach my $value( @$val_ref ){

      # Untaint for shell metachars
      $value =~ s/[""''``]//g; # Strip quotes
      my $clean_value;
      if( $value =~ /^([+-\@\w\s.]*)$/){ $clean_value = $1 }
      else{ $self->throw( "$value is an invalid parameter value" ) }
      $value = $clean_value;
    }
    my $old = join('', sort $self->option($name) ); 
    my $new = join('', sort @$val_ref );
    if( ( $old ne $new ) or ! exists( $self->{_options}->{$name} ) ){
      $self->modified(1);
      $self->{_options}->{$name} = $val_ref;
    }
  }

  my $val_ref = $self->{_options}->{$name};
  my @values = ref($val_ref) eq 'ARRAY' ? @{$self->{_options}->{$name}} : ();
  return wantarray ? @values : $values[0];
}

#----------------------------------------------------------------------

=head2 environment_variable

  Arg [1]   : string (optional)
  Arg [2]   : string (optional)
  Function  : Used to get/set environment variables required by the search 
              method.
              Without args; returns all variables as a list.
              With a single arg; returns the single value for the named var.
              With two args; sets the value (2nd arg) for the named
                var (first arg)
  Returntype: scalar
  Exceptions: 
  Caller    : 
  Example   : $search->environment_variable( 'PATH','/usr/local/bin' );
              $val  = $search->environment_variable( 'PATH' );
              foreach $var( $search->environment_variable ){ print "$var" }
              
=cut

sub environment_variable {
  my $self = shift;

  $self->{_environment_variables} ||= {};

  if( ! @_ ){ 
    # Return options list
    return( keys %{$self->{_environment_variables}} )
  };

  my $name = shift;
  if( @_ ){
    $name || $self->throw( "Missing envirinment variable name" );
    # Untaint name shell metachars
    my $clean_name;
    if( $name =~ /^([+-=\w.]+)$/ ){ $clean_name = $1 }
    else{ $self->throw( "$name is an invalid envirinment variable name" ) } 
    $name = $clean_name;

    # Set new value
    my $value = shift;

    if( defined $value ){
      # Untaint for shell metachars
      $value =~ s/[""''``]//g; # Strip quotes
      my $clean_value;
      if( $value =~ /^([+-\@\w\s.]*)$/){ $clean_value = $1 }
      else{ $self->throw( "$value is an invalid parameter value" ) }
      $value = $clean_value;
    }
    my $old_value = $self->option($name);
    if(  ! defined( $old_value ) or
	 !  defined( $value ) and defined( $old_value ) or
	 $value ne $old_value ){
      $self->modified(1);
      $self->{_environment_variables}->{$name} = $value;
    }
  }
  
  return $self->{_environment_variables}->{$name};
}

#----------------------------------------------------------------------

=head2 database

  Arg [1]   : $database_str scalar optional
  Function  : Accessor for method-specific locator of sequence database 
  Returntype: $database_str scalar
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub database {
  my $key = '_database';
  my $self  = shift;
  my $value = shift;

  if( $value ){
    if( $self->{$key} ){ $self->throw("Database already initialised.") }
    $self->modified(1);
    $self->{$key} = $value;
    $self->result->database_name( $value );
  }
  return( $self->{$key} );
}

#----------------------------------------------------------------------

=head2 seq

  Arg [1]   : Bio::SeqI compliant object (optional)
  Function  : Accessor for Bio::SeqI compliant object representing the 
              query sequence. If a new sequence is provided, the query
              result is initialised with relevent sequence attributes. 
  Returntype: Bio::SeqI compliant object
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub seq{ 
  my $key = '-seq';
  my $self = shift;
  my $seq = shift;
  if( $seq ){
    if( $self->{$key} ){ $self->throw("Seq object already initialised.") }
    unless( ref( $seq ) && $seq->isa( 'Bio::Seq' ) ){
      $self->throw('Need a Bio::Seq object');
    } 
    $self->modified(1);
    # --- TODO - Move fastafile manipulation to the 'run' method.
    my $fastafile = $self->statefile . ".fasta";
    my $out = Bio::SeqIO->new( -file   => ">".$self->fastafile, 
			       -format => 'Fasta');
    $out->write_seq($seq);
    # ---

    $self->{$key} = $seq;
    my $res = $self->result;
    $res->query_name( $seq->display_id );
    $res->query_accession( $seq->accession_number );
    $res->query_description( $seq->desc);
    $res->query_length( $seq->length );
  }

  # Handle storable seq
  if( $self->{$key} and
      $self->{$key}->isa('Bio::Root::Storable') and
      $self->{$key}->retrievable ){
    $self->{$key}->retrieve( $self->adaptor );
  }

  return( $self->{$key} );
}

#----------------------------------------------------------------------

=head2 algorithm

  Arg [1]   : none
  Function  : Returns the algorithm associated with the search method.
              Defaults to program_name.
  Returntype: $algorithm scalar
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub algorithm{ shift->program_name }

#----------------------------------------------------------------------

=head2 id

  Arg [1]   : $id scalar optional
  Function  : Getter/setter for those occasions when you need to 
              attach an ID to the Search object
  Returntype: $id scalar
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub id {
  my $key  = '_id';
  my $self = shift;
  if( @_ ){ 
    my $new = shift;
    if( $new ne $self->{$key} ){
      $self->modified(1);
      $self->{$key} = $new;
    }
  }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 format

  Arg [1]   : None
  Function  : Returns the Bio::SearchIO format required to parse the 
              search report 
  Returntype: $format scalar
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub format{ shift->throw_not_implemented() }

#----------------------------------------------------------------------

=head2 priority

  Arg [1]   : $priority scalar
  Function  : Arbitrary priority for the job. 
              Used when scheduling multiple jobs (e.g. bsub)
  Returntype: $priority scalar
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub priority{
  my $key = "_priority";
  my $self = shift;
  if( @_ ){ 
    my $new = shift;
    if( $new ne $self->{$key} ){
      $self->modified(1);
      $self->{$key} = $new;
    }
  }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 status

  Arg [1]   : $status scalar
  Function  : Accessor for object status. 
              The following states are currently supported:
              UNKNOWN, PENDING, RUNNING, COMPLETED, 
  Returntype: $status scalar
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub status {
  my %STATES = 
    ( 
     'UNKNOWN'    => 1,
     'PENDING'    => 1,
     'DISPATCHED' => 1,
     'RUNNING'    => 1,
     'COMPLETED'  => 1,
     'FAILED'     => 1,
    );  
  my $key  = '-status';
  my $self = shift;
  my $status = shift;

  if( ! $status and ! $self->{$key} ){ $self->{$key} = 'UNKNOWN' }

  if( $self->{$key} eq 'UNKNOWN' && $self->seq && $self->database ){
    $self->modified(1);
    $self->{$key} = 'PENDING';
  }

  if( $status ){
    if( ! $STATES{$status} ){ $self->throw( "Status $status is invalid" ) }
    if( $self->{$key} ne $status ){
      $self->modified(1);
      $self->{$key} = $status;
    }
  }
  return $self->{$key};
}

#----------------------------------------------------------------------

=head2 result

  Arg [1]   : Bio::Search::Result::ResultI object optional
  Function  : Returns the Result object associated with this Search
              A skeleton result will be created if none exists
  Returntype: Bio::Search::Result::ResultI object
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub result{ 
  my $self = shift;

  if( @_ ){ 
    my $res = shift;
    $res->isa( 'Bio::Search::Result::ResultI' ) or
      $self->throw( "Need a Bio::Search::Result::ResultI compliant obj" );

    # Try to populate missing query data from seqobj.
    # Used when method (e.g. SSAHA) report is missing this data
    my $seq;
    if( ! $res->query_length ){
      $seq ||= $self->seq;
      $seq && $res->query_length($seq->length);
    }
    if( ! $res->query_name ){
      $seq ||= $self->seq;
      $seq && $res->query_name($seq->display_id);
    }
    if( ! $res->query_name ){
      $seq ||= $self->seq;
      $seq && $res->query_description($seq->description);
    }

    $self->{-result} = $res; 
    $self->modified(1);
  }

  if( $self->{-result} and
      $self->{-result}->isa('Bio::Root::Storable') and 
      $self->{-result}->retrievable ){
    # Handle retrievable result
    $self->{-result}->adaptor( $self->adaptor );
    $self->{-result}->retrieve( );
  }

  if( ! $self->{-result} ){
    # Create skeleton result of the correct class
    my %args = ( -algorithm =>$self->algorithm,
		 -version   =>$self->version, 
		 -verbose   =>$self->verbose );
    my $skel_result = $self->_eventHandler->factory('result')->create(%args);
    if( $skel_result->isa('Bio::Root::Storable') ){
      $skel_result->adaptor( $self->adaptor );
    }
    $self->result( $skel_result );
  }

  return $self->{-result};
}

#----------------------------------------------------------------------

=head2 next_result

  Arg [1]   : None
  Function  : Alias for 'result' method for SearchIO compliance; 
              Search can only handle a single result at present. 
  Returntype: Bio::Search::Result::ResultI object
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub next_result{ return shift->result(@_) }


#----------------------------------------------------------------------

=head2 result_count

  Arg [1]   : None
  Function  : Added for SearchIO compliance;
              Search can only handle a single result at present.
  Returntype: 1
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub result_count {
   my $self = shift;
   return 1;
}

#----------------------------------------------------------------------

=head2 remove

  Arg [1]   : None
  Function  : Cleanup of files associated with this object.
              This method should be overloaded to perform method-specific 
              cleanup, e.g. to cacel jobs that may be running already. 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub remove {
  my $self = shift;

  # Remove child object
  my $res = $self->result;
  $res->remove if $res->can('remove');

  # Clean up search-specific temp files
  unlink( $self->fastafile );
  unlink( $self->reportfile );
  unlink( $self->errorfile );
  return $self->SUPER::remove();
}


#----------------------------------------------------------------------

=head2 report

  Arg [1]   : None
  Function  : Returns the text of the raw search report. Available only
              after search completes 
  Returntype: string
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub raw_results{
  my $self = shift;
  my $caller = join(', ', (caller(0))[1..2] );
  my $class  = (caller(0))[3];
  $self->warn( "Deprecated $class; use report method instead: $caller" );
  return $self->report(@_);
}

sub report{
   my $self = shift;
   if( $self->status ne 'COMPLETED' ){
     $self->warn( 'Should not call results until search is complete');
   }
   my $io = Bio::Root::IO->new( $self->reportfile );
   local $/=undef();
   return $io->_readline;
}
#----------------------------------------------------------------------

=head2 serialise

  Arg [1]   : 
  Function  : As Search ISA SearchIO, need to clear 'io' before stringifying obj.
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub serialise {
  my $self = shift;
  if( exists $self->{'io'} ){ delete  $self->{'io'} }
  return $self->SUPER::serialise(@_);
}

#----------------------------------------------------------------------

=head2 DESTROY

  Arg [1]   : none
  Function  : Cleanup routine. Does nothing at present.
  Returntype: none
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub DESTROY{ }

#----------------------------------------------------------------------

=head2 run

  Arg [1]   : None
  Function  : Fires off the search-specific command
  Returntype: Boolean
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub run{ 
  my $self = shift;

  if( $self->status ne 'PENDING' and
      $self->status ne 'DISPATCHED' ){
    $self->warn( "Wrong status for run: ". $self->status );
  }

  # Apply environment variables
   my %ENV_TMP = %ENV;
  local %ENV = %ENV;
  foreach my $env(  $self->environment_variable() ){
    my $val = $self->environment_variable( $env );
    if( defined $val ){ $ENV{$env} = $val }
    else{ delete( $ENV{$env} ) }
  }

  $self->{'_pathtoexe'} = undef(); # Hack to stop WrapperBase caching exe

  my $command;
  eval{ $command = $self->command() };
  if( $@ ){
    my $msg = "Command could not be constructed\n$@";
    $self->warn( $msg );
    open( ERR, ">>".$self->errorfile );
    print ERR $msg;
    close ERR;
    $self->status( "FAILED" );
    return;
  }
  $self->debug( $command."\n" );
  
  my $retval;
  $self->status( "RUNNING" );
  #warn( "==================================== RUN" ); 
  eval{ $retval = $self->dispatch( $command ) };
  #warn( "==================================== RUN" );
  if( $@ ){
    my $msg = "Command $command failed\n$@";
    $self->warn( $msg );
    open( ERR, ">>".$self->errorfile );
    print ERR $msg;
    close ERR;
    $self->status( "FAILED" );
    return 
  }

  # Restore environment
  %ENV = %ENV_TMP;

  return $retval;
}

#----------------------------------------------------------------------

=head2 executable

  Arg [1]   : 
  Function  : Same as SUPER, but checks if PATH set in environment_variable
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub executable {
   my $self = shift;
   my $new_path = $self->environment_variable('PATH');
   $new_path and local $ENV{PATH} = $new_path;
   return $self->SUPER::executable();
}

#----------------------------------------------------------------------

=head2 dispatch

  Arg [1]   : string: command to run
  Function  : Runs the supplied command using 'system'.
              Calls parse if the seach returns a report file.
              The command should be constructed such that
              the search report goes into $self->reportfile, and any
              error goes into $self->errorfile. 
              This method may well be subclassed, e.g. for offline dispatch.
  Returntype: boolean: 1 on success.
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub dispatch {
  my $self = shift;
  my $command  = shift ||$self->throw( "Need a command" );
#warn "$command";
  my $ret = system( "$command");
  my $reportfile  = $self->reportfile;
  my $errorfile    = $self->errorfile;
  #warn "XXX $ret XXX";
#  if( $ret == 0 ){
    # Command successful
#warn "HERE  ",$self->reportfile;
    if( -r $self->reportfile ){
      # Reportfile generated
#warn "PARSING report file $@";
      eval{ $self->parse };
#warn "PARSED report file $@";
      if( ! $@ ){
#warn "PARSING SUCCEEDED";
	# Parsing successful
	$self->status("COMPLETED");
#warn "STATUS SET";
	unlink( $errorfile );
#warn "RETURNING SUCCESSFULLY";
	return 1;
      }
      else{
#warn "PARSING FAILED";
	# Parsing failed 
	$self->throw( "Parsing failed\n$@" );
      }
    }
    else{ # Strange - no result file!
#warn "NO RESULTS";
      $self->throw( "Result set $reportfile does not exist" );
    }
#  }
#  else{ # Command itself failed
#warn "FAILURE!! $ret";
#    $self->throw( "system failed: $!\n    $command" );
#  }
#warn "RETURNING";
  return;
}
#----------------------------------------------------------------------

=head2 parse

  Arg [1]   : 
  Function  : Parses the search report file into BioPerl Search objects
              There are ensembl specific calls in here that need removing.
  Returntype: boolean: true on success
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub parse {
  my $self = shift;
  -r $self->reportfile || $self->throw( "Cannot parse without result file" );
  
  my $dummy_result = $self->result || 
    $self->throw( "$self has no dummy result" );

  my $searchio = Bio::SearchIO->new
    ( -verbose => $self->verbose,
      -format  => $self->format,
      -file    => $self->reportfile, );

#warn "HERE....";
  $searchio->attach_EventHandler( $self->_eventHandler );
  my $result = $searchio->next_result;

#warn "HERE...2";
  if( $result ){
    if( $result->isa('Bio::Root::Storable') ){
#warn "AT ADAPTOR";
      $result->adaptor( $self->adaptor );
    }
    if( $result->can("map_to_genome") ){ # EnsemblResult specific method
#warn "MAP TO GENOME";
      # TODO Move Ensembl-specific code out of Search.pm
#warn "ATTACHING CORE ADAPTOR";
      $result->core_adaptor    ( $dummy_result->core_adaptor );
#warn "SETTING DB NAME...";
      $result->database_name   ( $dummy_result->database_name );
#warn "INT";
      $result->database_species( $dummy_result->database_species );
#warn "TYPE";
      $result->database_type   ( $dummy_result->database_type );
#warn "MAP TO GENOME ...",ref($result);
      $result->map_to_genome;
    }
#warn "STOrE";
    $self->result( $result );
#warn "STOrEd";
  }
  else{
    $self->warn( "Search returned no result" );
  }
  
  return 1;
}

#----------------------------------------------------------------------
=head2 command,parameter_options

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub command{ $_[0]->throw_not_implemented() }
sub parameter_options{ $_[0]->throw_not_implemented() }
#----------------------------------------------------------------------
1;
