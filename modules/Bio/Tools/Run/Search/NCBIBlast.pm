
=head1 NAME

Bio::Tools::Run::Search::NCBIBlast - Search runnable for NCBI-BLAST

=head1 SYNOPSIS

  # Do not use this object directly - it is used as part of the
  # Bio::Tools::Run::Search system.

  # This is a base class can be inhereted by any Search runner based
  # on NCBI-BLAST executables. E.g.

  use Bio::Tools::Run::Search;
  my $runnable = Bio::Tools::Run::Search(-method=>'ncbiblastn');
  $runnable->database( $database ); #DB string, eg /blastdir/cdnas.fa
  $runnable->seq( $seq );           #Bio::SeqI object for query
  $runnable->run; # Launch the query

  my $result = $runnable->next_result; #Bio::Search::Result::* object

=head1 DESCRIPTION

This object extends Bio::Tools::Run::Search (sequence database
searching framework) to provide a base class for NCBI-BLAST
executables. Read the L<Bio::Tools::Run::Search> docs for more
information about how to use this.

=cut

# Let the code begin...
package Bio::Tools::Run::Search::NCBIBlast;
use strict;
use File::Copy qw(mv);
use Data::Dumper qw(Dumper);

use vars qw( @ISA 
	     $SEARCHIO_FORMAT
	     $PROGRAM_NAME
	     $PARAMETER_OPTIONS 
	     $SPECIES_DEFS );

use Bio::Tools::Run::Search;
use EnsEMBL::Web::SpeciesDefs;

@ISA = qw( Bio::Tools::Run::Search );

BEGIN{
  $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new();

  $SEARCHIO_FORMAT   = 'blast';
  $PROGRAM_NAME      = 'blastall';
  $PARAMETER_OPTIONS = 
    {

     '-e' => 
     {
      default => 10,
      order   => 10,
      options => [0.0001,0.001,0.01,0.1,1,10,100,1000,10000,100000 ],
      description => 'Maximum E-value for reported alignments',
     },

     '-b' =>
     {
      default => 250,
      order   => 20,
      options => [ 10, 50, 100, 250, 500, 1000, 5000 ],
      description   => 'Maximum number of alignments to report',
     },

     '-M' =>
     {
      default => 'BLOSUM62',
      order   => 25,
      options => [ qw(BLOSUM30 BLOSUM40 BLOSUM50 BLOSUM60 BLOSUM62 
		      BLOSUM70 BLOSUM80 BLOSUM90 BLOSUM100 DAYHOFF 
		      DNA_MAT GONNET IDENTITY PAM30 PAM60 PAM90 PAM120 
		      PAM150 PAM180 PAM210 PAM240 ) ],
      description => 'Scoring matrix file',
     },

     -RepeatMasker => 
     {
      default => 1,
      order   => 40,
      options => 'BOOLEAN',
      description   => 'Filter query sequences using RepeatMasker'
     },

     'Additional' =>
     {
      default => '',
      order   => 110,
      options => 'STRING',
      description   => 'Other options (not validated)',
     },
    };

}

#----------------------------------------------------------------------
sub format      { return $SEARCHIO_FORMAT }

#----------------------------------------------------------------------
sub program_name{ 
  my $self = shift;
  my $pname = $self->SUPER::program_name(@_);
  return defined( $pname ) ?  $pname : $PROGRAM_NAME;
}
#----------------------------------------------------------------------
=head2 _repeatmask

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _repeatmask{
  my $self = shift;
  my $rm_exe = $ENV{BLASTREPEATMASKER} || 
    ( $self->warn("BLASTREPEATMASKER env not set; skipping") && return );
					    
  my $fastafile = $self->fastafile;
  my $command   = "$rm_exe $fastafile";
  $self->debug( $command."\n" );
  system( $command ) == 0 or $self->throw( "RepeatMasker failed: $!" );
  unlink( "$fastafile.out" );
  unlink( "$fastafile.stderr" );
  unlink( "$fastafile.cat" );
  unlink( "$fastafile.RepMask" );
  unlink( "$fastafile.RepMask.cat");
  unlink( "$fastafile.masked.log");
  mv("$fastafile.masked", $fastafile) or $self->throw( "cp failed: $!" );
  return 1;
}

#----------------------------------------------------------------------

=head2 command

  Arg [1]   : None
  Function  : generates the shell command to run
              the blast query
  Returntype: String: $command
  Exceptions:
  Caller    :
  Example   :

=cut

sub command{
  my $self = shift;

  if( ! -f $self->fastafile ){ $self->throw("Need a query sequence!") }

  my $res_file = $self->reportfile;
  if( -f $res_file ){ 
    $self->warn("A result already exists for $res_file" );
    unlink( $self->reportfile );
  }

  my $res_file_local = '/tmp/ensblast_$$.out';

  # Build a list of blast-specific environment variables and set these
  # explicitly in the command. Apache(2)-safe.
  my $env_command = '';
  foreach my $env qw( PATH BLASTMAT BLASTFILTER BLASTDB ){
    my $val = $self->environment_variable( $env );
    $val = $ENV{$env} unless defined( $val );
    $val or  $self->warn( "$env variable not set" ) && next;
    $env_command .= sprintf( 'export %s=%s; ', $env, $val );
  }

  my $database = $self->database ||
    $self->throw("No database");

  if( $self->seq->length < 30 ){ $self->option( '-e'=>'10000' ) }


  my $me = ref($self);
  my $prog_nam;
  if(    $me =~ /tblastn/i ){ $prog_nam = "tblastn" }
  elsif( $me =~ /tblastx/i ){ $prog_nam = "tblastx" }
  elsif( $me =~ /blastn/i  ){ $prog_nam = "blastn"  }
  elsif( $me =~ /blastx/i  ){ $prog_nam = "blastx"  }
  elsif( $me =~ /blastp/i  ){ $prog_nam = "blastp"  }
  else{ $self->throw( "Method $me has no program name" ) }

  my $param_str = '';
  foreach my $param( $self->option ){
    my $val = $self->option($param) || '';
    next if $param eq "repeatmask";
    next if $param eq "-RepeatMasker";
    if( $param =~ /=$/ ){ $param_str .= " $param$val" }
    elsif( $val ){ $param_str .= " $param $val" }
    else{ $param_str .= " $param" }
  }

  $param_str =~ s/[;`&|<>\s]+/ /g; #`
  my $blast_command = join( ' ',
			    $self->program_path,
			    '-d', $database,
			    '-p', $prog_nam,
			    $param_str, 
			    ' > ', $self->reportfile );
  
  my $report_file     = $self->reportfile;
  my $report_file_tmp = $report_file."_";
  my $command_tmpl = "%s cat %s | %s > %s 2>&1 ; mv %s %s";
  my $command = sprintf
    ( $command_tmpl,
      $env_command,
      $self->fastafile,
      $blast_command,
      $report_file_tmp,
      $report_file_tmp,
      $report_file );
		   warn( "==> $command" );
  return $command;		   
}

#----------------------------------------------------------------------

=head2 _dispatch

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut
sub _dispatch {
  my $self = shift;
  my $command = shift || die( "Need a command to dispatch!" );

  $ENV{BLASTDB}     = $SPECIES_DEFS->ENSEMBL_BLAST_DATA_PATH;
  $ENV{BLASTMAT}    = $SPECIES_DEFS->ENSEMBL_BLAST_MATRIX;
  $ENV{BLASTFILTER} = $SPECIES_DEFS->ENSEMBL_BLAST_FILTER;
  $ENV{'BLASTDB'}     || $self->warn( "BLASTDB env not set" );
  $ENV{'BLASTMAT'}    || $self->warn( "BLASTMAT env not set" );
  $ENV{'BLASTFILTER'} || $self->warn( "BLASTFILTER env not set" );

  # Dispatch the command, sending both stdout and stderr to result file
  my $dispatch = "$command -o ".$self->resultfile." 2>&1";
  $self->debug( "DISPATCH: $dispatch" );
  system( $dispatch );

  if( -f $self->resultfile && -r $self->resultfile ){

    my $searchio = Bio::SearchIO->new
      ( -format         => $self->format,
	-file           => $self->resultfile );

    $searchio->attach_EventHandler( $self->_eventHandler );

    if( my $result = $searchio->next_result ){

      # Propogate database name, type and species. There may well be a better
      # way of doing this!
      my $dbname = $self->database;
      $result->database_name( $self->database );
      if( $dbname =~ /([^\/]+)$/ ){ $dbname = $1 }
      my @bits = split( /[_\.]/, $dbname, 3 ); 
      if( @bits < 3 ){ 
	$self->warn("Bad format for Ensembl search DB: ".$dbname );
      }
      else{
	if( $result->can('species') ){
	  $result->species(  ucfirst( $bits[0] ) . '_' . lc( $bits[1] ) );
	}
	if( $result->can('database') ){
	  $result->database( uc( $bits[2] ) );
	}
      }

      if( $result->can('_map') ){$result->_map}
      $self->{-result} = $result;	
    }
    else{
      $self->{-result}->num_hits(0);
    }

    $self->SUPER::status( 'COMPLETED' );
  }
  else{
    $self->throw( "Something nasty is going on" );
  }

  delete( $self->{io} ); # Just in case ;)
  $self->store; # This is needed to get the status to update Would be better 
                # to do this another way!
  return 1;
}

#----------------------------------------------------------------------

=head2 option

  Arg [1]   : 
  Function  : Overrides the SUPER class for certain options.
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub option{
  my $self = shift;
  scalar(@_) > 1 or return $self->SUPER::option(@_);

  my $param = shift;
  my $value = shift;

   # Names can only have a single value in this implementation
  if( ref $value eq 'ARRAY' ){ $value = $value->[0] }

  # Check for explicit delete
  if( ! defined( $value ) ){  return $self->SUPER::option( $param, $value ) }

 if( $param eq 'Additional' ){
    # String of arbitrary options
    my $arg_str = $value;
    my @bits = split( /\s+/, $arg_str );
    while( my $param = shift @bits ){
      my $next_bit = $bits[0];
      if( ! $next_bit or $param !~ /^-/ or $next_bit =~ /(^-|=)/ ){
	if( $param =~ /(.+=)(.+)/ ){
	  $self->option( $1, $2 ) 
	}
	else{ $self->option($param,'') };
      }
      else{
	$self->option($param, shift @bits);
      }
    }
    return 1;
  }
  my @args = ($param);
  if( defined( $value ) ){ push @args, $value }
  return $self->SUPER::option(@args);
}

#----------------------------------------------------------------------
1;
