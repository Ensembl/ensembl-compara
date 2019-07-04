=head1 LICENSE

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 AUTHORS

Abel Ureta-Vidal <abel@ebi.ac.uk>

=head1 NAME

Bio::EnsEMBL::Compara::Production::Analysis::Lastz - 

=head1 SYNOPSIS

  # To run a lastz job from scratch do the following.

  my $query = new Bio::SeqIO(-file   => 'somefile.fa',
                           -format => 'fasta')->next_seq;

  my $database = 'multifastafile.fa';

  my $lastz =  Bio::EnsEMBL::Compara::Production::Analysis::Lastz->new 
    ('-query'     => $query,
     '-database'  => $database,
     '-options'   => 'T=2');

  $lastz->run();

  @featurepairs = $last->output();

  foreach my $fp (@featurepairs) {
      print $fp->gffstring . "\n";
  }

  # Additionally if you have lastz runs lying around that need parsing
  # you can use the EnsEMBL blastz parser module 
  # perldoc Bio::EnsEMBL::Compara::Production::Analysis::Parser::Blastz


=head1 DESCRIPTION

Lastz takes a Bio::Seq (or Bio::PrimarySeq) object and runs lastz with against 
the specified multi-FASTA file database. Tthe output is parsed by 
Bio::EnsEMBL::Compara::Production::Analysis::Parser::Lastz and stored as Bio::EnsEMBL::DnaDnaAlignFeature 

Other options can be passed to the lastz program using the -options method

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::Production::Analysis::Lastz;


use warnings ;
use strict;

use File::Spec::Functions qw(catfile tmpdir);
use File::Temp;

use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::Production::Analysis::Blastz;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception;


sub new {
  my ($class,@args) = @_;

  my $self = bless {},$class;
  my ($query, $program, $options,
      $workdir, $bindir, $libdir,
      $database,
      $datadir, $analysis) = rearrange
        (['QUERY', 'PROGRAM', 'OPTIONS',
          'WORKDIR', 'BINDIR', 'LIBDIR',
          'DATABASE',
          'DATADIR', 'ANALYSIS'], @args);

  $self->query($query);
  $self->program($program);
  $self->options($options);
  $self->workdir($workdir);

  $self->database($database) if defined $database;

  throw("You must supply a database") if not $self->database; 
  throw("You must supply a query") if not $self->query;

  return $self;
}

=head2 run

    Title   :  run
    Usage   :   $obj->run()
    Function:   Runs lastz and BPLite and creates array of feature pairs
    Returns :   none
    Args    :   none

=cut

sub run{
  my ($self, $dir) = @_;

  $self->workdir($dir) if($dir);

  throw("Can't run ".$self." without a query sequence")
    unless($self->query);

  $self->write_seq_files();
  $self->run_analysis();

  my $cmd = $self->program  ." ".
            $self->query ." ".
            $self->database ." ".
            $self->options;

  my $BlastzParser;
  my $blastz_output_pipe = undef;
  if($self->results_to_file) {
    if (not $self->resultsfile) {
      my $resfile = $self->create_filename("lastz", "results");
      $self->resultsfile($resfile);
      $self->files_to_delete($resfile);
    }

    $cmd .=  " > ". $self->resultsfile;
    info("Running lastz...\n$cmd\n");

    throw("Error runing lastz cmd\n$cmd\n." .
                 " Returned error $? LASTZ EXIT: '" .
                 ($? >> 8) . "'," ." SIGNAL '" . ($? & 127) .
                 "', There was " . ($? & 128 ? 'a' : 'no') .
                 " core dump") unless(system($cmd) == 0);

    $BlastzParser = Bio::EnsEMBL::Compara::Production::Analysis::Blastz->
        new('-file' => $self->resultsfile);
  } else {
    info("Running lastz to pipe...\n$cmd\n");

    my $stderr_file = $self->workdir()."/lastz_$$.stderr";

    open($blastz_output_pipe, "$cmd 2>$stderr_file |") ||
      throw("Error opening lasts cmd <$cmd>." .
                   " Returned error $? LAST EXIT: '" .
                   ($? >> 8) . "'," ." SIGNAL '" . ($? & 127) .
                   "', There was " . ($? & 128 ? 'a' : 'no') .
                   " core dump");

    $BlastzParser = Bio::EnsEMBL::Compara::Production::Analysis::Blastz->
        new('-fh' => $blastz_output_pipe) || print_error($stderr_file, "Unable to parse blastz_output_pipe");
  }

  my @results;

  while (defined (my $alignment = $BlastzParser->nextAlignment)) { # nextHSP-like
    push @results, $alignment;
  }
  close($blastz_output_pipe) if(defined($blastz_output_pipe));

  $self->output(\@results);

  $self->delete_files;
}


sub print_error {
    my ($stderr_file, $text) = @_;

    my $msg;
    if (-e $stderr_file) {
	print "$stderr_file\n";
	open FH, $stderr_file or die("Unable to open $stderr_file");
	while (<FH>) {
	    $msg .= $_;
	}
	unlink($stderr_file);
    }
    $msg .= $text;

    throw($msg);
}

#################
# get/set methods 
#################

=head2 query

    Title   :   query
    Usage   :   $self->query($seq)
    Function:   Get/set method for query.  If set with a Bio::Seq object it
                will get written to the local tmp directory
    Returns :   filename
    Args    :   Bio::PrimarySeqI, or filename

=cut

sub query {
  my ($self, $val) = @_;

  if (defined $val) {
    if (not ref($val)) {   
      throw("[$val] : file does not exist\n") unless -e $val;
    } elsif (not $val->isa("Bio::PrimarySeqI")) {
      throw("[$val] is neither a Bio::Seq not a file");
    }
    $self->{_query} = $val;
  }

  return $self->{_query}
}

=head2 database
  
    Title   :   database
    Usage   :   $self->database($seq)
    Function:   Get/set method for database.  If set with a Bio::Seq object it
                will get written to the local tmp directory
    Returns :   filename
    Args    :   Bio::PrimarySeqI, or filename

=cut

sub database {
  my ($self, $val) = @_;

  if (defined $val) {
    if ($val eq "--self") {
	$self->{_database} = $val;
	return $self->{_database};
    }
    if (not ref($val)) {   
      throw("[$val] : file does not exist\n") unless -e $val;
    } else {
      if (ref($val) eq 'ARRAY') {
        foreach my $el (@$val) {
          throw("All elements of given database array should be Bio::PrimarySeqs")
              if not ref($el) or not $el->isa("Bio::PrimarySeq");
        }
      } elsif (not $val->isa("Bio::PrimarySeq")) {
        throw("[$val] is neither a file nor array of Bio::Seq");
      } else {
        $val = [$val];
      }
    }
    $self->{_database} = $val;
  }

  return $self->{_database};
}
  

sub write_seq_files {
  my ($self) = @_;

  if (ref($self->query)) {
    # write the query
    my $query_file = $self->create_filename("lastz", "query");
    my $seqio = Bio::SeqIO->new(-format => "fasta",
                                -file   => ">$query_file");
    $seqio->write_seq($self->query);
    $seqio->close;

    $self->query($query_file);
    $self->files_to_delete($query_file);
  }
  if (ref($self->database)) {
    my $db_file = $self->create_filename("lastz", "database");    
    my $seqio = Bio::SeqIO->new(-format => "fasta",
                                -file   => ">$db_file");
    foreach my $seq (@{$self->database}) {
      $seqio->write_seq($seq);
    }
    $seqio->close;

    $self->database($db_file);
    $self->files_to_delete($db_file);
  }
}


sub results_to_file {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_results_to_file} = $val;
  }

  return $self->{_results_to_file};
}


## Copied from the ensembl-analysis' Runnable.pm
###################################################


=head2 options

  Arg [1]   : string
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


=head2 workdir

  Arg [1]   : string, path to working directory
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
  return $self->{'workdir'} || tmpdir();
}


=head2 program

  Arg [1]   : string, path to program
  Function  : getter/setter for the program being executed
  Returntype: string, path to program
  Exceptions: throws if program path isnt executable
  Example   : 

=cut



sub program{
  my $self = shift;
  my $program = shift;
  if($program){
    $self->{'program'} = $program;
  }
  throw($self->{'program'}.' is not executable for '.ref($self))
    if($self->{'program'} && !(-x $self->{'program'}));
  return $self->{'program'};
}



=head2 output

  Arg [1]   : arrayref of output
  Arg [2]   : flag to attach the runnable->query as a slice
  Function  : pushes passed in arrayref onto the output array
  Returntype: arrayref
  Exceptions: throws if not passed an arrayref
  Example   : 

=cut



sub output{
  my ($self, $output, $attach_slice) = @_;
  if(!$self->{'output'}){
    $self->{'output'} = [];
  }
  if($output){
    throw("Must pass Runnable:output an arrayref not a ".$output)
      unless(ref($output) eq 'ARRAY');
    push(@{$self->{'output'}}, @$output);
  }
  if($attach_slice) {
    foreach my $output_unit (@{$output}) {
      $output_unit->slice($self->{'query'});
    }
  }
  return $self->{'output'};
}


=head2 files_to_delete

  Arg [1]   : string, file name
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


=head2 create_filename

  Arg [1]   : string, stem of filename
  Arg [2]   : string, extension of filename
  Arg [3]   : directory file should live in
  Function  : create a filename containing the PID and a random number
  with the specified directory, stem and extension
  Returntype: string, filename
  Exceptions: throw if directory specifed doesnt exist
  Example   : my $queryfile = $self->create_filename('seq', 'fa');

=cut


sub create_filename{
  my ($self, $stem, $ext, $dir, $no_clean) = @_;

  return create_file_name($stem, $ext, $dir || $self->workdir, $no_clean);
}


=head2 delete_files

  Arg [1]   : hashref, keyed on filenames to delete
  Function  : will unlink any file which exists on the first
  list but not on the second
  Returntype:
  Exceptions: 
  Example   : 

=cut


sub delete_files{
  my ($self, $filehash) = @_;
  if(!$filehash){
    $filehash = $self->files_to_delete;
  }
  foreach my $name (keys(%$filehash)){
      unlink $name;
  }
}


## Copied from the ensembl-analysis' Tools/Utilities.pm
########################################################



=head2 create_file_name

  Arg [1]   : string, stem of filename
  Arg [2]   : string, extension of filename
  Arg [3]   : directory file should live in
  Function  : create a filename using File::Temp
  with the specified directory, stem and extension
  Returntype: File::Temp object
  Exceptions: throw if directory specifed doesnt exist
  Example   : my $queryfile = create_file_name('seq', 'fa');

=cut


sub create_file_name{
  my ($stem, $ext, $dir, $no_clean) = @_;

  my $random = 'XXXXX';
  my %params = (DIR => tmpdir);
  if ($dir) {
    if (-d $dir) {
      $params{DIR} = $dir;
    }
    else {
      throw(__PACKAGE__."::create_file_name: $dir doesn't exist");
    }
  }
  $params{TEMPLATE} = $stem.'_'.$random if ($stem);
  $params{SUFFIX} = '.'.$ext if ($ext);
  if($no_clean) {
    $params{UNLINK} = 0;
  }
  my $fh = File::Temp->new(%params);
  return $fh;
}



## Copied from the ensembl-analysis' Runnable/ProteinAnnotation
################################################################


sub resultsfile{
  my ($self, $filename) = @_;
  
  if($filename){
    $self->{_resultsfile} = $filename;
  }
  return $self->{_resultsfile};
}


1;
