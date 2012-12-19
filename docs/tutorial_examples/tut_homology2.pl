my $homology = $homologies->[0]; # take one of the homologies and look into it

foreach my $member (@{$homology->get_all_Members}) {

  # each AlignedMember contains both the information on the Member and in
  # relation to the homology

  print (join " ", map { $member->$_ } qw(stable_id taxon_id))."\n";
  print (join " ", map { $member->$_ } qw(perc_id perc_pos perc_cov))."\n";

}
