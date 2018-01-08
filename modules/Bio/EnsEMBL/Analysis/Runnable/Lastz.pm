=head1 LICENSE

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

Bio::EnsEMBL::Analysis::Runnable::Lastz - 

=head1 SYNOPSIS

  # To run a lastz job from scratch do the following.

  my $query = new Bio::SeqIO(-file   => 'somefile.fa',
                           -format => 'fasta')->next_seq;

  my $database = 'multifastafile.fa';

  my $lastz =  Bio::EnsEMBL::Analysis::Runnable::Lastz->new 
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
  # perldoc Bio::EnsEMBL::Analysis::Runnable::Parser::Blastz


=head1 DESCRIPTION

Lastz takes a Bio::Seq (or Bio::PrimarySeq) object and runs lastz with against 
the specified multi-FASTA file database. Tthe output is parsed by 
Bio::EnsEMBL::Analysis::Runnable::Parser::Lastz and stored as Bio::EnsEMBL::DnaDnaAlignFeature 

Other options can be passed to the lastz program using the -options method

=head1 METHODS

=cut

package Bio::EnsEMBL::Analysis::Runnable::Lastz;


use warnings ;
use vars qw(@ISA);
use strict;

# Object preamble

use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Analysis::Tools::Blastz;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception;

@ISA = qw(Bio::EnsEMBL::Analysis::Runnable);


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);

  my ($database) = rearrange(['DATABASE'], @args);
  $self->database($database) if defined $database;

  throw("You must supply a database") if not $self->database; 
  throw("You must supply a query") if not $self->query;

  $self->program("lastz") if not $self->program;

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

  $self->delete_files;
  return 1;
}



sub run_analysis {
  my $self = shift;

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

    $BlastzParser = Bio::EnsEMBL::Analysis::Tools::Blastz->
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

    $BlastzParser = Bio::EnsEMBL::Analysis::Tools::Blastz->
        new('-fh' => $blastz_output_pipe) || print_error($stderr_file, "Unable to parse blastz_output_pipe");
  }

  my @results;

  while (defined (my $alignment = $BlastzParser->nextAlignment)) { # nextHSP-like
    push @results, $alignment;
  }
  close($blastz_output_pipe) if(defined($blastz_output_pipe));

  $self->output(\@results);
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

1;
