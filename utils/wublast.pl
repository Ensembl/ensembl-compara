#!/usr/bin/env perl
# $Id$
# ======================================================================
# WSWUBlast Perl client.
#
# Requires SOAP::Lite. Tested with versions 0.60, 0.69 and 0.71.
#
# See:
# http://www.ebi.ac.uk/Tools/Webservices/services/wublast
# http://www.ebi.ac.uk/Tools/Webservices/clients/wublast
# http://www.ebi.ac.uk/Tools/Webservices/tutorials/soaplite
# ======================================================================
# WSDL URL for service
my $WSDL = 'http://www.ebi.ac.uk/Tools/webservices/wsdl/WSWUBlast.wsdl';

# Enable Perl warnings
use strict;
use warnings;

# Load libraries
use SOAP::Lite;
use Getopt::Long qw(:config no_ignore_case bundling);
use File::Basename qw(basename);

# Set interval for checking status, see clientPoll().
my $checkInterval = 15;

# Output level
my $outputLevel = 1;

# Process command-line options
my $numOpts = scalar(@ARGV);
my (
	$outfile,       $outformat,      $help,        $async,
	$polljob,       $status,         $ids,         $dbIds,
	$jobid,         $trace,          $sequence,    $quiet,
	$verbose,       $getFormats,     $getMatrices, $getPrograms,
	$getDatabases,  $getSensitivity, $getStats,    $getSort,
	$getXmlFormats, $getFilters
);
my %params = (    # Defaults
	'async'  => 1,       # Use async mode and simulate sync mode in client
	'exp'    => 10.0,    # E-value threshold
	'numal'  => 50,      # Maximum number of alignments
	'scores' => 100,     # Maximum number of scores
);
GetOptions(              # Map the options into variables
	'program|p=s'     => \$params{'program'},      # BLAST program
	'database|D=s'    => \$params{'database'},     # Search database
	'matrix|m=s'      => \$params{'matrix'},       # Scoring matrix
	'exp|E=f'         => \$params{'exp'},          # E-value threshold
	'echofilter|e'    => \$params{'echofilter'},   # Display filtered sequence
	'filter|f=s'      => \$params{'filter'},       # Low complexity filter name
	'alignments|b=i'  => \$params{'numal'},        # Number of alignments
	'scores|s=i'      => \$params{'scores'},       # Number of scores
	'sensitivity|S=s' => \$params{'sensitivity'},  # Search sensitivity
	'sort|t=s'        => \$params{'sort'},         # Sort hits by...
	'stats|T=s'       => \$params{'stats'},        # Scoring statistic to use
	'strand|d=s'      => \$params{'strand'},       # Strand to use
	'topcombon|c=i'   => \$params{'topcombon'},    # Consistent sets of HSPs
	'sequence=s'      => \$sequence,               # Query sequence
	'async|a'         => \$async,                  # Asynchronous mode
	'email=s'         => \$params{'email'},        # E-mail address
	'help|h'          => \$help,                   # Usage info
	'getFormats'      => \$getFormats,             # List result formats
	'outfile|O=s'     => \$outfile,                # Output file
	'outformat|o=s'   => \$outformat,              # Output format
	'polljob'         => \$polljob,                # Get results
	'status'          => \$status,                 # Get job status
	'ids'             => \$ids,                    # Get ids from result
	'jobid|j=s'       => \$jobid,                  # JobId
	'quiet'           => \$quiet,                  # Decrease output level
	'verbose'         => \$verbose,                # Increase output level
	'trace'           => \$trace,                  # SOAP trace
	'getMatrices'     => \$getMatrices,            # List matrices
	'getPrograms'     => \$getPrograms,            # List programs
	'getDatabases'    => \$getDatabases,           # List databases
	'getSensitivity'  => \$getSensitivity,         # List sensitvity options
	'getSort'         => \$getSort,                # List sort options
	'getStats'        => \$getStats,               # List statistical models
	'getXmlFormats'   => \$getXmlFormats,          # List XML formats
	'getFilters'      => \$getFilters,             # List low complexity filters
);
if ($verbose) { $outputLevel++ }
if ($quiet)   { $outputLevel-- }

# Get the script filename for use in usage messages
my $scriptName = basename( $0, () );

# Print usage and exit if requested
if ( $help || $numOpts == 0 ) {
	&usage();
	exit(0);
}

# If required enable SOAP message trace
if ($trace) {
	print STDERR "Tracing active\n";
	SOAP::Lite->import( +trace => 'debug' );
}

# Create the service interface, setting the fault handler to throw exceptions
my $soap = SOAP::Lite->service($WSDL)->proxy(
	'http://localhost/',
	proxy   => [],      #['http' => 'http://your.proxy.server/'], # HTTP proxy
	timeout => 6000,    # HTTP connection timeout
  )->on_fault(
	sub {               # SOAP fault handler
		my $soap = shift;
		my $res  = shift;

		# Throw an exception for all faults
		if ( ref($res) eq '' ) {
			die($res);
		}
		else {
			die( $res->faultstring );
		}
		return new SOAP::SOM;
	}
  );

# List scoring matrices
if ( defined($getMatrices) ) {
	my $matrixInfoListRef = $soap->getMatrices($getMatrices);
	foreach my $matrixInfo (@$matrixInfoListRef) {
		print $matrixInfo->{'name'}, ' ', $matrixInfo->{'print_name'};
		if ( $matrixInfo->{'selected'} eq 'yes' ) {
			print "\t(Default)";
		}
		print "\n\t", $matrixInfo->{'search_type'}, " comparision\n";
	}
}

# List search programs
elsif ( defined($getPrograms) ) {
	my $programInfoListRef = $soap->getPrograms($getPrograms);
	foreach my $programInfo (@$programInfoListRef) {
		print $programInfo->{'name'}, "\t", $programInfo->{'print_name'}, "\n";
		print "\t", $programInfo->{'input_type'}, ' query vs. ',
		  $programInfo->{'data_type'},   ' database; ',
		  $programInfo->{'search_type'}, " search\n";
	}
}

# List databases to search
elsif ( defined($getDatabases) ) {
	my $databaseInfoListRef = $soap->getDatabases();
	foreach my $databaseInfo (@$databaseInfoListRef) {
		print $databaseInfo->{'name'}, "\n";
		print "\t", $databaseInfo->{'print_name'}, "\n";
		print "\t", $databaseInfo->{'data_type'},  "\n";
	}
}

# List sensitivity options
elsif ( defined($getSensitivity) ) {
	my $sensitivityInfoListRef = $soap->getSensitivity();
	foreach my $sensitivityInfo (@$sensitivityInfoListRef) {
		print $sensitivityInfo->{'name'}, "\t",
		  $sensitivityInfo->{'print_name'};
		if ( $sensitivityInfo->{'selected'} eq 'yes' ) {
			print "\t(Default)";
		}
		print "\n";
	}
}

# List hit sort options
elsif ( defined($getSort) ) {
	my $sortInfoListRef = $soap->getSort();
	foreach my $sortInfo (@$sortInfoListRef) {
		print $sortInfo->{'name'}, "\t", $sortInfo->{'print_name'};
		if ( $sortInfo->{'selected'} eq 'yes' ) {
			print "\t(Default)";
		}
		print "\n";
	}
}

# List statistical models
elsif ( defined($getStats) ) {
	my $statsInfoListRef = $soap->getStats();
	foreach my $statsInfo (@$statsInfoListRef) {
		print $statsInfo->{'name'}, "\t", $statsInfo->{'print_name'};
		if ( $statsInfo->{'selected'} eq 'yes' ) {
			print "\t(Default)";
		}
		print "\n";
	}
}

# List XML format options
elsif ( defined($getXmlFormats) ) {
	my $formatInfoListRef = $soap->getXmlFormats();
	foreach my $formatInfo (@$formatInfoListRef) {
		print $formatInfo->{'name'}, "\t", $formatInfo->{'print_name'};
		if ( $formatInfo->{'selected'} eq 'yes' ) {
			print "\t(Default)";
		}
		print "\n";
	}
}

# List low complexity filters
elsif ( defined($getFilters) ) {
	my $filterInfoListRef = $soap->getFilters($getFilters);
	foreach my $filterInfo (@$filterInfoListRef) {
		print $filterInfo->{'name'}, "\t", $filterInfo->{'print_name'};
		if ( $filterInfo->{'selected'} eq 'yes' ) {
			print "\t(Default)";
		}
		print "\n\t", $filterInfo->{'input_type'}, "\n";
	}
}

# List result formats for job
elsif ( defined($getFormats) && defined($jobid) ) {
	if ( $outputLevel > 0 ) {
		print STDERR "Getting output formats for job $jobid\n";
	}
	my $resultTypes = $soap->getResults($jobid);
	foreach my $resultType (@$resultTypes) {
		print $resultType->{'type'}, "\n";
	}
}

# Print usage if bad argument combination
elsif (!( $polljob || $status || $ids || $dbIds )
	&& !( defined( $ARGV[0] ) || defined($sequence) ) )
{
	print STDERR 'Error: bad option combination', "\n";
	&usage();
	exit(1);
}

# Poll job and get results
elsif ( $polljob && defined($jobid) ) {
	if ( $outputLevel > 1 ) {
		print "Getting results for job $jobid\n";
	}
	&getResults($jobid);
}

# Job status
elsif ( $status && defined($jobid) ) {
	if ( $outputLevel > 0 ) {
		print STDERR "Getting status for job $jobid\n";
	}
	my $result = $soap->checkStatus($jobid);
	print STDOUT "$result\n";
	if ( $result eq 'DONE' && $outputLevel > 0 ) {
		print STDERR "To get results: $scriptName --polljob --jobid $jobid\n";
	}
}

# Get hit ids for a result
elsif ( ( $ids || $dbIds ) && defined($jobid) ) {
	if ( $outputLevel > 0 ) {
		print STDERR "Getting ids from job $jobid\n";
	}
	if ($dbIds) {
		&getIds( $jobid, 1 );
	}
	else {
		&getIds( $jobid, 0 );
	}
}

# Submit a job
else {

	# Prepare input data
	my $content;
	if ( defined( $ARGV[0] ) ) {    # Bare option
		if ( -f $ARGV[0] || $ARGV[0] eq '-' ) {    # File
			$content =
			  { type => 'sequence', content => &read_file( $ARGV[0] ) };
		}
		else {                                     # DB:ID or sequence
			$content = { type => 'sequence', content => $ARGV[0] };
		}
	}
	if ($sequence) {                               # Via --sequence
		if ( -f $sequence || $sequence eq '-' ) {    # File
			$content = { type => 'sequence', content => &read_file($sequence) };
		}
		else {                                       # DB:ID or sequence
			$content = { type => 'sequence', content => $sequence };
		}
	}
	my (@contents) = ();
	push @contents, $content;

	# Submit the job
	my $paramsData  = SOAP::Data->name('params')->type( map => \%params );
	my $contentData = SOAP::Data->name('content')->value( \@contents );

	# For SOAP::Lite 0.60 and earlier parameters are passed directly
	if ( $SOAP::Lite::VERSION eq '0.60' || $SOAP::Lite::VERSION =~ /0\.[1-5]/ ) {
		$jobid = $soap->runWUBlast( $paramsData, $contentData );
	}

	# For SOAP::Lite 0.69 and later parameter handling is different, so pass
	# undef's for templated params, and then pass the formatted args.
	else {
		$jobid = $soap->runWUBlast( undef, undef, $paramsData, $contentData );
	}

	# Asynchronous mode: output jobid and exit.
	if ( defined($async) ) {
		print STDOUT $jobid, "\n";
		if ( $outputLevel > 0 ) {
			print STDERR
			  "To check status: $scriptName --status --jobid $jobid\n";
		}
	}

	# Synchronous mode: try to get results
	else {
		if ( $outputLevel > 0 ) {
			print STDERR "JobId: $jobid\n";
		}
		sleep 1;
		&getResults($jobid);
	}
}

# For a finished job get the hit IDs
sub getIds($$) {
	my $jobid  = shift;
	my $withDb = shift;
	my $results;
	if ($withDb) {
		$results = $soap->getFullIds($jobid);
	}
	else {
		$results = $soap->getIds($jobid);
	}
	for my $result (@$results) {
		print "$result\n";
	}
}

# Client-side poll: wait for a job to complete or fail
sub clientPoll($) {
	my $jobid  = shift;
	my $result = 'PENDING';

	# Check status and wait if not finished
	while ( $result eq 'RUNNING' || $result eq 'PENDING' ) {
		$result = $soap->checkStatus($jobid);
		if ( $outputLevel > 0 ) {
			print STDERR "$result\n";
		}
		if ( $result eq 'RUNNING' || $result eq 'PENDING' ) {

			# Wait before polling again.
			sleep $checkInterval;
		}
	}
}

# Get the results for a jobid
sub getResults($) {
	my $jobid = shift;
	my $res;

	# Check status, and wait if not finished
	clientPoll($jobid);

	# Use JobId if output file name is not defined
	unless ( defined($outfile) ) {
		$outfile = $jobid;
	}

	# Get list of data types
	my $resultTypes = $soap->getResults($jobid);

	# Get the data and write it to a file
	if ( defined($outformat) ) {    # Specified data type
		                            # Re-map short names
		if ( $outformat eq 'xml' ) { $outformat = 'toolxml'; }
		if ( $outformat eq 'txt' ) { $outformat = 'tooloutput'; }
		my $selResultType;
		foreach my $resultType (@$resultTypes) {
			if ( $resultType->{type} eq $outformat ) {
				$selResultType = $resultType;
			}
		}
		if ( defined($selResultType) ) {
			my $res = $soap->poll( $jobid, $selResultType->{type} );
			if ( $outfile eq '-' ) {
				write_file( $outfile, $res );
			}
			else {
				write_file( $outfile . '.' . $selResultType->{ext}, $res );
			}
		}
		else {
			die "Error: unknown result format \"$outformat\"";
		}
	}
	else {    # Data types available
		      # Write a file for each output type
		for my $resultType (@$resultTypes) {
			if ( $outputLevel > 1 ) {
				print STDERR "Getting $resultType->{type}\n";
			}
			my $res = $soap->poll( $jobid, $resultType->{type} );
			if ( $outfile eq '-' ) {
				write_file( $outfile, $res );
			}
			else {
				write_file( $outfile . '.' . $resultType->{ext}, $res );
			}
		}
	}
}

# Read a file
sub read_file($) {
	my $filename = shift;
	my ( $content, $buffer );
	if ( $filename eq '-' ) {
		while ( sysread( STDIN, $buffer, 1024 ) ) {
			$content .= $buffer;
		}
	}
	else {    # File
		open( FILE, $filename )
		  or die "Error: unable to open input file $filename ($!)";
		while ( sysread( FILE, $buffer, 1024 ) ) {
			$content .= $buffer;
		}
		close(FILE);
	}
	return $content;
}

# Write a result file
sub write_file($$) {
	my ( $filename, $data ) = @_;
	if ( $outputLevel > 0 ) {
		print STDERR 'Creating result file: ' . $filename . "\n";
	}
	if ( $filename eq '-' ) {
		print STDOUT $data;
	}
	else {
		open( FILE, ">$filename" )
		  or die "Error: unable to open output file $filename ($!)";
		syswrite( FILE, $data );
		close(FILE);
	}
}

# Print program usage
sub usage {
	print STDERR <<EOF
WU-BLAST
========

Rapid sequence database search programs utilizing the BLAST algorithm.
   
[Required]

      --email          : str  : user email address 
  -p, --program	       : str  : BLAST program to use: blastn, blastp, blastx, 
                                tblastn or tblastx
  -D, --database       : str  : database to search
  seqFile              : file : query sequence data file ("-" for STDIN)

[Optional]

  -m, --matrix	       : str  : scoring matrix
  -E, --exp            : real : 0<E<= 1000. Statistical significance threshold
                                for reporting database sequence matches.
  -e, --echofilter     :      : display the filtered query sequence
  -f, --filter	       : str  : activates filtering of the query sequence
  -b, --alignments     : int  : number of alignments to be reported
  -s, --scores	       : int  : number of scores to be reported
  -S, --sensitivity    : str  : sensitivity of the search
  -t, --sort	       : str  : sort order for hits
  -T, --stats          : str  : statistical model
  -d, --strand         : str  : DNA strand to search with 
  -c, --topcombon      : int  : consistent sets of HSPs
      --getMatrices    :      : list scoring matrices
      --getPrograms    :      : list search programs
      --getDatabases   :      : list databases
      --getSensitivity :      : list ensitivity options
      --getSort        :      : list hit sort options
      --getStats       :      : list statisitical models
      --getXmlFormats  :      : list XML formats
      --getFilters     :      : list low complexity filters 

[General]	

  -h, --help           :      : prints this help text
  -a, --async          :      : forces to make an asynchronous query
  -j, --jobid          : str  : jobid that was returned when an asynchronous 
                                job was submitted.
      --polljob        :      : poll for the results of a job
      --status         :      : poll for the status of a job
      --ids            :      : get hit identifers from job result
      --getFormats     :      : list result formats for a job
  -O, --outfile        : str  : name of the file results should be written to 
                                (default is based on the jobid;
                                "-" for STDOUT)
  -o, --outformat      : str  : txt or xml output (no file is written)
      --quiet          :      : decrease output
      --verbose        :      : increase output
      --trace	       :      : show SOAP messages being interchanged 

Synchronous job:

  The results/errors are returned as soon as the job is finished.
  Usage: $scriptName --email <your\@email> [options...] seqFile
  Returns: saves the results to disk

Asynchronous job:

  Use this if you want to retrieve the results at a later time. The results 
  are stored for up to 24 hours. 
  The asynchronous submission mode is recommended when users are submitting 
  batch jobs or large database searches	
  Usage: $scriptName --async --email <your\@email> [options...] seqFile
  Returns : jobid

  Use the jobid to query for the status of the job. 
  Usage: $scriptName --status --jobid <jobId>
  Returns : string indicating the status of the job:
    DONE - job has finished
    RUNNING - job is running
    NOT_FOUND - job cannot be found
    ERROR - the jobs has encountered an error

  When done, use the jobid to retrieve the status of the job. 
  Usage: $scriptName --polljob --jobid <jobId> [--outfile string]
  Returns: saves the results to disk

[Help]

For more detailed help information refer to 
http://www.ebi.ac.uk/Tools/blast2/help.html
 
EOF
	  ;
}
