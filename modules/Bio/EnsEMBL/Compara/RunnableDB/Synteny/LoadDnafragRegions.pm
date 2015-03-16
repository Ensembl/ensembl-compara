
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Synteny::BuildSynteny

=cut

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Synteny::LoadDnafragRegions;

use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use base ('Bio::EnsEMBL::Compara::RunnableDB::RunCommand', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;
  return 1;
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my( $self) = @_;
  my $compara_name = "compara";
  $self->param('pipeline_db');
  my $worker_dir = $self->worker_temp_directory; 

  my $loc_cmd = "perl $ENV{'ENSEMBL_CVS_ROOT_DIR'}/ensembl-compara/scripts/pipeline/make_reg_from_locator.pl -no_print_ret 1 -url " . $self->param('compara_url');
  open(LOC, "$loc_cmd |");

  my $tmp_file =  $worker_dir . 'reg_conf';
print $tmp_file, " ***\n";
  open(IN, ">$tmp_file") or die "cant open $tmp_file for writing\n$!\n\n";
  while(<LOC>){
   print IN $_;
  }
  close(LOC);
  print IN "\n######\nnew Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(\n"; 
  while(my($key, $value) = each %{ $self->param('pipeline_db') }){
   print IN "  $key => \"$value\",\n";
  }
  print IN "  -species => \"$compara_name\",);\n1;\n";
  close(IN);
  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_all("$tmp_file");
  my $non_ref_species;
  my $genome_db_adaptor = $reg->get_adaptor("$compara_name", "compara", "GenomeDB");
  foreach my $genome_db(@{ $genome_db_adaptor->fetch_all }){
   unless ($self->param('ref_species') eq $genome_db->name){
    $non_ref_species = $genome_db->name;
   }
  }
  my $cmd = "perl $ENV{'ENSEMBL_CVS_ROOT_DIR'}/ensembl-compara/scripts/synteny/LoadSyntenyData.pl --reg_conf $tmp_file" . 
            " --dbname $compara_name -ref \"" . $self->param('ref_species') . "\" -nonref \"$non_ref_species\" " .
            " -synteny_mlss_id 10109 " . " " . $self->param('input_file');
            #" -mlss_id " . $self->param('synteny_mlss_id') . " " . $self->param('input_file');
  system("$cmd");
}




=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut

sub write_output {
  my( $self) = @_;
  return 1;
}


1;
