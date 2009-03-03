package EnsEMBL::Web::Command::Account::SaveDas;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  print "Content-type:text/html\n\n";
  print "Saving DAS for " . $user->id . "<br />"; 
  my @sources = @{ $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_das_filtered_and_sorted };
    
  foreach my $das (@sources) {
    $user->add_to_dases({
      name    => $das->get_name,
      url     => $das->get_data->{'url'},
      config  => $das->get_data,
    });

    print $user_das->name . "<br />";
    warn "DAS: " . $das->get_name . " (" . $das->get_data->{'url'} . ")";
  } 
}

}

1;
