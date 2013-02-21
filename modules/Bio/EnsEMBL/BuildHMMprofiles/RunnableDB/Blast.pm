=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::Blast - 

=head1 SYNOPSIS

  my $blast = Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::Blast->
  new(
      -query => $slice,
      -program => 'wublastn',
      -database => 'embl_vertrna',
      -options => 'hitdist=40 -cpus=1',
      -parser => $bplitewrapper,
      -filter => $featurefilter,
     );
  $blast->run;
  my @output =@{$blast->output};

=head1 DESCRIPTION

  This module is a wrapper for running blast. It knows how to construct
  the commandline and can call to other modules to run the parsing and 
  filtering. By default is constructs wublast commandlines but it can be
  told to construct ncbi command lines. It needs to be passed a Bio::Seq
  and a database name (this database should either have its full path 
  given or it should live in the location specified by the $BLASTDB 
  environment variable). It should also be given a parser object which has
  the method parse_file which takes a filename and returns an arrayref of
  results and optionally it can be given a filter object which has the 
  method filter_results which takes an arrayref of results and returns the
  filtered set of results as an arrayref. For examples of both parser
  objects and a filter object look in Bio::EnsEMBL::Analysis::Tools for
  BPliteWrapper, FilterBPlite and FeatureFilter


=cut


package Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::Blast;

use strict;
use warnings;

#use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::Runnable;
use Bio::EnsEMBL::Analysis::Config::Blast qw( BLASTDB );
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Analysis::Runnable);


=head2 new

  Arg [1]       : Bio::EnsEMBL::Analysis::Runnable::Blast
  Arg [Parser]  : A blast parser object must meet specified interface
  Arg [Filter]  : A Filter object must meet specified interface
  Arg [Database]: string, database name/path
  Arg [Type]    : string, wu or ncbi to specify which type of input
  Arg [Unknown_error_string] : the string to throw if the blast runs fails
  with an unexpected error 4
  Function  : create a Blast runnable 
  Returntype: Bio::EnsEMBL::Analysis::Runnable::Blast
  Exceptions: throws if not given a database name or if not given
  a parser object
  Example   : 

=cut



sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($parser, $filter, $database, $type,
      $unknown_error,$query) = rearrange(['PARSER', 'FILTER', 'DATABASE', 
                                    'TYPE', 'UNKNOWN_ERROR_STRING','QUERY',
                                   ], @args);
  $type = undef unless($type);
  $unknown_error = undef unless($unknown_error);
  ######################
  #SETTING THE DEFAULTS#
  ######################
  $self->type('wu');
  $self->unknown_error_string('FAILED');
  $self->options('-cpus=1') if(!$self->options);
  ######################
  $self->databases($database);
  $self->parser($parser);
  $self->filter($filter);
  $self->type($type) if($type);
  $self->unknown_error_string($unknown_error) if($unknown_error);

  $self->query($query);	

  throw("No valid databases to search")
  #    unless(@{$self->databases});
       unless($self->databases);		

  throw("Must pass Bio::EnsEMBL::Analysis::Runnable::Blast ".
        "a parser object ") 
      unless($self->parser);

  return $self;
}



=head2 databases

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Blast 
  Arg [2]   : string/int/object
  Function  : container for given value, this describes the 5 methods
  below, database, parser, filter, type and unknown_error_string
  Returntype: string/int/object
  Exceptions: 
  Example   : 

=cut

sub databases {
  my ($self, $arg) = @_;

  if($arg){
        $self->{databases} = $arg;
   }

return $self->{databases};
}

sub databases_bak{
  my ($self, @vals) = @_;

  if (not exists $self->{databases}) {
    $self->{databases} = [];
  }

  foreach my $val (@vals) {
    my $dbname = $val;

    my @dbs;

    $dbname =~ s/\s//g;

    # prepend the variable $BLASTDB from Config/Blast.pm
    # if database name is not an absolute path
  
    unless ($dbname =~ m!^/!) {
        $dbname = $BLASTDB . "/" . $dbname;
    }
  
    # If the expanded database name exists put this in
    # the database array.
    #
    # If it doesn't exist then see if $database-1,$database-2 exist
    # and put them in the database array
    
    if (-f $dbname || -f $dbname . ".fa") {
      push(@dbs,$dbname);
    } else {
      my $count = 1;
      while (-f $dbname . "-$count") {
        push(@dbs,$dbname . "-$count"); 	 
        $count++; 	 
      }
    }

    if (not @dbs) {
      warning("Valid BLAST database could not be inferred from '$val'");
    } else {
      push @{$self->{databases}}, @dbs;
    }
  }

  return $self->{databases};
}


=head2 parser 

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Blast 
  Arg [2]   : string/int/object
  Function  : container for given value, this describes the 5 methods
  below, database, parser, filter, type and unknown_error_string
  Returntype: string/int/object
  Exceptions: 
  Example   : 

=cut
sub parser{
  my $self = shift;
  $self->{'parser'} = shift if(@_);
  return $self->{'parser'};
}


=head2 filter

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Blast 
  Arg [2]   : string/int/object
  Function  : container for given value, this describes the 5 methods
  below, database, parser, filter, type and unknown_error_string
  Returntype: string/int/object
  Exceptions: 
  Example   : 

=cut
sub filter{
  my $self = shift;
  $self->{'filter'} = shift if(@_);
  return $self->{'filter'};
}

=head2 type

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Blast 
  Arg [2]   : string/int/object
  Function  : container for given value, this describes the 5 methods
  below, database, parser, filter, type and unknown_error_string
  Returntype: string/int/object
  Exceptions: 
  Example   : 

=cut
sub type{
  my $self = shift;
  $self->{'type'} = shift if(@_);
  return $self->{'type'};
}

=head2 unknown_error_string

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Blast 
  Arg [2]   : string/int/object
  Function  : container for given value, this describes the 5 methods
  below, database, parser, filter, type and unknown_error_string
  Returntype: string/int/object
  Exceptions: 
  Example   : 

=cut
sub unknown_error_string{
  my $self = shift;
  $self->{'unknown_error_string'} = shift if(@_);
  return $self->{'unknown_error_string'};
}


=head2 results_files

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Blast
  Arg [2]   : string, filename
  Function  : holds a list of all the output files from the blast runs
  Returntype: arrayref
  Exceptions:
  Example   :

=cut


sub results_files{
  my ($self, $file) = @_;
  if(!$self->{'results_files'}){
    $self->{'results_files'} = [];
  }
  if($file){
    push(@{$self->{'results_files'}}, $file);
  }
  return $self->{'results_files'};
}


=head2 run_analysis

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Blast
  Function  : gets a list of databases to run against and constructs
  commandlines against each one and runs them
  Returntype: none
  Exceptions: throws if there is a problem opening the commandline or
  if blast produces an error
  Example   : 

=cut



sub run_analysis {
  my ($self) = @_;
  
  #foreach my $database (@{$self->databases}) {
    my $database = $self->databases;	

    my $db = $database;
    $db =~ s/.*\///;
    #allow system call to adapt to using ncbi blastall. 
    #defaults to WU blast
    my $command  = $self->program;
    my $blastype = "";
    my $filename = $self->queryfile;

    my $results_file = $self->create_filename($db, 'blast.out');
    
    $self->files_to_delete($results_file);
    $self->results_files($results_file);
    if ($self->type eq 'ncbi') {
      $command .= " -d $database -i $filename ";
    } else {
      $command .= " $database $filename -gi ";
    }
    $command .= $self->options. ' 2>&1 > '.$results_file;
    
    print "Running blast ".$command."\n";
    info("Running blast ".$command); 

    if ( ! -e $ENV{BLASTMAT} && ! -e $ENV{WUBLASTMAT}) {  
      throw(" your environment variable \$BLASTMAT is not set !!! ". 
            " Point it to /usr/local/ensembl/data/blastmat/ or where your BLOSUM62 matrices live\n") ;
    } 
    open(my $fh, "$command |") || 
      throw("Error opening Blast cmd <$command>." .
            " Returned error $? BLAST EXIT: '" . 
            ($? >> 8) . "'," ." SIGNAL '" . ($? & 127) . 
            "', There was " . ($? & 128 ? 'a' : 'no') . 
            " core dump");
    # this loop reads the STDERR from the blast command
    # checking for FATAL: messages (wublast) [what does ncbi blast say?]
    # N.B. using simple die() to make it easier for RunnableDB to parse.
    while(<$fh>){
      if(/FATAL:(.+)/){
        my $match = $1;
        print $match;
	# clean up before dying
	$self->delete_files;
        if($match =~ /no valid contexts/){
          die qq{"VOID"\n}; # hack instead
        }elsif($match =~ /Bus Error signal received/){
          die qq{"BUS_ERROR"\n}; # can we work out which host?
        }elsif($match =~ /Segmentation Violation signal received./){
          die qq{"SEGMENTATION_FAULT"\n}; # can we work out which host?
        }elsif($match =~ /Out of memory;(.+)/){
          # (.+) will be something like "1050704 bytes were last 
          #requested."
          die qq{"OUT_OF_MEMORY"\n}; 
          # resenD to big mem machine by rulemanager
        }elsif($match =~ /the query sequence is shorter than the word length/){
          #no valid context 
          die qq{"VOID"\n}; # hack instead
        }elsif($match =~ /External filter/){
          # Error while using an external filter
          die qq{"EXTERNAL_FITLER_ERROR"\n}; 
        }else{
          warning("Something FATAL happened to BLAST we've not ".
                  "seen before, please add it to Package: " 
                  . __PACKAGE__ . ", File: " . __FILE__);
          die ($self->unknown_error_string."\n"); 
          # send appropriate string 
          #as standard this will be failed so job can be retried
          #when in pipeline
        }
      }elsif(/WARNING:(.+)/){
        # ONLY a warning usually something like hspmax=xxxx was exceeded
        # skip ...
      }elsif(/^\s{10}(.+)/){ # ten spaces
        # Continuation of a WARNING: message
        # Hope this doesn't catch more than these.
        # skip ...
      }
    }
    unless(close $fh){
      # checking for failures when closing.
      # we should't get here but if we do then $? is translated 
      #below see man perlvar
      warning("Error running Blast cmd <$command>. Returned ".
              "error $? BLAST EXIT: '" . ($? >> 8) . 
              "', SIGNAL '" . ($? & 127) . "', There was " . 
              ($? & 128 ? 'a' : 'no') . " core dump");
      die ($self->unknown_error_string."\n"); 
    }
  #}
}


=head2 parse_results

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Blast
  Function  : call to parser to get results from output file
  and filter those results if there is a filter object
  Returntype: none
  Exceptions: none
  Example   : 

=cut


sub parse_results{
	my ($self) = @_;
 
  	my $results = $self->results_files;
  	my $output = $self->parser->parse_files($results);
  	my $filtered_output;

#print STDERR "BLAST.pm Have ".@$output." features to filter\n";
  	if($self->filter){
    		$filtered_output = $self->filter->filter_results($output);
  	}else{
    		$filtered_output = $output;
  	}
  	$self->output($filtered_output);
}


1;
