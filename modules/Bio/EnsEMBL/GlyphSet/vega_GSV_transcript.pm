package Bio::EnsEMBL::GlyphSet::vega_GSV_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::GSV_transcript;

@ISA = qw(Bio::EnsEMBL::GlyphSet::GSV_transcript);

sub colours {
  my $self = shift;
  my $Config = $self->{'config'};
  return $Config->get('vega_GSV_transcript','colours');
}

sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;
  my $genecol = $colours->{ $gene->analysis->logic_name }->{ $gene->biotype };
  if(exists $highlights{lc($transcript->stable_id)}) {
    return (@$genecol, $colours->{'superhi'}[0]);
  } elsif(exists $highlights{lc($transcript->external_name)}) {
    return (@$genecol, $colours->{'superhi'}[0]);
  } elsif(exists $highlights{lc($gene->stable_id)}) {
    return (@$genecol, $colours->{'hi'}[0]);
  }
  return (@$genecol, undef);
}

1;
