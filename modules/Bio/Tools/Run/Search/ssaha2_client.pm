
=head1 NAME

Bio::Tools::Run::Search::ssaha2_client - Ensembl search runnable for SSAHA2

=head1 SYNOPSIS

  # Do not use this object directly - it is used as part of the
  # Bio::SearchIO system.
  use Bio::Tools::Run::Search;
  my $runnable = Bio::Tools::Run::Search(-method=>'ssaha2_client')
  $runnable->database( $database ); #Database string
  $runnable->seq( $seq );           #Bio::SeqI object
  $runnable->run; # Launch the query

  my $result = $runnable->next_result; #Bio::Search::Result::* object

=head1 DESCRIPTION

This object encapsulates methods for running SSAHA sequence database
search queries within the Ensembl web framework. Read the
L<Bio::Tools::Run::Search> docs for more information about how to use this.

=cut

# Let the code begin...
package Bio::Tools::Run::Search::ssaha2_client;

use strict;
use Data::Dumper;
use vars qw( @ISA 
	     $ALGORITHM $VERSION $SEARCHIO_FORMAT 
	     $DEFAULT_KMER_LENGTH $PARAMETER_OPTIONS $PROGRAM_NAME);

use Bio::Tools::Run::Search;
use IO::Socket;

@ISA = qw( Bio::Tools::Run::Search );

BEGIN{
  $SEARCHIO_FORMAT   = 'ssaha2';
  $ALGORITHM  = 'SSAHA';
  $VERSION    = 'Unknown';
  $PROGRAM_NAME  = 'ssaha2Client.pl';
  $PARAMETER_OPTIONS = 
    {
     '-depth' =>
     {
      default => 100,
      order   => 10,
      options => [1,5,10,50,100,500,1000,5000],
      description => qq( 
Output only the top 'n' matches for each query, sorted by number
of matching bases, then by subject name, then by start position in the
query sequence ),
     },

     '-seeds' =>
     {
      default => 2,
      order   => 20,
      options => [1,2,5,10,50,100],
      description => qq(
The minimum number of matching k-mers (typical length 12bp) required
to seed an alignment ),
     },

     '-score' =>
     {
      default => 20,
      order   => 30,
      options => [10,20,50,100,500,1000],
      description => qq(
Raw score threshold; alignments that score below this will not be
reported ),
     },
    };
  }
#----------------------------------------------------------------------

sub program_name{ 
  my $self = shift;
  my $pname = $self->SUPER::program_name(@_);
  return defined( $pname ) ?  $pname : $PROGRAM_NAME;
}
sub algorithm         { return $ALGORITHM }
sub format            { return $SEARCHIO_FORMAT }
sub parameter_options { return $PARAMETER_OPTIONS }

#----------------------------------------------------------------------

=head2 command

  Arg [1]   : None
  Function  : generates the shell command to run
              the ssaha query
  Returntype: String: $command
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub command {
  my $self = shift;

  if( ! -f $self->fastafile ){ $self->throw("Need a query sequence!") }

  my $exe = $self->executable ;
  $exe || $self->throw( "Executable for ". ref($self) . " undetermined" );
  -e $exe || $self->throw( "$exe does not exist" );
  -X $exe || $self->throw( "$exe is not executable bu UID/GID" );

  my( $host, $port ) = $self->_get_server();

  my $param_str = '';
  foreach my $param( $self->option ){
    my $val = $self->option($param);
    $param_str .= " $param $val";
  }
  $param_str =~ s/[;`&|<>\s]+/ /g;
  my $command = 
    join( ' ',  $exe, -server, $host, -port, $port, -align, 1, $param_str );

  my $fastafile   = $self->fastafile;
  my $reportfile  = $self->reportfile;
  my $errorfile    = $self->errorfile;
  my $hack_to_ensure_false = "; echo ''";
  return "cat $fastafile | $command 1>$reportfile 2>$errorfile $hack_to_ensure_false";

}
#----------------------------------------------------------------------

=head2 database

  Arg [1]   : 
  Function  : Same as SUPER, but verifies that the database is a name:port
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub database {
   my $self = shift;
   if( @_ ){
       my ($host, $port) = split( ':', $_[0], 2 ); 
       $port ||  
	 $self->throw("Bad format for ssaha search DB: ".$_[0].
		      ". Use host:port" );
   }
   return $self->SUPER::database(@_);
}

#----------------------------------------------------------------------
=head2 _get_server

  Arg [1]   : None
  Function  : Internal method to convert the database string into a 
              SSAHA host and port. Database string must be in format of:
              host:port
  Returntype: array - $host, $port
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _get_server{
  my $self = shift;
  
  my $database = $self->database;

  my ($host, $port ) = split( ':', $database, 2 ); 
  $port ||  
    $self->throw("Bad format for ssaha search DB: ".$database.
		 ". Use host:port" );

  # Test to see whether the server is responding
  my $status = 1;
  my $error  = '';
  for( my $i=0; $i<5; $i++ ){ # Allow up to 5 attempts to contact the server
    eval{
      my $socket = IO::Socket::INET->new( PeerAddr => $host,
					  PeerPort => $port,
					  Timeout  => 1     ) 
	or die( "$@ $host:$port" );
    };
    if( $@ ){ $status = 0; alarm(0); $error=$@; $self->debug($@) }
    else{     $status = 1; last; }
  }
  if( ! $status ){
    $self->throw( "SSAHA2 server unavailable: $error" )
  }

  return( $host, $port );
}


#----------------------------------------------------------------------

1;

