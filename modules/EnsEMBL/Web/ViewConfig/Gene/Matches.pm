package EnsEMBL::Web::ViewConfig::Gene::Matches;

use strict;

use EnsEMBL::Web::Constants;

sub init {
#  my ($view_config) = @_;
my $view_config = shift;
my $help  = shift;
  
  $view_config->storable = 1;
  $view_config->nav_tree = 1;
  my %defaults;
  my $species= $ENV{'ENSEMBL_SPECIES'};
  my $DBConnection = new EnsEMBL::Web::DBSQL::DBConnection("Homo_sapiens", $ENV);
  my $dba = $DBConnection->get_DBAdaptor("core", $species);
  my $sth = $dba->dbc->prepare("SELECT distinct(edb.db_display_name)
  FROM object_xref ox join xref x on ox.xref_id=x.xref_id  join external_db edb on x.external_db_id = edb.external_db_id
    where edb.type IN ('MISC', 'LIT')
    and (ox.ensembl_object_type ='Transcript' or ox.ensembl_object_type ='Translation' )");  
  $sth->execute();    
  my @row;
  while (@row=$sth->fetchrow_array()){
    $defaults{$row[0]}='yes';
  }
  $view_config->_set_defaults(%defaults);
}

sub form {
  my ($view_config, $object) = @_;

  my $sth = $object->database('core',$object->species )->dbc->prepare("SELECT distinct(edb.db_display_name)
  FROM object_xref ox join xref x on ox.xref_id=x.xref_id  join external_db edb on x.external_db_id = edb.external_db_id
    where edb.type IN ('MISC', 'LIT')
    and (ox.ensembl_object_type ='Transcript' or ox.ensembl_object_type ='Translation' )");
  $sth->execute();
  my @row;
  while (@row=$sth->fetchrow_array()){
     my $external_ref_type_chec_box = {
      'type'  => 'CheckBox',
      'select' => 'select',
      'name'   => $row[0],
      'label'  => $row[0],
      'value' => 'yes'
    };     
    $view_config->add_form_element($external_ref_type_chec_box);
  }    
}

1;
