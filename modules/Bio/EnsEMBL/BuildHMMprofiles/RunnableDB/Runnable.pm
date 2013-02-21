# Ensembl module for Bio::EnsEMBL::Analysis::Runnable
#
# Copyright (c) 2004 Ensembl
#

=head1 NAME

Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::Runnable

=head1 SYNOPSIS

  my $repeat_masker = Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::RepeatMasker->
  new(
      -query => 'slice',
      -program => 'repeatmasker',
      -options => '-low'
      -analysis => $analysis,
     );
  $repeat_masker->run;
  my @repeats = @{$repeat_masker->output};

=head1 DESCRIPTION

This module is base class for our Runnables. Runnables are there to 
provide modules which can run different analyses and then parse the
results into core api objects

This module provides some base functionatily

The constructor can take 9 different arguments. The analysis object is 
obligatory and must be passed in. The next 3 arguments, query, program and 
options are the most important as it is with these the Runnable knows what 
to run and on what sequences with what command line options. The next 4 
are directory paths which can be determined from the config file 
Bio::EnsEMBL::Analysis::Config::General but arguments are placed here so 
they can be overidden if desired

The other base functionality includes some container methods
an output method aswell as methods for finding files and executables
and writing sequence to fasta files

All Runnables are expected to have 2 methods, run and output
run is the method which should run the analysis and output is where
the results should be stored

Generic versions of these methods are provided here. The run
method expects the runnables program to fit the commandline model used
by run_analysis, program options queryfile > resultsfile or to implement
its own run_analysis. If the run method is used the child Runnable
must implement a parse_results method as each analysis general has its 
own output format and as such it cant be genericized

The output method provided simple holds an array of results and can
be given an arrayref to push onto that array

For more details about the specification look at Runnable.spec
in the ensembl-doc cvs module

=head1 CONTACT

Post questions to the Ensembl development list: dev@ensembl.org

=cut

package Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::Runnable;

use strict;
use warnings;

use Bio::SeqIO;

#use Bio::EnsEMBL::Root;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::Utils::Exception qw(verbose throw warning);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Analysis::Programs;
use Bio::EnsEMBL::Analysis::Config::General;
use Bio::EnsEMBL::Analysis::Tools::FeatureFactory;
use Bio::EnsEMBL::Analysis::Tools::Utilities qw(create_file_name write_seqfile);
use Bio::EnsEMBL::Analysis::Tools::Logger qw(logger_info);
use vars qw (@ISA);

@ISA = qw();


=head2 new

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : Bio::EnsEMBL::Slice
  Arg [3]   : string, name/path of program
  Arg [4]   : string commandline options for the program
  Arg [5]   : string path to working dir 
  Arg [6]   : string, path to bin dir
  Arg [7]   : string, path to libary dir
  Arg [8]   : string, path to data dir
  Arg [9]   : Bio::EnsEMBL::Analysis;
  Function  : create a new Bio::EnsEMBL::Analysis::Runnable
  Returntype: Bio::EnsEMBL::Analysis::Runnable
  Exceptions: throws if not passed an analysis object
  Example   : $runnable = Bio::EnsEMBL::Analysis::Runnable::RepeatMasker
  ->new
  (
   -query => $self->query,
   -program => $self->analysis->program_file,
   $self->parameters_hash,
  );

=cut


sub new{
  my ($class,@args) = @_;
  my $self = bless {},$class;
  my ($query, $program, $options,
      $workdir, $bindir, $libdir,
      $datadir, $analysis) = rearrange
        (['QUERY', 'PROGRAM', 'OPTIONS',
          'WORKDIR', 'BINDIR', 'LIBDIR',
          'DATADIR', 'ANALYSIS'], @args);
  if(!$analysis){
    throw("Can't create a Runnable without an analysis object");
  }
  $self->query($query);
  $self->program($program);
  $self->options($options);
  $self->workdir($workdir);
  $self->bindir($bindir);
  $self->libdir($libdir);
  $self->datadir($datadir);
  $self->analysis($analysis);

  return $self;
}


#containers


=head2 options

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string
  Function  : container for specified variable. This pod refers to the
  four methods below options, bindir, libdir and datadir. These are simple 
  containers which dont do more than hold and return an given value
  Returntype: string
  Exceptions: none
  Example   : my $options = $self->options;

=cut



sub options{
  my $self = shift;
  $self->{'options'} = shift if(@_);
  return $self->{'options'} || '';
}


=head2 binddir

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string
  Function  : container for specified variable. This pod refers to the
  four methods below options, bindir, libdir and datadir. These are simple 
  containers which dont do more than hold and return an given value
  Returntype: string
  Exceptions: none
  Example   : my $options = $self->binddir;
=cut

sub bindir{
  my $self = shift;
  $self->{'bindir'} = shift if(@_);
  return $self->{'bindir'} || $BIN_DIR;
}


=head2 libdir

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string
  Function  : container for specified variable. This pod refers to the
  four methods below options, bindir, libdir and datadir. These are simple 
  containers which dont do more than hold and return an given value
  Returntype: string
  Exceptions: none
  Example   : my $options = $self->libdir;
=cut

sub libdir{
  my $self = shift;
  $self->{'libdir'} = shift if(@_);
  return $self->{'libdir'} || $LIB_DIR;
}

sub datadir{
  my $self = shift;
  $self->{'datadir'} = shift if(@_);
  return $self->{'datadir'} || $DATA_DIR;
}


=head2 workdir

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, path to working directory
  Function  : If given a working directory which doesnt exist
  it will be created by as standard it default to the directory
  specified in General.pm and then to /tmp
  Returntype: string, directory
  Exceptions: none
  Example   : 

=cut


sub workdir{
  my $self = shift;
  my $workdir = shift;
  if($workdir){
    if(!$self->{'workdir'}){
      mkdir ($workdir, '777') unless (-d $workdir);
    }
    $self->{'workdir'} = $workdir;
  }
  return $self->{'workdir'} || $ANALYSIS_WORK_DIR || '/tmp';
}


=head2 query

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : Bio::EnsEMBL::Slice
  Function  : container for the query sequence
  Returntype: Bio::EnsEMBL::Slice
  Exceptions: throws if passed an object which isnt a slice
  Example   : 

=cut


sub query{
  my $self = shift;
  my $slice = shift;

  if($slice){
    throw("Must pass Runnable::query a Bio::PrimarySeqI not a ".
          $slice) unless($slice->isa('Bio::PrimarySeqI'));
    $self->{'query'} = $slice;
  }

  return $self->{'query'};
}


=head2 program

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, path to program
  Function  : uses locate_executable to find the path of the executable
  Returntype: string, path to program
  Exceptions: throws if program path isnt executable
  Example   : 

=cut



sub program{
  my $self = shift;
  my $program = shift;
  if($program){
    my $path = $self->locate_executable($program);
    $self->{'program'} = $path;
  }
  throw($self->{'program'}." is not executable") 
    if($self->{'program'} && !(-x $self->{'program'}));
  return $self->{'program'};
}



=head2 output

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : arrayref of output
  Function  : pushes passed in arrayref onto the output array
  Returntype: arrayref
  Exceptions: throws if not passed an arrayref
  Example   : 

=cut



sub output{
  my ($self, $output) = @_;
  if(!$self->{'output'}){
    $self->{'output'} = [];
  }
  if($output){
    throw("Must pass Runnable:output an arrayref not a ".$output)
      unless(ref($output) eq 'ARRAY');
    push(@{$self->{'output'}}, @$output);
  }
  return $self->{'output'};
}


=head2 feature_factory

  Arg [1]   : Bio::EnsEMBL::Analysis::RunnableDB
  Arg [2]   : Bio::EnsEMBL::Analysis::Tools::FeatureFactory
  Function  : container for a feature factory object. If none is defined
  when one is requested a new one is created. 
  Returntype: Bio::EnsEMBL::Analysis::Tools::FeatureFactory
  Exceptions: none
  Example   : 

=cut



sub feature_factory{
  my ($self, $feature_factory) = @_;
  if($feature_factory){
    $self->{'feature_factory'} = $feature_factory;
  }
  if(!$self->{'feature_factory'}){
    $self->{'feature_factory'} = Bio::EnsEMBL::Analysis::Tools::FeatureFactory
      ->new();
  }
  return $self->{'feature_factory'};
}



=head2 analysis

  Arg [1]   : Bio::EnsEMBL::Analysis::RunnableDB
  Arg [2]   : Bio::EnsEMBL::Analysis
  Function  : container for analysis object
  Returntype: Bio::EnsEMBL::Analysis
  Exceptions: throws passed incorrect object type
  Example   : 

=cut



sub analysis{
  my $self = shift;
  my $analysis = shift;
  if($analysis){
    throw("Must pass RunnableDB:analysis a Bio::EnsEMBL::Analysis".
          "not a ".$analysis) unless($analysis->isa
                                     ('Bio::EnsEMBL::Analysis'));
    $self->{'analysis'} = $analysis;
  }
  return $self->{'analysis'};
}


=head2 files_to_delete/protect

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, file name
  Function  : both these methods create a hash keyed on file name the
  first a list of files to delete, the second a list of files to protect
  Returntype: hashref
  Exceptions: none
  Example   : 

=cut


sub files_to_delete{
  my ($self, $file) = @_;
  if(!$self->{'del_list'}){
    $self->{'del_list'} = {};
  }
  if($file){
    $self->{'del_list'}->{$file} = 1;
  }
  return $self->{'del_list'};
}

sub files_to_protect{
  my ($self, $file) = @_;
  if(!$self->{'protect_list'}){
    $self->{'protect_list'} = {};
  }
  if($file){
    $self->{'protect_list'}->{$file} = 1;
  }
  return $self->{'protect_list'};
}


=head2 queryfile

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, filename
  Function  : will hold a given filename or if one is requested but none
  defined it will use the create_filename method to create a filename
  if the resultsfile name hasnt yet been defined it will set that to be
  queryfilename.out
  Returntype: string, filename
  Exceptions: none
  Example   : 

=cut


sub queryfile{
  my ($self, $filename) = @_;
  if($filename){
    $self->{'queryfile'} = $filename;
  }
  if(!$self->{'queryfile'}){
    $self->{'queryfile'} = $self->create_filename('seq', 'fa');
  }
  if(!$self->resultsfile){
    my $resultsfile = $self->{'queryfile'}.".out";
    $self->resultsfile($resultsfile);
  }
  return $self->{'queryfile'};
}


=head2 resultsfile

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, file name
  Function  : container for the results filename
  Returntype: string
  Exceptions: none
  Example   : 

=cut


sub resultsfile{
  my ($self, $filename) = @_;
  if($filename){
    $self->{'resultsfile'} = $filename;
  }
  return $self->{'resultsfile'};
}




#utility methods

=head2 create_filename

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, stem of filename
  Arg [3]   : string, extension of filename
  Arg [4]   : directory file should live in
  Function  : create a filename containing the PID and a random number
  with the specified directory, stem and extension
  Returntype: string, filename
  Exceptions: throw if directory specifed doesnt exist
  Example   : my $queryfile = $self->create_filename('seq', 'fa');

=cut



sub create_filename{
  my ($self, $stem, $ext, $dir) = @_;
  if(!$dir){
    $dir = $self->workdir;
  }
  $stem = '' if(!$stem);
  $ext = '' if(!$ext);
  throw($dir." doesn't exist Runnable:create_filename") unless(-d $dir);
  my $num = int(rand(100000));
  my $file = $dir."/".$stem.".".$$.".".$num.".".$ext;
  while(-e $file){
    $num = int(rand(100000));
    $file = $dir."/".$stem.".".$$.".".$num.".".$ext;
  }
  return $file;
}


=head2 locate_executable

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, program name
  Function  : first checks if the passed in name is executable, if not
  checks if the name catted with the bindir is executable, if not
  then uses Bio::EnsEMBL::Analysis::Programs to find where the program
  is
  Returntype: full path of program 
  Exceptions: throws if no name of program is passed in
  Example   : 

=cut


sub locate_executable{
  my ($self, $name) = @_;

  my $path;
  if($name){
    if(-x $name){
      $path = $name;
    }elsif($self->bindir && -x $self->bindir."/$name"){
      $path = $self->bindir."/$name";
    }else{
      Bio::EnsEMBL::Analysis::Programs->import($name);
      $path = $Bio::EnsEMBL::Analysis::Programs::Program_Paths{$name};
    }
  }else{
    throw("Must pass Runnable:locate_executable a name if the program ".
          "is to be located");
  }
  return $path;
}


=head2 write_seq_file

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : Bio::Seq
  Arg [3]   : filename
  Function  : This uses Bio::SeqIO to dump a sequence to a fasta file
  Returntype: string, filename
  Exceptions: throw if failed to write sequence
  Example   : 

=cut


sub write_seq_file{
  my ($self, $seq, $filename) = @_;
 
  if(!$seq){
    $seq = $self->query;
  }
  if(!$filename){
    $filename = $self->queryfile;
  }
  $filename = write_seqfile($seq, $filename);
  return $filename;
}


=head2 find_file

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, filename
  Function  : checks for files existance in current directoru and
  in the data and lib dirs and returns its full path
  Returntype: string, file path
  Exceptions: thows if cant find file
  Example   : 

=cut


sub find_file{
  my ($self, $file) = @_;
  my $found;
  if(-e $file){
    $found = $file;
  }elsif($self->datadir && -e ($self->datadir."/".$file)){
    $found = $self->datadir."/".$file;
  }elsif($self->libdir && -e ($self->libdir."/".$file)){
    $found = $self->libdir."/".$file;
  }else{
    throw($file." doesn't exist Runnable:find_file");
  }
  return $found;
}


=head2 delete_files

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : hashref, keyed on filenames to delete
  Arg [3]   : hashref keyed on filename to protect
  Function  : will unlink any file which exists on the first
  list but not on the second
  Returntype: arrayref of protected filenames
  Exceptions: 
  Example   : 

=cut


sub delete_files{
  my ($self, $filehash, $protected_hash) = @_;
  if(!$filehash){
    $filehash = $self->files_to_delete;
  }
  if(!$protected_hash){
    $protected_hash = $self->files_to_protect;
  }
  foreach my $name (keys(%$filehash)){
    if(!$protected_hash->{$name}){
      unlink $name;
    }
  }
  my @protected = keys(%$protected_hash);
  return \@protected;
}


=head2 clean_output

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Function  : empties output array as some runnabledbs use output
  array as a place holder do offers a simple manner to empty it for
  reuse
  Returntype: arrayref that used to be contained by $self->{'output'}; 
  Exceptions: none
  Example   : 

=cut



sub clean_output{
  my ($self) = @_;
  my $array = $self->{'output'};
  $self->{'output'} = [];
  return $array;
}


=head2 checkdir

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, directory
  Arg [3]   : int, space limit
  Function  : check if specified directory has enough space and then
  changes into that directory
  Returntype: none
  Exceptions: throws if not enough diskspace or if cant change into 
  specified directory
  Example   : 

=cut


sub checkdir{
  my ($self, $dir, $spacelimit) = @_;
  if(!$dir){
    $dir = $self->workdir;
  }
  if(!$spacelimit){
    $spacelimit = 0.01;
  }
  throw("Not enough diskspace on ".$dir." RunnableDB:checkdir")
    unless($self->diskspace($dir, $spacelimit));
  chdir($dir) or throw("FAILED to open ".$dir." Runnable::checkdir");
}

=head2 diskspace

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, directory
  Arg [3]   : int, space limit
  Function  : checks how much space is availible in the specified 
  directory using df -kP 
  Returntype: int, binary toggle, returns 0 if not enough space, 1 if 
  there is
  Exceptions: opens DF using a pipe throws if failed to open or close
  that pipe
  Example   : 

=cut


sub diskspace {
  my ($self, $dir, $limit) =@_;
  my $block_size; #could be used where block size != 512 ?
  my $Gb = 1024 ** 3;

  open DF, "df -kP $dir |" || throw("FAILED to open 'df' pipe ".
                                   "Runnable::diskspace : $!\n");
  my $count = 0;
  my $status = 1;
  while (<DF>) {
    if($count && $count > 0){
      my @values = split;
      my $space_in_Gb = $values[3] * 1024 / $Gb;
      $status = 0 if ($space_in_Gb < $limit);
    }
    $count++;
  }
  close DF || throw("FAILED to close 'df' pipe ".
                    "Runnable::diskspace : $!\n");
  return $status;
}


=head2 run

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, directory
  Function  : a generic run method. This checks the directory specifed
  to run it, write the query sequence to file, marks the query sequence
  file and results file for deletion, runs the analysis parses the 
  results and deletes any files
  Returntype: 1
  Exceptions: throws if no query sequence is specified
  Example   : 

=cut


sub run{
  my ($self, $dir) = @_;

  $self->workdir($dir) if($dir);
  throw("Can't run ".$self." without a query sequence") 
    unless($self->query);
  $self->checkdir();
  my $filename = $self->write_seq_file();
  $self->files_to_delete($filename);
  $self->files_to_delete($self->resultsfile);
  $self->run_analysis();
  $self->parse_results;
  $self->delete_files;
  return 1;
}


=head2 run_analysis

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Arg [2]   : string, program name
  Function  : constructs a generic commandline
  in the form program options queryfile > resultsfile
  Returntype: none
  Exceptions: throws if program isnt defined or is not executable
  Example   : 

=cut



sub run_analysis{
  my ($self, $program) = @_;
  if(!$program){
    $program = $self->program;
  }
  throw($program." is not executable Runnable::run_analysis ") 
    unless($program && -x $program);
  
  my $command = $program." ";
  $command .= $self->options." " if($self->options);
  $command .= $self->queryfile." > ".$self->resultsfile;
  logger_info("Running analysis ".$command);
  system($command) == 0 or throw("FAILED to run ".$command);
}





=head2 parse_results

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable
  Function  : place holder to indicate a child Runnable should implement
  this method
  Returntype: none
  Exceptions: throws as this method should be implemented by any child
  module
  Example   : 

=cut



sub parse_results{
  my ($self) = @_;
  throw("Need to implement parse results in ".$self.
        "Runnable won't provide this functionality for you");
}


1;
