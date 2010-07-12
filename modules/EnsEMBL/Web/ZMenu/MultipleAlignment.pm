# $Id$

package EnsEMBL::Web::ZMenu::MultipleAlignment;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $id          = $hub->param('id');
  my $object_type = $hub->param('ftype');
  my $align       = $hub->param('align');
  my $caption     = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'name'};
  
  my $url = $hub->url({
    type   => 'Location',
    action => 'Compara_Alignments',
    align  => $align
  });

  my ($chr, $start, $end) = split /[:-]/, $hub->param('r');
  
  # if there's a score than show it and also change the name of the track (hacky)
  if ($object_type && $id) {
    my $db_adaptor   = $hub->database('compara');
    my $adaptor_name = "get_${object_type}Adaptor";
    my $feat_adap    = $db_adaptor->$adaptor_name;
    my $feature      = $feat_adap->fetch_by_dbID($id);
    
    if ($object_type eq 'ConstrainedElement') {
      if ($feature->p_value) {
        $self->add_entry({
          type  => 'p-value',
          label => sprintf('%.2e', $feature->p_value)
        });
      }
      
      $self->add_entry({
        type  => 'Score',
        label => sprintf('%.2f', $feature->score)
      });
      
      $caption = "Constrained el. $1 way" if $caption =~ /^(\d+)/;
    } elsif ($object_type eq 'GenomicAlignBlock' && $hub->param('ref_id')) {
      $feature->{'reference_genomic_align_id'} = $hub->param('ref_id');
      $start = $feature->reference_genomic_align->dnafrag_start;
      $end = $feature->{'reference_genomic_align'}->dnafrag_end;
    }
  }
  
  $self->caption($caption);
  
  $self->add_entry({
    type  => 'start',
    label => $start
  });
  
  $self->add_entry({
    type  => 'end',
    label => $end
  });
  
  $self->add_entry({
    type  => 'length',
    label => ($end - $start + 1) . ' bp'
  });
  
  $self->add_entry({
    label => 'View alignments (text)',
    link  => $url
  });
  
  $url =~ s/Compara_Alignments/Compara_Alignments\/Image/;
  
  $self->add_entry({
    label => 'View alignments (image)',
    link  => $url
  });
}

1;
