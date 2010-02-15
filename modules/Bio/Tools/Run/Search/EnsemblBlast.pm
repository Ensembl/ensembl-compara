=head1 NAME

Bio::Tools::Run::Search::EnsemblBlast - Base class for Ensembl BLAST searches

=head1 SYNOPSIS

  see Bio::Tools::Run::Search::WuBlast

=head1 DESCRIPTION

An extension of Bio::Tools::Run::Search::WuBlast to cope with the
ensembl blast farm. E.g. uses the bsub job submission system to
dispatch jobs. The jobs themselves are wrapped in the
utils/runblast.pm perl script.

=cut

# Let the code begin...
package Bio::Tools::Run::Search::EnsemblBlast;
use strict;
use File::Copy qw(mv);
use Data::Dumper qw(Dumper);

use vars qw( @ISA 
	     $BSUB_QUEUE $BSUB_RESOURCE
	     $MAX_BLAST_CPUS
	     $SPECIES_DEFS );

use Bio::Tools::Run::Search::WuBlast;
use EnsEMBL::Web::SpeciesDefs;
use Sys::Hostname qw(hostname);
use warnings;


@ISA = qw( Bio::Tools::Run::Search::WuBlast );

BEGIN{
  $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new;

#  $BSUB_QUEUE    = "-q basement";
  $BSUB_QUEUE    = "-q fast";
  $BSUB_RESOURCE = "-R 'ncpus>1'";

  # Set default blast cpus flag for SMP boxes
  $MAX_BLAST_CPUS = 1;

}

#----------------------------------------------------------------------

=head2 run

  Arg [1]   : none
  Function  : Dispatches the blast job using the dispatch_bsub method
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub run {
  my $self = shift;

  if( $self->status ne 'PENDING' and
      $self->status ne 'DISPATCHED' ){
    $self->warn( "Wrong status for run: ". $self->status );
  }

  # Apply environment variables, keeping a backup copy
  my %ENV_TMP = %ENV;
  foreach my $env(  $self->environment_variable() ){
    my $val = $self->environment_variable( $env );
    if( defined $val ){ $ENV{$env} = $val }
    else{ delete( $ENV{$env} ) }
  }

  # Do the deed
  my $command = $self->command;
  $self->dispatch_bsub( $command );

  $self->debug( "BLAST COMMAND: "  .$command."\n" );
  # $self->debug( "BLAST COMMAND: ".$self->command."\n" );

  # Restore environment
  %ENV = %ENV_TMP;
  return 1;
}


#----------------------------------------------------------------------

=head2 run_blast

  Arg [1]   : None
  Function  : Fires off the blast command (SUPER::run),
              with a pre-repeatmask step
  Returntype: Boolean
  Exceptions:
  Caller    : 
  Example   :

=cut

sub run_blast{
  my $self = shift;

#  if( $self->option("repeatmask") ||
#      defined( $self->option("-RepeatMasker")  ) ){
#    uc($self->seq->alphabet) eq 'DNA' || 
#     ( $self->warn( "Can't repeatmask peptide sequences!" ) && return );
#    $self->_repeatmask;
#  }

  return $self->SUPER::run();
}

#----------------------------------------------------------------------

=head2 command_bsub

  Arg [1]   : None
  Function  : Internal method to generate the shell bsub command.
              This command calls the utils/runblast.pm wrapper script 
              rather that the blast command itself
  Returntype: String: $command
  Exceptions:
  Caller    :
  Example   :

=cut

sub command_bsub{
  my $self = shift;
#  my $program_name = "runblast.pl";
#  my $program_dir  = $SiteDefs::ENSEMBL_SERVERROOT."/utils";
  my $blastscript = $SiteDefs::ENSEMBL_BLASTSCRIPT;
  my $args         = $self->token;
  my $command      = "$blastscript $args";
  return $command;
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
  #TODO: expunge SpDefs
  $ENV{BLASTREPEATMASKER} = $SPECIES_DEFS->ENSEMBL_REPEATMASKER;
  return $self->SUPER::_repeatmask(@_);
}

#----------------------------------------------------------------------

=head2 command

  Arg [1]   : None
  Function  : Generate the blast command itself
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

  my $res_file_local = '/tmp/blast_$$.out';

  $ENV{'BLASTMAT'}    || $self->warn( "BLASTMAT variable not set" );
  $ENV{'BLASTFILTER'} || $self->warn( "BLASTFILTER variable not set" );
  $ENV{'BLASTDB'}     || $self->warn( "BLASTBD variable not set" );

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
  $param_str =~ s/[;`&|<>\s]+/ /g;
  my $BDP = $SPECIES_DEFS->ENSEMBL_BLAST_DATA_PATH;
  return join( ' ', $SPECIES_DEFS->ENSEMBL_BLAST_BIN_PATH."/".$self->program_path,
                    "$BDP/$database", '[[]]', $param_str);
}

#----------------------------------------------------------------------

=head2 dispatch_bsub

  Arg [1]   :
  Function  : Fires off the bsub command
  Returntype:
  Exceptions:
  Caller    : run method
  Example   :

=cut

sub dispatch_bsub {
   my $self = shift;
   my $command = shift || die( "Need a command to dispatch!" );
   my( $ticket ) = $self->statefile =~ m#/([^/]+$)#;
   
   ## Files on BLAST SERVER
   my $server_out_file   = "/tmp/$ticket.out"; 
   my $server_fail_file  = "/tmp/$ticket.fail";
   my $server_flag_file  = "/tmp/$ticket.flag";
   my $server_fasta_file = "/tmp/$ticket.fa";
   ## Files on web-blade
   my $client_out_file   = $self->reportfile;
   my $state_file        = $self->statefile;
   my @PARTS             = split /\//, $state_file;
   my $TICKET_NAME       = "$PARTS[-3]$PARTS[-2]-$PARTS[-1]";
   my $client_flag_file  = $SPECIES_DEFS->ENSEMBL_TMP_DIR_BLAST."/pending/$TICKET_NAME";
   my $client_sent_file  = $SPECIES_DEFS->ENSEMBL_TMP_DIR_BLAST."/sent/$TICKET_NAME";
   my $client_fail_file  = "$state_file.fail";
   my $client_fasta_file = $self->fastafile; 

   $command =~ s/\[\[\]\]/$server_fasta_file/;

   my $queue = $self->priority || 'offline';
   my $jobid;
   my $host = hostname();
    my $pid;
    local *BSUB;
   
   my $repeatmask_command = $SPECIES_DEFS->ENSEMBL_REPEATMASKER;
#   $queue = 'systest';
   
   my $project_name;
   
   if($SiteDefs::ENSEMBL_SITETYPE eq 'Vega'){
      my $db_name;
      if(length($self->database) > 38){
          $db_name= substr($self->database, 0, 38);
      }
      else{
          $db_name= $self->database;
      }
      $project_name=  join ':', $self->program_name, $db_name, $self->seq->alphabet;   
   }
   else{
      (my $db_name = $self->database) =~ s/([A-Z])[a-z]+_([a-z]{3})[a-z_]*\..*\.a([-\w+])\.(\w+)\.fa/ENSEMBL.$1$2.$3.$4/;
      $project_name = join ':', $self->program_name, $db_name, $self->seq->length, $self->seq->alphabet;
   }

    warn "PROJECT-NAME: $project_name\n";
   
   my $command_line = qq(|bsub -c 120 -q $queue -P '$project_name' -J $ticket -o /dev/null -f "$client_fasta_file > $server_fasta_file");
   warn $command_line;
   if( open(BSUB, $command_line )) {
      if( open(FH,">$client_sent_file" ) ) {
        print FH "$state_file";
        close FH;
      }
      $self->_init_command_string();
      # $self->_add_command( 'set -e' );                                         # set -e causes the job to fail instantly if any command within it fails
       if( 
         ( $self->option("repeatmask") || defined( $self->option("-RepeatMasker") ) ) &&
         ( uc($self->seq->alphabet) eq 'DNA' )
       ) {
        $self->_add_command(
          qq( $repeatmask_command $server_fasta_file ),           ## Run repeat masker
          qq( rm $server_fasta_file.out ),                        ## Remove all of the temporary files
          qq( rm $server_fasta_file.stderr ),
          qq( rm $server_fasta_file.cat ),
          qq( rm $server_fasta_file.RepMask ),
          qq( rm $server_fasta_file.RepMask.cat ),
          qq( rm $server_fasta_file.masked.log ),
          qq( mv $server_fasta_file.masked $server_fasta_file )   ## Copy back the repeat masked file!
        );
      }
      $self->_add_command(
        qq($command >$server_out_file 2>$server_fail_file),       ## Run the blast, sending output to local temp file
         q(status=$?),                                            ## Store status of BLAST command
        qq(echo '$state_file' > $server_flag_file),               ## Touch flag file so that can indicate blast has finished
        qq(lsrcp "$server_out_file"  "$host:$client_out_file"  ),
        qq(lsrcp "$server_fail_file" "$host:$client_fail_file" ),
        qq(lsrcp "$server_flag_file" "$host:$client_flag_file" ), # Copy all files back...
        qq(rm -f /tmp/$ticket.*),                                 # Now tidy up the temporary files
         q(exit $status)                                          # Return exit codo of $command!
      );
warn $self->_command_string();
      print BSUB $self->_command_string();
      close BSUB;
      if ($? != 0) {
        die("bsub exited with non-zero status - job not submitted\n");
      }
    } else {
      die("Could not exec bsub : $!\n");
    }
   return 1;
}

sub _init_command_string {
  my $self = shift;
  $self->{'command_string'} = '';
}

sub _add_command {
  my $self = shift;
  $self->{'command_string'} .= join "\n", @_, '';
}

sub _command_string {
  my $self = shift;
  return $self->{'command_string'};
}
#----------------------------------------------------------------------
sub remove{
  my $self = shift;
  my( $ticket ) = $self->statefile =~ m#/([^/]+$)#;
  my $sec = 5;
  local $SIG{ALRM} = sub{ die( "bkill timeout ($sec secs)\n" ) };

  my $out;
  eval{
    alarm( $sec );
    $out = `bkill -J $ticket 2>&1`;
    alarm( 0 );
  };
  if( $@ ){ die( $@ ) }
  warn ( "BSUB REMOVING $ticket: ",$out );
  $self->SUPER::remove();
}

#----------------------------------------------------------------------

1;
