# get the MemberAdaptor
my $genemember_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    'Multi','compara','GeneMember');

# fetch a Member
my $member = $genemember_adaptor->fetch_by_source_stable_id(
    'ENSEMBLGENE','ENSG00000004059');

# print out some information about the Member
print $member->chr_name, " ( ", $member->chr_start, " - ", $member->chr_end,
    " ): ", $member->description, "\n";
