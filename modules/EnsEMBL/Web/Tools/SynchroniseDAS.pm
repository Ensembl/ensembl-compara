package EnsEMBL::Web::Tools::SynchroniseDAS;

use strict;
use warnings;

use EnsEMBL::Web::SpeciesDefs;
use SiteDefs qw(:ALL);
use Bio::EnsEMBL::Utils::Exception qw(info warning);
use Digest::MD5;
use File::Spec;
use base qw(Exporter);

use constant {
  DAS_CHANGED   => 1,
  DAS_UNCHANGED => 0
};

our @EXPORT = qw(DAS_CHANGED DAS_UNCHANGED rebuild_das);

sub rebuild_das {
  
  my $digest = Digest::MD5->new;
  
  # Remove config.packed to make SpeciesDefs rebuild it
  my $packed_filename = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0],'config.packed');
  info("Removing '$packed_filename'");
  unlink $packed_filename;
  
  info('Calculating checksum for existing DAS packed files');
  
  # Calculate a checksum for all the packed files, and remove them
  foreach my $species ( @$ENSEMBL_DATASETS ) {
    $packed_filename = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0],'packed',"$species.das.packed");
    if ( open (FH, '<', $packed_filename) ) {
      $digest->addfile( *FH );
      close FH;
      info("Removing '$packed_filename'");
      unlink $packed_filename;
    } else {
      info("Not including '$packed_filename' in checksum");
    }
  }
  
  my $before_checksum = $digest->hexdigest;
  info("Existing checksum: $before_checksum");
  
  # Instantiating SpeciesDefs will rebuild the packed files
  info('Regenerating DAS packed files via SpeciesDefs');
  EnsEMBL::Web::SpeciesDefs->new;
  
  # Go back through the species' and calculate the new checksum
  $digest->reset;
  foreach my $species ( @$ENSEMBL_DATASETS ) {
    $packed_filename = File::Spec->catfile($SiteDefs::ENSEMBL_CONF_DIRS[0],'packed',"$species.das.packed");
    if ( open (FH, '<', $packed_filename) ) {
      $digest->addfile( *FH );
      close FH;
    } else {
      warning("SpeciesDefs did not rebuild '$packed_filename'");
    }
  }
  
  my $after_checksum = $digest->hexdigest;
  info("New checksum: $after_checksum");
  
  return $after_checksum eq $before_checksum ? DAS_UNCHANGED : DAS_CHANGED;
}

1;
