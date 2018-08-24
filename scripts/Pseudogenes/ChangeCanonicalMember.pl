use warnings;
use strict;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host=>'mysql-ens-compara-prod-3.ebi.ac.uk', -user=>'ensadmin', -pass=>$ENV{ENSADMIN_PSW}, -dbname=>'ggiroussens_pseudogenes_v9', -port=>4523);

my $gene_member_adaptor = $compara_dba->get_GeneMemberAdaptor;
my $seq_member_adaptor = $compara_dba->get_SeqMemberAdaptor;
print("Fetching Pseudogene...\n");
my $pseudogenes = $gene_member_adaptor->generic_fetch(qq{genome_db_id IN (150, 134, 174, 212, 213) AND biotype_group = "pseudogene"});
print("Done\n");

$_->db_adaptor->dbc->disconnect_when_inactive(0) for @{$compara_dba->get_GenomeDBAdaptor->fetch_all_by_dbID_list([134, 150, 174, 212, 213])};

foreach my $this_pseudogene(@$pseudogenes)
{
  print($this_pseudogene->stable_id."\n");
  foreach my $this_seq_member(@{$this_pseudogene->get_all_SeqMembers})
  {
#    print("\t".$this_seq_member->stable_id."\n");
    if($this_seq_member->get_Transcript->biotype =~ /pseudogene/ and $this_seq_member->get_Transcript->biotype !~ /poly/)
    {
      $seq_member_adaptor->_set_member_as_canonical($this_seq_member);
    }
  }
}
