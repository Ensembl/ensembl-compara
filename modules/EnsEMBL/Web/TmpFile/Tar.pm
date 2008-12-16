package EnsEMBL::Web::TmpFile::Tar;

## EnsEMBL::Web::TmpFile::Tar - module for storing multiple tmp files into tar archive

use strict;
use EnsEMBL::Web::SpeciesDefs;
use base 'EnsEMBL::Web::TmpFile';

sub new {
  my $class = shift;
  my %args  = @_;
  
  my $species_defs = delete $args{species_defs} || EnsEMBL::Web::SpeciesDefs->new();
  my $self = $class->SUPER::new(
    content      => [],
    species_defs => $species_defs,
    compress     => 1,
    extension    => 'tar.gz',
    content_type => 'application/x-gzip',
    %args,
  );

  return $self;
}

1;