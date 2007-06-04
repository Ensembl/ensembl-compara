
# Let the code begin...
package Bio::Tools::Run::Search::ParacelBlast;
use strict;
use File::Copy qw(mv);
use Data::Dumper qw(Dumper);

use vars qw( @ISA 
	     $SEARCHIO_FORMAT
	     $PARAMETER_OPTIONS 
	     $SPECIES_DEFS );

use Bio::Tools::Run::Search::NCBIBlast;
use EnsEMBL::Web::SpeciesDefs;

@ISA = qw( Bio::Tools::Run::Search::NCBIBlast );

BEGIN{
  $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new();
  $SEARCHIO_FORMAT   = 'blast';
  $PARAMETER_OPTIONS = $Bio::Tools::Run::Search::NCBIBlast::PARAMETER_OPTIONS;
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

  my $me = ref($self);
  my $algorithm;

  if( $me =~ /tblastn/i ){
    $algorithm = "tblastn";
  }
  elsif( $me =~ /tblastx/i ){ 
    $algorithm = "tblastx";
  }
  elsif( $me =~ /blastn/i ){ 
    $algorithm = "blastn";
  }
  elsif( $me =~ /blastx/i ){ 
    $algorithm = "blastx";
  }
  elsif( $me =~ /blastp/i ){ 
    $algorithm = "blastp";
  }
  else{
    $self->throw( "Method $me has no recognised method" );
  }

  my $algo = uc( $algorithm );
  my $prognamkey = "ENSEMBL_${algo}_PROGRAM_NAME";
  my $prog_nam = $SPECIES_DEFS->$prognamkey() || 
    $self->throw( "No $prognamkey is configured" );

  my $progdirkey = "ENSEMBL_BLAST_BIN_PATH";
  my $prog_dir = $SPECIES_DEFS->$progdirkey() ||
    $self->throw( "No ENSEMBL_BLAST_BIN_PATH is configured" );

  $self->program_name( $prog_nam );
  $self->program_dir( $prog_dir );
  
  # Parse the database - this is yuk!
  my $dbname = $self->database || $self->throw("Need a database!");
  my @bits = split( /[_\.]/, $dbname, 3 );     
  if( @bits < 3 ){ 
    $self->throw("Bad format for Ensembl search DB: ".$dbname );
  }

  my $species = ucfirst( $bits[0] ) . '_' . lc( $bits[1] );
  my $pfp='';
  if   ( $species=~/mus/i)   { $pfp="mouse" }
  elsif( $species=~/rat/i)   { $pfp="rat"   }
  elsif( $species=~/caeno/i) { $pfp="celeg" }
  elsif( $species=~/dros/i)  { $pfp="dros"  }
  elsif( $species=~/danio/i) { $pfp="danr"  }
  else                       { $pfp="human" }

  my $db_type = uc( $bits[2] );
  my $confkey = $self->algorithm . '_DATASOURCES';
  my $db_conf = $SPECIES_DEFS->get_config( $species, $confkey );
  if( ref( $db_conf ) ne 'HASH' ){ $self->throw("No $confkey for $species") }

  my $database = $db_conf->{$db_type} ||
    $self->throw("No $db_type for $confkey, $species");

  my $executable = $self->program_path ||
    $self->throw("Need an executable");

  my $param_str = '';
  my %params = $self->parameters;
  foreach my $param( keys %params ){
    my $val = $params{$param} || '';
    if ($param=~/repeatmask/i){
      $param_str .= " --pfp=pfp_" . $pfp . ".prm";
      next
    }
    if( $val ){ $param_str .= " $param $val" }
    else{ $param_str .= " $param" }
  }
  $param_str =~ s/[;`&|<>\s]+/ /g;
  my $blast_command = join( ' ',
			    'cat', $self->fastafile , '|' ,
			    $executable,
			    '-d', $database,
			    '-p', $algorithm,
			    $param_str, );

  return $blast_command;

}


#----------------------------------------------------------------------


1;
