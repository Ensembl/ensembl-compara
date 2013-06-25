package Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::BlastDB;
#package Bio::EnsEMBL::Analysis::Tools::BlastDB;

use strict;
no warnings;

use vars qw (@ISA);

@ISA = qw();

use Bio::EnsEMBL::Utils::Exception qw(verbose throw warning stack_trace_dump);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Analysis::Tools::Logger qw(logger_info);
use Bio::EnsEMBL::Analysis::Tools::Utilities qw(write_seqfile create_file_name);


sub new {
  my ($class,@args) = @_;
  
  my $self = bless {},$class;
  my ($sequences, $sequence_file, $molecule_type, $blast_type, $format_command,
      $output_dir,$xdformat_exe)
    = rearrange ([qw(SEQUENCES 
                     SEQUENCE_FILE 
                     MOL_TYPE 
                     BLAST_TYPE 
                     FORMAT_COMMAND 
                     OUTPUT_DIR
		     XDFORMAT_EXE)], @args);

  #default setting
  $self->blast_type("wublast");
  #$self->output_dir("/tmp/");
  ###############
  $self->xdformat_exe($xdformat_exe);
  $self->sequences($sequences);
  $self->sequence_file($sequence_file);
  $self->molecule_type($molecule_type);
  $self->blast_type($blast_type);
  $self->format_command($format_command);
  $self->output_dir($output_dir);

  return $self;
}

sub xdformat_exe{
  my ($self, $arg) = @_;

  if($arg){
	$self->{xdformat_exe} = $arg;
   }
 
return $self->{xdformat_exe};
}

sub sequences{
  my ($self, $arg) = @_;

  if($arg){
    throw("BlastDB::sequences ".$arg." must be an array ref ") 
      unless(ref($arg) eq "ARRAY");
    push(@{$self->{sequences}}, @{$arg});
  }
  return $self->{sequences};
}

sub sequence_file{
  my ($self, $arg) = @_;
 
  if($arg){ 
    $self->{seq_file} = $arg;
  }

  if(!$self->{seq_file}){
    $self->{seq_file} = create_file_name("blastdb", "fa", $self->temp_dir);
  }

  return $self->{seq_file};
}

sub molecule_type{
  my ($self, $arg) = @_;
  if($arg){
    $arg = uc($arg);
    throw($arg." must be either DNA or PROTEIN") unless($arg eq "DNA" ||
                                                        $arg eq "PROTEIN");
    $self->{mol_type} = $arg;
  }
  return $self->{mol_type};
}

sub blast_type{
  my ($self, $arg) = @_;
  if($arg){
    $arg = lc($arg);
    throw($arg." must be either wublast, old_wublast or ncbi") 
      unless($arg eq "wublast" || $arg eq "old_wublast" || $arg eq "ncbi");
    $self->{blast_type} = $arg;
  }
  return $self->{blast_type};
}

sub format_command{
  my ($self, $arg) = @_;
  if($arg){
    $self->{format_command} = $arg;
  }
  return $self->{format_command};
}

sub output_dir{
  my ($self, $arg) = @_;
  if($arg){
    throw($arg." must be a directory") unless(-d $arg);
    $self->{output_dir} = $arg;
  }
  return $self->{output_dir};
}

sub temp_dir{
  my ($self, $arg) = @_;
  if($arg){
    throw($arg." must be a directory") unless(-d $arg);
    $self->{temp_dir} = $arg;
  }
  if(!$self->{temp_dir}){
    
    my $id_num = $$;
    my $blastdb_dir;
    do { 
      $blastdb_dir = $self->output_dir . "/tempblast." . $id_num . "/";
      $id_num++;
    } while ( -d $blastdb_dir);
       
    mkdir $blastdb_dir;
    $self->{temp_dir} = $blastdb_dir;

  }

  return $self->{temp_dir};
}


sub create_blastdb{
  my ($self, $seq_file, $format_command) = @_;

  $seq_file = $self->sequence_file if(!$seq_file);

  if(! -e $seq_file){
    throw("Your seqfile ".$seq_file." does not exist you must have some ".
          "seq objects defined to dump in it") unless($self->sequences);
    write_seqfile($self->sequences, $seq_file);
  }
  $format_command = $self->format_command if(!$format_command);
  if(!$format_command){
    $format_command = $self->discover_command;  
  }
  
   my $command = $self->format_command." ".$self->output_dir."/BLASTDB ".$seq_file;

  logger_info("Running ".$command);
  open SAVEOUT, ">&STDOUT";
  open SAVEERR, ">&STDERR";
  open STDOUT, "/dev/null";
  open STDERR, "/dev/null";
  
  my $exit_status = system($command);
  
  # restore STDOUT and STDERR
  open STDOUT, ">&SAVEOUT";
  open STDERR, ">&SAVEERR";
  
  if ($exit_status) {
    throw("Failed to run ".$command." exited with ".$exit_status);
  } else {
    return $seq_file;
  }  
}


sub discover_command{
  my ($self) = @_;
 
  my $xdformat_exe = $self->xdformat_exe;

  if($self->blast_type eq "wublast"){
    if($self->molecule_type eq "DNA"){
      $self->format_command('xdformat -n -I');
    }elsif($self->molecule_type eq "PROTEIN"){
      $self->format_command("$xdformat_exe -k -p -I -o");
      #$self->format_command('xdformat -p -I');
    }else{
      throw("Don't recognise mol type ".$self->molecule_type);
    }
  }elsif($self->blast_type eq "old_wublast"){
    if($self->molecule_type eq "DNA"){
      $self->format_command('pressdb');
    }elsif($self->molecule_type eq "PROTEIN"){
      $self->format_command('setdb');
    }else{
      throw("Don't recognise mol type ".$self->molecule_type);
    }
  }elsif($self->blast_type eq "ncbi"){
    if($self->molecule_type eq "DNA"){
      $self->format_command('formatdb -o -p F -i');
    }elsif($self->molecule_type eq "PROTEIN"){
      $self->format_command('formatdb -o -i ');
    }else{
      throw("Don't recognise mol type ".$self->molecule_type);
    }
  }
  throw("Format command ".$self->format_command." must both be defined") 
    unless ($self->format_command);
  return $self->format_command;
}


sub list_dbfiles{
  my ($self) = @_;
  if(!$self->{index_files}){
    opendir (BLASTDB_DIR, $self->temp_dir) or throw("BlastDB: Failed to ".
                                                    "open ".$self->temp_dir);
    my @dbfiles = readdir BLASTDB_DIR;
    closedir BLASTDB_DIR;
    my @full_path;
    foreach my $dbfile(@dbfiles){
      next if($dbfile eq "." || $dbfile eq "..");
      my $full = $self->temp_dir."/".$dbfile;
      push(@full_path, $full);
    }
    push(@full_path, $self->temp_dir);
    $self->{index_files} = \@full_path;
  }
  return $self->{index_files};
}

1;
