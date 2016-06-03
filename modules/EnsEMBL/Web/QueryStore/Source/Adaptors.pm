package EnsEMBL::Web::QueryStore::Source::Adaptors;

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::DBConnection;

sub new {
  my ($proto,$sd) = @_;

  my $class = ref($proto) || $proto;
  my $self = { _sd => $sd };
  bless $self,$class;
  return $self;
}

sub _database {
  my ($self,$species,$db) = @_;

  $db ||= 'core';
  if($db =~ /compara/) {
    $species = 'multi';
  }
  my $dbc = EnsEMBL::Web::DBSQL::DBConnection->new($species,$self->{'_sd'});
  if($db eq 'go') {
    return $dbc->get_databases_species($species,'go')->{'go'};
  }
  return $dbc->get_DBAdaptor($db,$species);
}

sub _get_adaptor {
  my ($self,$method,$db,$species) = @_;

  my $dba = $self->_database($species,$db);
  return undef unless defined $dba;
  return $dba->$method();
}

sub slice_adaptor {
  my ($self,$species) = @_;

  return $self->_get_adaptor('get_SliceAdaptor',undef,$species);
}

sub gene_adaptor {
  my ($self,$species,$type) = @_;

  return $self->_get_adaptor('get_GeneAdaptor',$type||'core',$species);
}

sub transcript_adaptor {
  my ($self,$species,$type) = @_;

  return $self->_get_adaptor('get_TranscriptAdaptor',$type||'core',$species);
}

sub variation_feature_adaptor {
  my ($self,$species) = @_;

  return $self->_get_adaptor('get_VariationFeatureAdaptor','variation',$species);
}

sub transcript_variation_adaptor {
  my ($self,$species) = @_;

  return $self->_get_adaptor('get_TranscriptVariationAdaptor','variation',$species);
}

sub slice_by_name {
  my ($self,$species,$name) = @_;

  return $self->slice_adaptor($species)->fetch_by_name($name);
}

sub gene_by_stableid {
  my ($self,$species,$type,$id) = @_;

  return $self->gene_adaptor($species,$type)->fetch_by_stable_id($id);
}

sub transcript_by_stableid {
  my ($self,$species,$type,$id) = @_;

  return $self->transcript_adaptor($species,$type)->fetch_by_stable_id($id);
}


sub compara_member {
  my ($self,$id) = @_;

  my $gma = $self->_get_adaptor('get_GeneMemberAdaptor','compara');
  return undef unless $gma;
  return $gma->fetch_by_stable_id($id);
}

sub pancompara_member {
  my ($self,$id) = @_;

  my $gma = $self->_get_adaptor('get_GeneMemberAdaptor','compara_pan_ensembl');
  return undef unless $gma;
  return $gma->fetch_by_stable_id($id);
}

sub phenotype_feature_adaptor {
  my ($self,$species) = @_;

  return $self->_get_adaptor('get_PhenotypeFeatureAdaptor','variation',$species);
}

sub alt_allele_group_adaptor {
  my ($self,$species) = @_;

  return $self->_get_adaptor('get_AltAlleleGroupAdaptor','core',$species);
}

sub default_gene_tree {
  my ($self,$species,$member) = @_;

  my $gta = $self->_get_adaptor('get_GeneTreeAdaptor','compara');
  return undef unless $gta;
  return $gta->fetch_default_for_Member($member);
}

sub variation_db_adaptor {
  my ($self,$var_db,$species) = @_;

  return $self->_database($species,$var_db);
}

sub compara_db_adaptor {
  my ($self) = @_;

  return $self->_database(undef,'compara');
}

sub pancompara_db_adaptor {
  my ($self) = @_;

  return $self->_database(undef,'compara_pan_ensembl');
}

sub regulation_db_adaptor {
  my ($self,$species) = @_;

  return $self->_database($species,'funcgen');
}

sub database_dbc {
  my ($self,$species,$type) = @_;

  my $db = $self->_database($species,$type);
  return undef unless defined $db;
  return $db->dbc;
}

1;
