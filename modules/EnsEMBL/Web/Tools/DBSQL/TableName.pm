package EnsEMBL::Web::Tools::DBSQL::TableName;

sub parse_table_name {
  my ($string) = @_;
  if ($string=~ /%%(.*)%%/) {
    #warn "TEMPLATING: " . $string;
    #warn "CHECKING:" . $1;
    my $name;
    my $species_defs = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs;
    if ($1 eq 'user_record') {
      $name = $species_defs->ENSEMBL_USER_DATA_TABLE;
    } elsif ($1 eq 'group_record') {
      $name = $species_defs->ENSEMBL_GROUP_DATA_TABLE;
    } else {
      $name = $1;
    }
    $string =~ s/%%(.*)%%/$name/;
  }
  #warn "USING: " . $string;
  return $string;
}

sub parse_primary_key {
  my ($string) = @_;
  if ($string=~ /%%(.*)%%/) {
    #warn "TEMPLATING: " . $string;
    #warn "CHECKING:" . $1;
    my $name;
    my $species_defs = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs;
    if ($1 eq 'user_record') {
      $name = $species_defs->ENSEMBL_USER_DATA_TABLE . '_id';
    } elsif ($1 eq 'group_record') {
      $name = $species_defs->ENSEMBL_GROUP_DATA_TABLE . '_id';
    } else {
      $name = $1 . '_id';
    }
    $string = $name;
  }
  #warn "USING: " . $string;
  return $string;
}



1;
