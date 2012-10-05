package Bio::EnsEMBL::GlyphSet::fg_methylation;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::bigbed);

sub features {
  my $self    = shift;
  my $slice   = $self->{'container'}; 
  my $Config  = $self->{'config'};
  my $type    = $self->type;

  my $data_id = $self->my_config('data_id');  
  return unless defined $data_id;

  if($slice->length > 200000) {
    if(not $self->{'config'}->{'_sent_ch3_error_track'}) {
      $self->{'config'}->{'_sent_ch3_error_track'} = 1;
      return $self->errorTrack("Methylation data is not currently only viewable on images over 200kb in size");
    } else {
      return undef;
    }
  }

  my $fgh = $slice->adaptor->db->get_db_adaptor('funcgen');
  
  return if($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")); # XXX Seems not to have adaptors?
  
  my $rsa = $fgh->get_ResultSetAdaptor;
  my $rs = $rsa->fetch_by_dbID($data_id);
  
  return unless defined $rs;

  my $bigbed_file = $rs->dbfile_data_dir;
  
  # Substitute path, if necessary. TODO: use DataFileAdaptor  
  my @parts = split(m!/!,$bigbed_file);
  $bigbed_file = join("/",$self->{'config'}->hub->species_defs->DATAFILE_BASE_PATH,
                          @parts[-5..-1]);
  my $bba = $self->bigbed_adaptor(Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor->new($bigbed_file));

  return $self->SUPER::features({
    style => 'colouredscore',
  });
}

sub render_normal {
  my $self = shift;
  $self->{'renderer_no_join'} = 1;
  $self->SUPER::render_normal(8, 0);  
}
sub render_compact { shift->render_normal(@_); }

sub href { return undef; } # tie to background
sub href_bgd {
  my ($self, $strand) = @_;
  
  return $self->_url({
    action   => 'Methylation',
    ftype    => 'Regulation',
    dbid     => $self->my_config('data_id'),
    species  => $self->species,
    fdb      => 'funcgen',
    scalex   => $self->scalex,
    strand   => $strand,
    width    => $self->{'container'}->length,
  });
}

1;
