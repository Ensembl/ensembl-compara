
=head1 NAME

Bio::Tools::Run::Search::WuBlast - Base class for WU-BLAST searches

=head1 SYNOPSIS

  # Do not use this object directly - it is used as part of the
  # Bio::Tools::Run::Search system.

  # This is a base class can be inhereted by any Search runner based
  # on WU-BLAST executables. E.g.

  use Bio::Tools::Run::Search;
  my $runnable = Bio::Tools::Run::Search(-method=>'wublastn');
  $runnable->database( $database ); #DB string, eg /blastdir/cdnas.fa
  $runnable->seq( $seq );           #Bio::SeqI object for query
  $runnable->run; # Launch the query

  my $result = $runnable->next_result; #Bio::Search::Result::* object

=head1 DESCRIPTION

This object extends Bio::Tools::Run::Search (sequence database
searching framework) to provide a base class for WU-BLAST
executables. Read the L<Bio::Tools::Run::Search> docs for more
information about how to use this.

=cut

# Let the code begin...
package Bio::Tools::Run::Search::WuBlast;
use strict;
use File::Copy qw(mv);
use Data::Dumper qw(Dumper);

use vars qw( @ISA 
             $SEARCHIO_FORMAT
             $PARAMETER_OPTIONS 
             @PARAMETER_SENSITIVITIES );

use Bio::Tools::Run::Search;

@ISA = qw( Bio::Tools::Run::Search );

BEGIN{
  $SEARCHIO_FORMAT   = 'blast';

  @PARAMETER_SENSITIVITIES = qw( HIGH MEDIUM LOW );

  $PARAMETER_OPTIONS = 
    {

     '-E' => 
     {
      default => 10,
      order   => 10,
      options => [0.0001,0.001,0.01,0.1,1,10,100,1000,10000,100000 ],
      description => 'Maximum E-value for reported alignments',
     },

     '-B' =>
     {
      default => 100, # Default: 250
      order   => 20,
      options => [ 10, 50, 100, 250, 500, 1000, 5000 ],
      description   => 'Maximum number of database hits to report',
     },

     -filter =>
     {
      default => 'seg',
      order   => 30,
      options => [ 'none', 'seg', 'xnu', 'seg+xnu', 'xnu+seg', 'ccp' ],
      description   => 'Program used to filter query sequence',
     },

     -RepeatMasker => 
     {
      default => 1,
      order   => 40,
      options => 'BOOLEAN',
      description   => 'Filter query sequences using RepeatMasker'
     },

     '-sort_by' =>
     {
      default =>undef, #default: pvalue
      order   => 50,
      options => [ undef,'pvalue','highscore','totalscore','count' ],
      description  => "Sort option for database hits",
     },

     '-statistics' =>
     {
      default => undef, #default: sump
      order   => 100,
      options => [ undef, '-sump', '-poissonp','-kap' ],
      description => 'Statistics option for calculation of alignment score',
     },

     '-W' =>
     {
      default => undef, # default: 11 blastn, 3 others
      order   => 120,
      options => [undef,2,3,4,6,8,11,15],
      description => 'Word size for seeding alignments',
     },

     '-wink' =>
     {
      default        => undef, # default: 1,
      order          => 130,
      options        => [undef,1,2,4,8,15],
      description    => 'Step-size for sliding-window used to seed alignments',
     },

     '-hitdist' =>
     {
      default        => undef, # default: 0/off,
      order          => 135,
      options        => [undef,0,40],
      description    => 'Max distance between words for two-hit seeding. (One-hit seeding by default)',
     },

     -matrix => 
     {
      default => 'BLOSUM62',
      order   => 140,
      options => [ qw(BLOSUM30 BLOSUM40 BLOSUM50 BLOSUM60 BLOSUM62 
                      BLOSUM70 BLOSUM80 BLOSUM90 BLOSUM100 DAYHOFF 
                      DNA_MAT GONNET IDENTITY PAM30 PAM60 PAM90 PAM120 
                      PAM150 PAM180 PAM210 PAM240 ) ],
      description => 'Scoring matrix file',
     },

     '-Q' =>
     {
      default        => undef, # default: 10 blastn, 9 others
      order          => 150,
      options        => [ undef,1,2,3,5,9,10,15 ],
      description    => 'Cost of first gap character',
     },

     -R =>
     {
      default        => undef, # default: blastn 10, 2 others
      order          => 160,
      options        => [ undef,1,2,3,5,9,10,15 ],
      description    => 'Cost of second and remaining gap characters',
     },

     -nogap =>
     {
      default => 0,
      order   => 165,
      options => 'BOOLEAN',
      description   => 'Turns off gapped alignments'      
     },

     -T =>
     {
      default        => undef, # default: 11 blastp, 12 blastx, 13 tblastn/x
      order          => 170,
      options        => [ undef,11, 12, 13, 14, 15, 16, 20, 999 ],
      description    => 'Neigborhood word threshold score',
     },

     -X =>
     {
      default     => undef, # default: depends on scoring params
      order       => 180,
      options     => [ undef, 5, 10 ],
      description => 'Alignment extension cutoff', 
     },

     'Additional' =>
     {
      default => '',
      order   => 1000,
      options => 'STRING',
      description   => 'Other options (not validated)',
     },

    };

}

#----------------------------------------------------------------------
sub format      { return $SEARCHIO_FORMAT }

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

  #if( $self->seq->length < 30 ){ # Nasty hack to fudge blast stats
  #  $self->option( '-E'=>'100000' );
  #}

  if( ! -f $self->fastafile ){ $self->throw("Need a query sequence!") }

  my $res_file = $self->reportfile;
  if( -f $res_file ){ 
    $self->warn("A result already exists for $res_file" );
    unlink( $self->reportfile );
  }

  my $res_file_local = '/tmp/blast_$$.out';

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
			    $database,
			    $self->fastafile,
			    $param_str, );

  my $command_tmpl = "%s %s > %s 2>&1 ; cp %s %s; rm %s";

  my $command = sprintf( $command_tmpl, 
      $env_command,
      $blast_command, 
      $res_file_local, 
      $res_file_local, 
      $res_file,
      $res_file_local
   );

  return $command; 
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
  my $self  = shift;
  scalar(@_) > 1 or return $self->SUPER::option(@_);

  my $param = shift;
  my $value = shift;

  # Names can only have a single value in this implementation
  if( ref $value eq 'ARRAY' ){ $value = $value->[0] }

  # Check for explicit delete
  if( ! defined( $value ) ){  return $self->SUPER::option( $param, $value ) }

  # Convert foo= parameters to -foo (wu-blast)
  $param =~ s/^(\w+)=\s*$/-$1/;

  if( $param eq '-sort_by' ){
    $param .= "_". $value;
    $value = $value ? '' : undef; # Needs a value!
  }
  elsif( $param eq '-statistics' ){
    $value || return undef; # Needs a value!
    $param = $value;
    $value = '';
  }
  elsif( $param eq 'Additional' ){
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
