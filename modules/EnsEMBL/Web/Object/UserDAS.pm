package EnsEMBL::Web::Object::UserDAS;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;

our @ISA = qw(EnsEMBL::Web::Object);

sub get_DAS_server_list {
  my ($self, $species_defs, $default) = @_;

  my $NO_REG = 'No registry';
  my $rurl = $species_defs->DAS_REGISTRY_URL || $NO_REG;

  if (defined (my $url = $default)) {
      $url = "http://$url" if ($url !~ m#^\w+://#);
      $url .= '/das' if ($url !~ m#/das$# && $url ne $rurl);
  }

  my @domains = ();
  push( @domains, @{$species_defs->ENSEMBL_DAS_SERVERS || []});
  #push( @domains, map{$_->adaptor->domain} @{$object->Obj} ); ## NEEDS REFACTORING!!
  push( @domains, $default) if ($default ne $species_defs->DAS_REGISTRY_URL);

  my @urls;
  foreach my $url (sort @domains) {
    $url = "http://$url" if ($url !~ m#^\w+://#);
    $url .= "/das" if ($url !~ m#/das$#);
    push @urls, $url;
  }
  my %known_domains = map { $_ => 1} grep{$_} @urls ;
  my @das_servers =  sort keys %known_domains;

  my @dvals = ();
  unless ($rurl eq $NO_REG) {
    push @dvals, {'name' => 'DAS Registry', 'value'=>$rurl};
  }

  foreach my $dom (@das_servers) {
    push @dvals, {'name'=>$dom, 'value'=>$dom} ;
  }
  return \@dvals;
}



1;

