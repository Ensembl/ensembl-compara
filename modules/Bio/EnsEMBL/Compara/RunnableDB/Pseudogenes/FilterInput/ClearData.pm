use warnings;
use strict;

package FilterInput::ClearData;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input
{
  my $self = shift;
}

sub run
{
  my $self = shift;
  my $sql, my $sth;
  my $insert = 0;
  ## Creates a TABLE containing only data with the status OK
  $sql = "CREATE TABLE IF NOT EXISTS good_pseudogenes LIKE pseudogenes_data";
  $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  $sth->finish();

  $sql = qq{REPLACE INTO good_pseudogenes SELECT * FROM pseudogenes_data WHERE status = "OK"};
  $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  $sth->finish();

  ## Update the tree when a parent pseudogene was not present in the first set of data.
  $sql = "SELECT * FROM good_pseudogenes WHERE pseudogene_id in (SELECT pseudogene_id FROM good_pseudogenes WHERE tree_id IS NULL) AND tree_id IS NOT NULL";
  $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();

  while (my $h = $sth->fetchrow_hashref()) {
    my %this_row = %$h;
    $sql = qq{UPDATE good_pseudogenes SET tree_id = ? WHERE parent_id = ? AND pseudogene_id = ? AND tree_id IS NULL};
    my $local_sth = $self->compara_dba->dbc->prepare($sql);
    $local_sth->execute($this_row{'tree_id'}, $this_row{'parent_id'}, $this_row{'good_pseudogenes'});
    $local_sth->finish();

    $sql = qq{REPLACE INTO good_pseudogenes (parent_id, pseudogene_id, parent_transcript_id, transcript_id, tree_id, score, evalue, parent_species, parent_query, parent_type, pseudogene_species, pseudogene_query, pseudogene_type, status, filepath, line) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)};
    $local_sth = $self->compara_dba->dbc->prepare($sql);
    $local_sth->execute($this_row{'parent_id'}, $this_row{'pseudogene_id'}, $this_row{'parent_transcript_id'}, $this_row{'transcript_id'}, $this_row{'tree_id'}, $this_row{'score'}, $this_row{'evalue'}, $this_row{'parent_species'}, $this_row{'parent_query'}, $this_row{'parent_type'}, $this_row{'pseudogene_species'}, $this_row{'pseudogene_query'}, $this_row{'pseudogene_type'}, "OK", "ClearData.pm", $insert++);
    $local_sth->finish();
  }

  ## Update the tree 
  $sql = qq{UPDATE good_pseudogenes d1 JOIN good_pseudogenes d2 ON (d1.parent_id = d2.pseudogene_id) SET d1.tree_id = d2.tree_id WHERE d1.tree_id IS NULL AND d2.tree_id IS NOT NULL};
  $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  $sth->finish();
}

1;
