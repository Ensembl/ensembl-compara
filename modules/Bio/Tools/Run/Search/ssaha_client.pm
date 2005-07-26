
=head1 NAME

Bio::Tools::Run::Search::ssaha_client - Search runnable for ssahaClient

=head1 SYNOPSIS

  # Do not use this object directly - it is used as part of the
  # Bio::Tools::Run::Search system.
  use Bio::Tools::Run::Search;
  my $runnable = Bio::Tools::Run::Search(-method=>'ssaha_client')
  $runnable->database( $database ); #DB string, eg localhost:50001
  $runnable->seq( $seq );           #Bio::SeqI object for query
  $runnable->run; # Launch the query

  my $result = $runnable->next_result; #Bio::Search::Result::* object

=head1 DESCRIPTION

This object extends Bio::Tools::Run::Search (sequence database
searching framework) to encompass SSAHA's ssahaClient executable. Read
the L<Bio::Tools::Run::Search> docs for more information about how to
use this.

=cut

# Let the code begin...
package Bio::Tools::Run::Search::ssaha_client;

use strict;
use Data::Dumper;
use vars qw( @ISA 
             $ALGORITHM $VERSION $SEARCHIO_FORMAT $PROGRAM_NAME
             $DEFAULT_KMER_LENGTH 
             $PARAMETER_OPTIONS );

use Bio::Tools::Run::Search;
use IO::Socket;

@ISA = qw( Bio::Tools::Run::Search );

BEGIN{
  $SEARCHIO_FORMAT   = 'ssaha';
  $ALGORITHM  = 'SSAHA';
  $VERSION    = 'Unknown';
  $PROGRAM_NAME  = 'ssahaClient';

  $DEFAULT_KMER_LENGTH = 13;
  $PARAMETER_OPTIONS = 
    {
     sortMatches =>
     {
      default => 100,
      order   => 10,
      options => [1,5,10,50,100,500,1000,10000],
      description => qq( 
Output only the top 'n' matches for each query, sorted by number
of matching bases, then by subject name, then by start position in the
query sequence ),
     },

     minPrint =>
     {
      default => $DEFAULT_KMER_LENGTH,
      order   => 20,
      options => [$DEFAULT_KMER_LENGTH*1,
                  $DEFAULT_KMER_LENGTH*2,
                  $DEFAULT_KMER_LENGTH*5,
                  $DEFAULT_KMER_LENGTH*10,
                  $DEFAULT_KMER_LENGTH*20,
                  $DEFAULT_KMER_LENGTH*50,
                  $DEFAULT_KMER_LENGTH*100 ],
      description   => qq(
The minimum number of matching bases or residues that must
be found in the query and subject sequences before they are considered
as a match ),
     },

     maxGap =>
     {
      default => $DEFAULT_KMER_LENGTH*1,
      default_EXACT => 0,
      order   => 30,
      options => [0,
                  $DEFAULT_KMER_LENGTH*1,
                  $DEFAULT_KMER_LENGTH*2,
                  $DEFAULT_KMER_LENGTH*5,],
      description   => qq(
Maximum gap allowed between successive hits for them to
count as part of the same match ),
     },

     maxInsert =>
     {
      default => 2,
      default_EXACT => 0,
      order   => 40,
      options => [0,1,2,4,7,13],
      description   => qq(
Maximum number of insertions/deletions allowed between
successive hits for them to count as part of the same
match),
     },

     numRepeats =>
     {
      default => 0,
      order   => 50,
      options => [0,1,2,4,7,13],
      description   => qq(
Maximum size of tandem repeating motif that can be detected
in the query sequence. This option may produce faster and better
matches when dealing with data containing tandem repeats ),
     },

     maxStore =>
     {
      default => 10000,
      order   => 60,
      options => [100,1000,10000,100000,1000000],
      description   => qq(
Largest number of times that a word may occur in the hash
table for it to be used for matching expressed as a multiple of the
number of occurrences per word that would be expected for a random
database of the same size as the subject database ),
     },
    }
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
  my $command = 
    join( ' ', 
	  $exe,
	  $host, $port,
	  $self->option('minPrint')    || 1,
	  $self->option('maxGap')      || 0,
	  $self->option('maxInsert')   || 0,
	  $self->option('numRepeats')  || 0,
	  $self->option('queryType')   || "DNA",
	  $self->option('maxStore')    || 10000,
	  $self->option('sortMatches') || 1000,
	  $self->option('sortMode')    || 'align' );
  
  my $fastafile   = $self->fastafile;
  my $reportfile  = $self->reportfile;
  my $errorfile    = $self->errorfile;
  return "cat $fastafile | $command 1>$reportfile 2>$errorfile";

}
#----------------------------------------------------------------------

=head2 database

  Arg [1]   : 
  Function  : Sane as SUPER, but verifies that the database is a name:port
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

  my $database = $self->database || $self->throw("Must set database first");
  my ($host, $port) = split( ':', $database, 2 );

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
    $self->throw( "SSAHA server unavailable: $error" )
  }

  return( $host, $port );
}


#----------------------------------------------------------------------

1;

